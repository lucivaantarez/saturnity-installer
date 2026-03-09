#!/data/data/com.termux/files/usr/bin/bash
# curl -sL https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main/saturnity.sh -o saturnity.sh && bash saturnity.sh

G='\033[0;32m'; R='\033[0;31m'; M='\033[0;35m'; D='\033[2m'; NC='\033[0m'

cleanup() { [[ -f "$0" && "$0" != /proc/* ]] && rm -f "$0" 2>/dev/null; }
trap cleanup EXIT

bar() {
  local pct=$1 w=20
  local f=$(( pct * w / 100 )) e=$(( w - f ))
  printf "\r ${M}[$(printf '%*s' $f | tr ' ' '#')$(printf '%*s' $e | tr ' ' '.')${M}]${NC} ${D}%d%%${NC}" "$pct"
}

clear
echo ""
echo -e "${M} SATURNITY${NC}"
echo -e "${D} --------${NC}"
echo ""

if ! su -c "id" >/dev/null 2>&1; then
  echo -e " ${R}x no root${NC}"; echo ""; exit 1
fi

bar 10; sleep 0.3

# scan
FOUND=()
RAW=$(su -c "pm list packages" 2>/dev/null)
for pt in "com.roblox.client" "com.roblox" "roblox"; do
  while IFS= read -r ln; do
    pkg=$(echo "${ln#package:}" | tr -d '[:space:]\r')
    already=0
    for e in "${FOUND[@]}"; do [[ "$e" == "$pkg" ]] && already=1 && break; done
    [[ $already -eq 0 && -n "$pkg" ]] && FOUND+=("$pkg")
  done < <(echo "$RAW" | grep -i "$pt")
done

bar 40; sleep 0.3
COUNT=${#FOUND[@]}

if [[ $COUNT -eq 0 ]]; then
  bar 100; echo ""
  echo ""
  echo -e " ${D}nothing found${NC}"
  echo ""; exit 0
fi

# uninstall
PASS=0; FAIL=0
for i in "${!FOUND[@]}"; do
  pkg="${FOUND[$i]}"
  pct=$(( 40 + (i + 1) * 50 / COUNT ))
  bar $pct
  r=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
  if echo "$r" | grep -qi "success\|deleted"; then
    ((PASS++))
  else
    r2=$(su -c "pm uninstall $pkg" 2>&1)
    echo "$r2" | grep -qi "success" && ((PASS++)) || ((FAIL++))
  fi
done

bar 100; echo ""
echo ""
echo -e "${D} --------${NC}"
[[ $FAIL -eq 0 ]] \
  && echo -e " ${G}+ $PASS removed${NC}" \
  || echo -e " ${G}+ $PASS removed${NC}  ${R}x $FAIL failed${NC}"
echo -e "${D} --------${NC}"
echo -e " ${D}@lanavienrose${NC}"
echo ""
