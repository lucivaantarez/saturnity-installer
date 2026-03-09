#!/data/data/com.termux/files/usr/bin/bash
# curl -sL https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main/saturnity.sh -o saturnity.sh && bash saturnity.sh

G='\033[0;32m'; R='\033[0;31m'; M='\033[0;35m'; D='\033[2m'; NC='\033[0m'

TMP="/tmp/.sat"
cleanup() { rm -f "$TMP" 2>/dev/null; [[ -f "$0" && "$0" != /proc/* ]] && rm -f "$0" 2>/dev/null; }
trap cleanup EXIT

APKS=(
  "W1|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W1.apk"
  "W2|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W2.apk"
  "W3|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W3.apk"
  "W4|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W4.apk"
  "W5|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W5.apk"
  "W6|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W6.apk"
)

# ── ROOT ─────────────────────────────────────────────────────
clear
echo ""
echo -e "${M}SATURNITY${NC}"
echo ""
if ! su -c "id" > /dev/null 2>&1; then
  echo -e "${R}x no root${NC}"; exit 1
fi
echo -e "${G}* root ok${NC}"
echo ""

# ── UNINSTALL ROBLOX ─────────────────────────────────────────
echo -e "${D}scanning...${NC}"
FOUND=()
RAW=$(su -c "pm list packages" 2>/dev/null)
for pattern in "com.roblox.client" "com.roblox" "roblox"; do
  while IFS= read -r ln; do
    pkg=$(echo "${ln#package:}" | tr -d '[:space:]\r')
    already=0
    for e in "${FOUND[@]}"; do [[ "$e" == "$pkg" ]] && already=1 && break; done
    [[ $already -eq 0 && -n "$pkg" ]] && FOUND+=("$pkg")
  done < <(echo "$RAW" | grep -i "$pattern")
done

COUNT=${#FOUND[@]}
if [[ $COUNT -gt 0 ]]; then
  echo -e "${D}removing $COUNT package(s)...${NC}"
  for pkg in "${FOUND[@]}"; do
    echo -ne " $pkg... "
    r=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
    if echo "$r" | grep -qi "success\|deleted"; then
      echo -e "${G}ok${NC}"
    else
      r2=$(su -c "pm uninstall $pkg" 2>&1)
      echo "$r2" | grep -qi "success" && echo -e "${G}ok${NC}" || echo -e "${R}fail${NC}"
    fi
  done
  echo ""
  echo -e "${G}* uninstall done${NC}"
else
  echo -e "${D}no roblox found${NC}"
fi

sleep 1

# ── INSTALL ──────────────────────────────────────────────────
clear
echo ""
echo -e "${M}SATURNITY${NC}"
echo ""
echo -e "${D}installing ${#APKS[@]} apps...${NC}"
echo ""

for entry in "${APKS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  echo -ne " $name... "
  curl -sL "$url" -o "$TMP" 2>/dev/null
  if [[ ! -s "$TMP" ]]; then
    echo -e "${R}download fail${NC}"; continue
  fi
  r=$(su -c "pm install -r $TMP" 2>&1)
  rm -f "$TMP"
  echo "$r" | grep -qi "success" && echo -e "${G}ok${NC}" || echo -e "${R}fail${NC}"
done

# ── DONE ─────────────────────────────────────────────────────
sleep 1
clear
echo ""
echo -e "${M}SATURNITY${NC}"
echo ""
echo -e "${G}* all done${NC}"
echo -e "${D}@lanavienrose${NC}"
echo ""
