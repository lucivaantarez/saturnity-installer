#!/data/data/com.termux/files/usr/bin/bash
# curl -sL https://raw.githubusercontent.com/lucivaantarez/saturnity-installer/main/saturnity.sh -o saturnity.sh && bash saturnity.sh

G='\033[0;32m'; R='\033[0;31m'; M='\033[0;35m'; D='\033[2m'; NC='\033[0m'
TMP="/tmp/.sat"

cleanup() {
  rm -f "$TMP" 2>/dev/null
  [[ -f "$0" && "$0" != /proc/* ]] && rm -f "$0" 2>/dev/null
}
trap cleanup EXIT

APKS=(
  "W1|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W1.apk"
  "W2|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W2.apk"
  "W3|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W3.apk"
  "W4|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W4.apk"
  "W5|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W5.apk"
  "W6|https://github.com/lucivaantarez/saturnity-installer/releases/download/v1/W6.apk"
)

say()  { echo -e "$1"; }
ok()   { say " ${G}+ $1${NC}"; }
err()  { say " ${R}x $1${NC}"; }
info() { say " ${D}$1${NC}"; }
line() { say "${D} --------${NC}"; }

# ROOT
clear
say ""
say "${M} SATURNITY${NC}"
line
say ""
if ! su -c "id" >/dev/null 2>&1; then
  err "no root"; say ""; exit 1
fi
ok "root"
say ""

# UNINSTALL
info "scanning..."
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

COUNT=${#FOUND[@]}
if [[ $COUNT -gt 0 ]]; then
  info "removing $COUNT app(s)"
  for pkg in "${FOUND[@]}"; do
    # only show short name
    short="${pkg##*.}"
    echo -ne " ${D}$short...${NC} "
    r=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
    if echo "$r" | grep -qi "success\|deleted"; then
      say "${G}ok${NC}"
    else
      r2=$(su -c "pm uninstall $pkg" 2>&1)
      echo "$r2" | grep -qi "success" && say "${G}ok${NC}" || say "${R}fail${NC}"
    fi
  done
  ok "uninstalled"
else
  info "none found"
fi

sleep 1; clear

# INSTALL
say ""
say "${M} SATURNITY${NC}"
line
say ""
info "installing 6 apps"
info "201MB each, please wait"
say ""

PASS=0; FAIL=0
IDX=0

for entry in "${APKS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  IDX=$(( IDX + 1 ))

  say " ${D}[$IDX/6] $name${NC}"
  info "downloading..."

  curl -L --max-time 600 --retry 2 --retry-delay 3 \
    --progress-bar "$url" -o "$TMP" 2>&1

  if [[ ! -s "$TMP" ]]; then
    err "$name failed"; ((FAIL++))
    say ""; continue
  fi

  info "installing..."
  r=$(su -c "pm install -r $TMP" 2>&1)
  rm -f "$TMP"

  if echo "$r" | grep -qi "success"; then
    ok "$name done"; ((PASS++))
  else
    err "$name fail"; ((FAIL++))
  fi
  say ""
done

# DONE
line
ok "$PASS installed"
[[ $FAIL -gt 0 ]] && err "$FAIL failed"
line
say " ${D}@lanavienrose${NC}"
say ""
