#!/data/data/com.termux/files/usr/bin/bash
# saturnity — roblox uninstaller
# curl -sL https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main/roblox-uninstall.sh -o roblox-uninstall.sh && bash roblox-uninstall.sh

R='\033[0;31m'; G='\033[0;32m'; M='\033[0;35m'
W='\033[1;37m'; D='\033[2m'; NC='\033[0m'

cleanup() {
  rm -f /tmp/.rblx_tmp 2>/dev/null
  [[ -f "$0" && "$0" != /proc/* ]] && rm -f "$0" 2>/dev/null
}
trap cleanup EXIT

# get terminal width, fallback to 40
COLS=$(tput cols 2>/dev/null || echo 40)
MAX_PKG=$(( COLS - 18 ))
[[ $MAX_PKG -lt 10 ]] && MAX_PKG=10

trunc() {
  local s="$1"
  if [[ ${#s} -gt $MAX_PKG ]]; then
    echo "${s:0:$MAX_PKG}.."
  else
    echo "$s"
  fi
}

SEP=$(printf '%*s' "$COLS" '' | tr ' ' '─')

clear
echo ""
echo -e "${M} SATURNITY${NC} ${D}roblox uninstaller${NC}"
echo -e "${D} ${SEP}${NC}"
echo ""

if ! su -c "id" > /dev/null 2>&1; then
  echo -e " ${R}✗ no root. exiting.${NC}"
  exit 1
fi

echo -e " ${G}✓${NC} ${D}root ok${NC}"
echo -e " ${D}· scanning...${NC}"
echo ""

PATTERNS=("com.roblox.client" "com.roblox" "roblox")
FOUND=()
RAW=$(su -c "pm list packages" 2>/dev/null)

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r line; do
    pkg=$(echo "${line#package:}" | tr -d '[:space:]\r')
    already=0
    for e in "${FOUND[@]}"; do [[ "$e" == "$pkg" ]] && already=1 && break; done
    [[ $already -eq 0 && -n "$pkg" ]] && FOUND+=("$pkg")
  done < <(echo "$RAW" | grep -i "$pattern")
done

COUNT=${#FOUND[@]}

if [[ $COUNT -eq 0 ]]; then
  echo -e " ${D}no roblox packages found.${NC}"
  echo ""
  exit 0
fi

echo -e " ${W}found ${M}${COUNT}${W} package(s):${NC}"
for pkg in "${FOUND[@]}"; do
  echo -e " ${M}·${NC} $(trunc "$pkg")"
done
echo -e "${D} ${SEP}${NC}"
echo ""

SUCCESS=0; FAILED=0

for pkg in "${FOUND[@]}"; do
  short=$(trunc "$pkg")
  echo -ne " ${D}removing${NC} ${short}... "

  # Android 10 — try --user 0 first
  r=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
  if echo "$r" | grep -qi "success\|deleted"; then
    echo -e "${G}✓${NC}"
    ((SUCCESS++))
    continue
  fi

  # fallback full uninstall
  r2=$(su -c "pm uninstall $pkg" 2>&1)
  if echo "$r2" | grep -qi "success"; then
    echo -e "${G}✓${NC}"
    ((SUCCESS++))
  else
    echo -e "${R}✗${NC}"
    ((FAILED++))
  fi
done

echo ""
echo -e "${D} ${SEP}${NC}"
if [[ $FAILED -eq 0 ]]; then
  echo -e " ${G}✓ all ${COUNT} removed.${NC}"
elif [[ $SUCCESS -gt 0 ]]; then
  echo -e " ${M}⚠ ${SUCCESS} removed, ${FAILED} failed.${NC}"
else
  echo -e " ${R}✗ failed. try full root shell.${NC}"
fi
echo -e "${D} ${SEP}${NC}"
echo -e " ${D}✦ saturnity · @lanavienrose${NC}"
echo ""
