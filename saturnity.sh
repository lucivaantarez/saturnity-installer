#!/data/data/com.termux/files/usr/bin/bash
# saturnity — installer + uninstaller
# curl -sL https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main/saturnity.sh -o saturnity.sh && bash saturnity.sh

R='\033[0;31m'; G='\033[0;32m'; M='\033[0;35m'
W='\033[1;37m'; D='\033[2m'; NC='\033[0m'

INSTALL_PAGE="https://lucivaantarez.github.io/saturnity-installer/"
TMP_APK="/tmp/.sat_apk_tmp"
TMP_HTML="/tmp/.sat_html_tmp"

cleanup() {
  rm -f "$TMP_APK" "$TMP_HTML" 2>/dev/null
  [[ -f "$0" && "$0" != /proc/* ]] && rm -f "$0" 2>/dev/null
}
trap cleanup EXIT

COLS=$(tput cols 2>/dev/null || echo 42)
MAX_PKG=$(( COLS - 18 ))
[[ $MAX_PKG -lt 10 ]] && MAX_PKG=10
SEP=$(printf '%*s' "$COLS" '' | tr ' ' '─')

trunc() {
  local s="$1"
  [[ ${#s} -gt $MAX_PKG ]] && echo "${s:0:$MAX_PKG}.." || echo "$s"
}

header() {
  clear
  echo ""
  echo -e "${M} SATURNITY${NC} ${D}· installer${NC}"
  echo -e "${D} ${SEP}${NC}"
  echo ""
}

# ── ROOT CHECK ───────────────────────────────────────────────
header
if ! su -c "id" > /dev/null 2>&1; then
  echo -e " ${R}✗ no root. exiting.${NC}"
  exit 1
fi
echo -e " ${G}✓${NC} ${D}root ok${NC}"
echo ""

# ── DETECT ROBLOX CLONES ─────────────────────────────────────
echo -e " ${D}· scanning for roblox packages...${NC}"
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

if [[ $COUNT -gt 0 ]]; then
  echo ""
  echo -e " ${W}found ${M}${COUNT}${W} roblox package(s):${NC}"
  for pkg in "${FOUND[@]}"; do
    echo -e " ${M}·${NC} $(trunc "$pkg")"
  done
  echo ""
  echo -ne " ${W}uninstall now?${NC} ${D}(y/n)${NC} "
  read -r UNINSTALL_ANS

  if [[ "$UNINSTALL_ANS" =~ ^[Yy]$ ]]; then
    header
    echo -e " ${D}· uninstalling...${NC}"
    echo ""
    U_SUCCESS=0; U_FAILED=0

    for pkg in "${FOUND[@]}"; do
      short=$(trunc "$pkg")
      echo -ne " ${D}removing${NC} ${short}... "
      r=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
      if echo "$r" | grep -qi "success\|deleted"; then
        echo -e "${G}✓${NC}"; ((U_SUCCESS++))
        continue
      fi
      r2=$(su -c "pm uninstall $pkg" 2>&1)
      if echo "$r2" | grep -qi "success"; then
        echo -e "${G}✓${NC}"; ((U_SUCCESS++))
      else
        echo -e "${R}✗${NC}"; ((U_FAILED++))
      fi
    done

    echo ""
    echo -e "${D} ${SEP}${NC}"
    if [[ $U_FAILED -eq 0 ]]; then
      echo -e " ${G}✓ all ${COUNT} removed.${NC}"
    else
      echo -e " ${M}⚠ ${U_SUCCESS} removed, ${U_FAILED} failed.${NC}"
    fi
    echo -e "${D} ${SEP}${NC}"
    echo ""
    sleep 1
  fi
fi

# ── INSTALLER ────────────────────────────────────────────────
header
echo -e " ${D}· fetching installer page...${NC}"

if ! command -v curl &>/dev/null; then
  echo -e " ${R}✗ curl not found. run: pkg install curl${NC}"
  exit 1
fi

curl -sL "$INSTALL_PAGE" -o "$TMP_HTML" 2>/dev/null

if [[ ! -s "$TMP_HTML" ]]; then
  echo -e " ${R}✗ failed to fetch installer page.${NC}"
  exit 1
fi

# parse APK links from the page
declare -a APK_NAMES APK_URLS
while IFS= read -r line; do
  # match href="...apk" or href="...APK"
  url=$(echo "$line" | grep -oP 'href="\K[^"]+(?=\.apk"|\.APK")' | head -1)
  if [[ -n "$url" ]]; then
    # make absolute if relative
    if [[ "$url" != http* ]]; then
      url="${INSTALL_PAGE%/}/${url#/}"
    fi
    name=$(basename "$url")
    APK_NAMES+=("$name")
    APK_URLS+=("$url")
  fi
done < "$TMP_HTML"

TOTAL=${#APK_NAMES[@]}

if [[ $TOTAL -eq 0 ]]; then
  echo -e " ${R}✗ no APKs found on installer page.${NC}"
  exit 1
fi

echo -e " ${G}✓${NC} ${D}found ${TOTAL} APK(s)${NC}"
echo ""
echo -e "${D} ${SEP}${NC}"

for i in "${!APK_NAMES[@]}"; do
  num=$(( i + 1 ))
  echo -e " ${M}[${num}]${NC} ${APK_NAMES[$i]}"
done

echo -e "${D} ${SEP}${NC}"
echo ""
echo -ne " ${W}install which?${NC} ${D}(1-${TOTAL} or 'all')${NC} "
read -r CHOICE

install_apk() {
  local name="$1" url="$2"
  echo ""
  echo -e " ${D}· downloading ${name}...${NC}"
  curl -L "$url" -o "$TMP_APK" --progress-bar
  if [[ ! -s "$TMP_APK" ]]; then
    echo -e " ${R}✗ download failed.${NC}"
    return 1
  fi
  echo -e " ${D}· installing...${NC}"
  r=$(su -c "pm install -r $TMP_APK" 2>&1)
  rm -f "$TMP_APK"
  if echo "$r" | grep -qi "success"; then
    echo -e " ${G}✓ installed: ${name}${NC}"
  else
    echo -e " ${R}✗ install failed: ${r}${NC}"
  fi
}

header

if [[ "$CHOICE" == "all" ]]; then
  for i in "${!APK_NAMES[@]}"; do
    install_apk "${APK_NAMES[$i]}" "${APK_URLS[$i]}"
  done
elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= TOTAL )); then
  idx=$(( CHOICE - 1 ))
  install_apk "${APK_NAMES[$idx]}" "${APK_URLS[$idx]}"
else
  echo -e " ${Y}cancelled.${NC}"
fi

# ── DONE ─────────────────────────────────────────────────────
echo ""
echo -e "${D} ${SEP}${NC}"
echo -e " ${G}✓ done.${NC}"
echo -e "${D} ${SEP}${NC}"
echo ""
echo -ne " ${W}open editor?${NC} ${D}(y/n)${NC} "
read -r EDIT_ANS

if [[ "$EDIT_ANS" =~ ^[Yy]$ ]]; then
  clear
  if command -v nano &>/dev/null; then
    nano "$0" 2>/dev/null || echo -e " ${R}✗ file already deleted.${NC}"
  elif command -v vi &>/dev/null; then
    vi "$0" 2>/dev/null || echo -e " ${R}✗ file already deleted.${NC}"
  else
    echo -e " ${R}✗ no editor found. run: pkg install nano${NC}"
  fi
else
  clear
fi

echo -e " ${D}✦ saturnity · @lanavienrose${NC}"
echo ""
