#!/data/data/com.termux/files/usr/bin/bash
# saturnity — installer + uninstaller
# curl -sL https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main/saturnity.sh -o saturnity.sh && bash saturnity.sh

R='\033[0;31m'; G='\033[0;32m'; M='\033[0;35m'
W='\033[1;37m'; D='\033[2m'; NC='\033[0m'

RAW="https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main"
APKLIST_URL="${RAW}/apklist.txt"
TMP_APK="/tmp/.sat_apk"
TMP_LIST="/tmp/.sat_list"

cleanup() {
  rm -f "$TMP_APK" "$TMP_LIST" 2>/dev/null
  [[ -f "$0" && "$0" != /proc/* ]] && rm -f "$0" 2>/dev/null
}
trap cleanup EXIT

trunc() {
  local s="$1" max="${2:-30}"
  [[ ${#s} -gt $max ]] && echo "${s:0:$max}.." || echo "$s"
}

# ── ROOT CHECK ───────────────────────────────────────────────
clear
echo ""
echo -e "${M} SATURNITY${NC} ${D}installer${NC}"
echo -e "${D} --------------------------------${NC}"
echo ""

if ! su -c "id" > /dev/null 2>&1; then
  echo -e " ${R}x no root. exiting.${NC}"
  echo ""; exit 1
fi
echo -e " ${G}* root ok${NC}"
echo ""

# ── SCAN ROBLOX ──────────────────────────────────────────────
echo -e " ${D}scanning packages...${NC}"

PATTERNS=("com.roblox.client" "com.roblox" "roblox")
FOUND=()
RAW_PKG=$(su -c "pm list packages" 2>/dev/null)

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r ln; do
    pkg=$(echo "${ln#package:}" | tr -d '[:space:]\r')
    already=0
    for e in "${FOUND[@]}"; do [[ "$e" == "$pkg" ]] && already=1 && break; done
    [[ $already -eq 0 && -n "$pkg" ]] && FOUND+=("$pkg")
  done < <(echo "$RAW_PKG" | grep -i "$pattern")
done

COUNT=${#FOUND[@]}

if [[ $COUNT -gt 0 ]]; then
  echo ""
  echo -e " ${W}found $COUNT roblox package(s):${NC}"
  for pkg in "${FOUND[@]}"; do
    echo -e " ${D}- $(trunc "$pkg")${NC}"
  done
  echo ""
  echo -ne " ${W}uninstall first? (y/n):${NC} "
  read -r UA

  if [[ "$UA" =~ ^[Yy]$ ]]; then
    clear
    echo ""
    echo -e "${M} SATURNITY${NC} ${D}uninstaller${NC}"
    echo -e "${D} --------------------------------${NC}"
    echo ""
    US=0; UF=0
    for pkg in "${FOUND[@]}"; do
      echo -ne " ${D}removing $(trunc "$pkg")... ${NC}"
      r=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
      if echo "$r" | grep -qi "success\|deleted"; then
        echo -e "${G}ok${NC}"; ((US++))
      else
        r2=$(su -c "pm uninstall $pkg" 2>&1)
        if echo "$r2" | grep -qi "success"; then
          echo -e "${G}ok${NC}"; ((US++))
        else
          echo -e "${R}fail${NC}"; ((UF++))
        fi
      fi
    done
    echo ""
    [[ $UF -eq 0 ]] \
      && echo -e " ${G}* all $COUNT removed.${NC}" \
      || echo -e " ${M}* $US removed, $UF failed.${NC}"
    echo ""; sleep 1
  fi
else
  echo -e " ${D}none found.${NC}"
fi

# ── FETCH APKLIST ────────────────────────────────────────────
clear
echo ""
echo -e "${M} SATURNITY${NC} ${D}installer${NC}"
echo -e "${D} --------------------------------${NC}"
echo ""
echo -e " ${D}fetching list...${NC}"

curl -sL "$APKLIST_URL" -o "$TMP_LIST" 2>/dev/null

if [[ ! -s "$TMP_LIST" ]]; then
  echo -e " ${R}x cannot fetch apklist.txt${NC}"
  echo -e " ${D}make sure apklist.txt exists in:${NC}"
  echo -e " ${D}github.com/lucivaantarez/saturnity-installer${NC}"
  echo ""; exit 1
fi

declare -a APK_NAMES APK_URLS

while IFS='|' read -r name url; do
  name=$(echo "$name" | tr -d '\r ')
  url=$(echo "$url" | tr -d '\r ')
  [[ -z "$name" || -z "$url" ]] && continue
  APK_NAMES+=("$name")
  APK_URLS+=("$url")
done < "$TMP_LIST"

TOTAL=${#APK_NAMES[@]}

if [[ $TOTAL -eq 0 ]]; then
  echo -e " ${R}x apklist.txt is empty or malformed.${NC}"
  echo -e " ${D}format: AppName|https://...${NC}"
  echo ""; exit 1
fi

echo ""
echo -e " ${W}available ($TOTAL):${NC}"
for i in "${!APK_NAMES[@]}"; do
  echo -e " ${M}[$((i+1))]${NC} $(trunc "${APK_NAMES[$i]}" 28)"
done
echo ""
echo -ne " ${W}install (1-${TOTAL}/all):${NC} "
read -r CHOICE

do_install() {
  local name="$1" url="$2"
  clear
  echo ""
  echo -e "${M} SATURNITY${NC} ${D}installing${NC}"
  echo -e "${D} --------------------------------${NC}"
  echo ""
  echo -e " ${D}$(trunc "$name" 28)${NC}"
  echo -e " ${D}downloading...${NC}"
  echo ""
  curl -L "$url" -o "$TMP_APK" --progress-bar 2>&1
  echo ""
  if [[ ! -s "$TMP_APK" ]]; then
    echo -e " ${R}x download failed.${NC}"; echo ""; return
  fi
  echo -e " ${D}installing...${NC}"
  r=$(su -c "pm install -r $TMP_APK" 2>&1)
  rm -f "$TMP_APK"
  echo ""
  if echo "$r" | grep -qi "success"; then
    echo -e " ${G}* done.${NC}"
  else
    echo -e " ${R}x failed: $r${NC}"
  fi
  echo ""
}

if [[ "$CHOICE" == "all" ]]; then
  for i in "${!APK_NAMES[@]}"; do
    do_install "${APK_NAMES[$i]}" "${APK_URLS[$i]}"
  done
elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= TOTAL )); then
  do_install "${APK_NAMES[$((CHOICE-1))]}" "${APK_URLS[$((CHOICE-1))]}"
else
  echo -e " ${D}cancelled.${NC}"; echo ""
fi

# ── DONE ─────────────────────────────────────────────────────
echo -e "${D} --------------------------------${NC}"
echo -e " ${G}* all done.${NC}"
echo -e "${D} --------------------------------${NC}"
echo ""
echo -ne " ${W}open editor? (y/n):${NC} "
read -r EA

if [[ "$EA" =~ ^[Yy]$ ]]; then
  clear
  if command -v nano &>/dev/null; then
    nano "$0" 2>/dev/null
  elif command -v vi &>/dev/null; then
    vi "$0" 2>/dev/null
  else
    echo -e " ${R}x no editor. pkg install nano${NC}"; sleep 2
  fi
fi

clear
echo ""
echo -e "${M} SATURNITY${NC} ${D}@lanavienrose${NC}"
echo ""
