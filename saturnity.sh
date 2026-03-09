#!/data/data/com.termux/files/usr/bin/bash
# saturnity — installer + uninstaller
# curl -sL https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main/saturnity.sh -o saturnity.sh && bash saturnity.sh

R='\033[0;31m'; G='\033[0;32m'; M='\033[0;35m'
Y='\033[1;33m'; W='\033[1;37m'; D='\033[2m'; NC='\033[0m'

GITHUB_REPO="lucivaantarez/saturnity-installer"
TMP_APK="/tmp/.sat_apk"
TMP_JSON="/tmp/.sat_json"

cleanup() {
  rm -f "$TMP_APK" "$TMP_JSON" 2>/dev/null
  [[ -f "$0" && "$0" != /proc/* ]] && rm -f "$0" 2>/dev/null
}
trap cleanup EXIT

COLS=$(tput cols 2>/dev/null || echo 42)
[[ $COLS -gt 50 ]] && COLS=50
W_IN=$(( COLS - 4 ))

line() { printf ' +'; printf '%*s' "$W_IN" '' | tr ' ' '-'; printf '+\n'; }
row()  { printf ' | %-*s |\n' "$(( W_IN - 1 ))" "$1"; }
blank(){ row ""; }

trunc() {
  local s="$1" max="${2:-$((W_IN-4))}"
  [[ ${#s} -gt $max ]] && echo "${s:0:$max}.." || echo "$s"
}

draw_header() {
  clear
  echo ""
  line
  row "  SATURNITY  installer"
  row "  @lanavienrose"
  line
  blank
}

# ── ROOT CHECK ───────────────────────────────────────────────
draw_header
if ! su -c "id" > /dev/null 2>&1; then
  row "  x  no root access. exiting."
  line
  echo ""
  exit 1
fi
row "  *  root ok"

# ── SCAN ROBLOX ──────────────────────────────────────────────
row "  .  scanning packages..."
blank

PATTERNS=("com.roblox.client" "com.roblox" "roblox")
FOUND=()
RAW=$(su -c "pm list packages" 2>/dev/null)

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r line_; do
    pkg=$(echo "${line_#package:}" | tr -d '[:space:]\r')
    already=0
    for e in "${FOUND[@]}"; do [[ "$e" == "$pkg" ]] && already=1 && break; done
    [[ $already -eq 0 && -n "$pkg" ]] && FOUND+=("$pkg")
  done < <(echo "$RAW" | grep -i "$pattern")
done

COUNT=${#FOUND[@]}

if [[ $COUNT -gt 0 ]]; then
  row "  found $COUNT roblox package(s):"
  for pkg in "${FOUND[@]}"; do
    row "    - $(trunc "$pkg" $((W_IN-6)))"
  done
  blank
  row "  uninstall before install? (y/n)"
  line
  echo ""
  printf '  > '; read -r UNINST_ANS

  if [[ "$UNINST_ANS" =~ ^[Yy]$ ]]; then
    draw_header
    row "  removing $COUNT package(s)..."
    blank
    US=0; UF=0
    for pkg in "${FOUND[@]}"; do
      short=$(trunc "$pkg" $((W_IN-12)))
      printf ' | %-*s' "$(( W_IN - 1 ))" "  - $short"
      r=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
      if echo "$r" | grep -qi "success\|deleted"; then
        printf '  ok |\n'; ((US++))
      else
        r2=$(su -c "pm uninstall $pkg" 2>&1)
        if echo "$r2" | grep -qi "success"; then
          printf '  ok |\n'; ((US++))
        else
          printf ' err |\n'; ((UF++))
        fi
      fi
    done
    blank
    if [[ $UF -eq 0 ]]; then
      row "  done. all $COUNT removed."
    else
      row "  done. $US removed, $UF failed."
    fi
    line
    echo ""
    sleep 1
  fi
else
  row "  no roblox packages found."
fi

# ── FETCH APKs via GITHUB API ────────────────────────────────
draw_header
row "  fetching releases..."
blank

if ! command -v curl &>/dev/null; then
  row "  x curl not found. run: pkg install curl"
  line; echo ""; exit 1
fi

curl -sL "https://api.github.com/repos/${GITHUB_REPO}/releases" \
  -H "Accept: application/vnd.github+json" \
  -o "$TMP_JSON" 2>/dev/null

if [[ ! -s "$TMP_JSON" ]]; then
  row "  x failed to reach GitHub API."
  row "    check internet connection."
  line; echo ""; exit 1
fi

# parse APK names + urls from JSON (no jq needed)
declare -a APK_NAMES APK_URLS
while IFS= read -r jline; do
  if echo "$jline" | grep -q '"browser_download_url"'; then
    url=$(echo "$jline" | grep -oP '(?<="browser_download_url": ")[^"]+')
    name=$(basename "$url")
    if echo "$name" | grep -qi '\.apk$'; then
      APK_NAMES+=("$name")
      APK_URLS+=("$url")
    fi
  fi
done < "$TMP_JSON"

TOTAL=${#APK_NAMES[@]}

if [[ $TOTAL -eq 0 ]]; then
  row "  x no APKs found in releases."
  row "    make sure you have published"
  row "    a GitHub Release with .apk assets."
  line; echo ""; exit 1
fi

row "  $TOTAL APK(s) available:"
blank
for i in "${!APK_NAMES[@]}"; do
  num=$(( i + 1 ))
  row "  [$num] $(trunc "${APK_NAMES[$i]}" $((W_IN-6)))"
done
blank
row "  install which? (1-$TOTAL or all)"
line
echo ""
printf '  > '; read -r CHOICE

install_apk() {
  local name="$1" url="$2"
  draw_header
  row "  downloading..."
  row "    $(trunc "$name" $((W_IN-4)))"
  line
  echo ""
  curl -L "$url" -o "$TMP_APK" --progress-bar 2>&1
  echo ""
  if [[ ! -s "$TMP_APK" ]]; then
    draw_header
    row "  x download failed."
    line; echo ""; return 1
  fi
  draw_header
  row "  installing $name..."
  blank
  r=$(su -c "pm install -r $TMP_APK" 2>&1)
  rm -f "$TMP_APK"
  if echo "$r" | grep -qi "success"; then
    row "  ok  installed successfully."
  else
    row "  x  install failed."
    row "     $r"
  fi
  line; echo ""
}

if [[ "$CHOICE" == "all" ]]; then
  for i in "${!APK_NAMES[@]}"; do
    install_apk "${APK_NAMES[$i]}" "${APK_URLS[$i]}"
  done
elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= TOTAL )); then
  idx=$(( CHOICE - 1 ))
  install_apk "${APK_NAMES[$idx]}" "${APK_URLS[$idx]}"
else
  draw_header
  row "  cancelled."
  line; echo ""
fi

# ── DONE ─────────────────────────────────────────────────────
draw_header
row "  all done."
blank
row "  open script in editor? (y/n)"
line
echo ""
printf '  > '; read -r EDIT_ANS

if [[ "$EDIT_ANS" =~ ^[Yy]$ ]]; then
  clear
  if command -v nano &>/dev/null; then
    nano "$0" 2>/dev/null || { echo "  file already deleted."; }
  elif command -v vi &>/dev/null; then
    vi "$0" 2>/dev/null || { echo "  file already deleted."; }
  else
    echo "  no editor found. run: pkg install nano"
  fi
fi

clear
echo ""
line
row "  saturnity  @lanavienrose"
line
echo ""
