#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#   SATURNITY — ROBLOX UNINSTALLER
#   by @lanavienrose
# ============================================================

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; M='\033[0;35m'; W='\033[1;37m'
DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'
SCRIPT_PATH="$(realpath "$0" 2>/dev/null || echo "$0")"

# ── CLEANUP TRAP ────────────────────────────────────────────
cleanup() {
  rm -f /tmp/.roblox_pkgs_tmp 2>/dev/null
  # Self-delete if saved as a real file (not piped)
  if [[ -f "$SCRIPT_PATH" && "$SCRIPT_PATH" != "/proc/"* ]]; then
    rm -f "$SCRIPT_PATH" 2>/dev/null
  fi
  echo ""
  echo -e "${DIM}  ✦ saturnity • @lanavienrose${NC}"
  echo ""
}
trap cleanup EXIT

# ── PROGRESS BAR ────────────────────────────────────────────
progress() {
  local pct=$1
  local label="$2"
  local width=34
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "\r  ${C}[${M}%s${C}]${NC} ${W}%3d%%${NC}  ${DIM}%s${NC}               " "$bar" "$pct" "$label"
}

smooth_progress() {
  local from=$1 to=$2 label="$3" delay="${4:-0.03}"
  for ((p=from; p<=to; p++)); do
    progress "$p" "$label"
    sleep "$delay"
  done
}

# ════════════════════════════════════════════════════════════
#   START
# ════════════════════════════════════════════════════════════
clear
echo ""
echo -e "${M}  ░${W}SATURNITY${M}░  ${DIM}Roblox Uninstaller${NC}"
echo -e "${DIM}  ──────────────────────────────────────────${NC}"
echo -e "  ${DIM}root-powered · no approval · auto-clean${NC}"
echo -e "${DIM}  ──────────────────────────────────────────${NC}"
echo ""
sleep 0.3

# ── STAGE 1 — BOOT (0→10%) ──────────────────────────────────
smooth_progress 0 5 "booting up..." 0.04
smooth_progress 5 10 "checking root access..." 0.04

if ! su -c "id" > /dev/null 2>&1; then
  echo ""
  echo -e "\n  ${R}[✗] Root not available. Exiting.${NC}"
  exit 1
fi

# ── STAGE 2 — SCAN (10→40%) ─────────────────────────────────
smooth_progress 10 20 "scanning packages..." 0.035
RAW_LIST=$(su -c "pm list packages" 2>/dev/null)
smooth_progress 20 30 "filtering roblox entries..." 0.03

PATTERNS=("com.roblox.client" "com.roblox" "roblox")
FOUND=()

for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r line; do
    pkg="${line#package:}"
    pkg="${pkg%%$'\r'}"
    pkg="$(echo "$pkg" | tr -d '[:space:]')"
    already=0
    for existing in "${FOUND[@]}"; do
      [[ "$existing" == "$pkg" ]] && already=1 && break
    done
    [[ $already -eq 0 && -n "$pkg" ]] && FOUND+=("$pkg")
  done < <(echo "$RAW_LIST" | grep -i "$pattern")
done

smooth_progress 30 40 "analyzing results..." 0.03
smooth_progress 40 50 "preparing uninstaller..." 0.03
COUNT=${#FOUND[@]}

echo ""
echo ""
echo -e "${DIM}  ──────────────────────────────────────────${NC}"

if [[ $COUNT -eq 0 ]]; then
  echo -e "  ${Y}[!]${NC} No Roblox packages found on this device."
  echo -e "${DIM}  ──────────────────────────────────────────${NC}"
  echo ""
  progress 100 "nothing to remove."
  echo ""
  exit 0
fi

echo -e "  ${W}Found ${M}${BOLD}${COUNT}${NC}${W} Roblox package(s):${NC}"
for i in "${!FOUND[@]}"; do
  echo -e "  ${M}·${NC} ${FOUND[$i]}"
done
echo -e "${DIM}  ──────────────────────────────────────────${NC}"
echo ""
sleep 0.3

# ── STAGE 3 — UNINSTALL (50→90%) ────────────────────────────
SUCCESS=0; FAILED=0

for i in "${!FOUND[@]}"; do
  pkg="${FOUND[$i]}"

  range_start=$(( 50 + (i * 40 / COUNT) ))
  range_end=$(( 50 + ((i + 1) * 40 / COUNT) ))
  mid=$(( (range_start + range_end) / 2 ))

  smooth_progress "$range_start" "$mid" "removing ${pkg}..." 0.025

  result=$(su -c "pm uninstall $pkg" 2>&1)
  if echo "$result" | grep -qi "success"; then
    smooth_progress "$mid" "$range_end" "✓ removed ${pkg}" 0.02
    ((SUCCESS++))
  else
    result2=$(su -c "pm uninstall --user 0 $pkg" 2>&1)
    if echo "$result2" | grep -qi "success\|deleted\|uninstalled"; then
      smooth_progress "$mid" "$range_end" "✓ removed ${pkg}" 0.02
      ((SUCCESS++))
    else
      smooth_progress "$mid" "$range_end" "✗ failed: ${pkg}" 0.02
      ((FAILED++))
    fi
  fi
done

# ── STAGE 4 — CLEANUP (90→100%) ─────────────────────────────
smooth_progress 90 95 "cleaning up cache..." 0.04
rm -f /tmp/.roblox_pkgs_tmp 2>/dev/null
smooth_progress 95 100 "all done." 0.04

# ── FINAL REPORT ─────────────────────────────────────────────
echo ""
echo ""
echo -e "${DIM}  ──────────────────────────────────────────${NC}"
if [[ $SUCCESS -eq $COUNT ]]; then
  echo -e "  ${G}${BOLD}✓ All ${COUNT} package(s) removed successfully.${NC}"
elif [[ $SUCCESS -gt 0 ]]; then
  echo -e "  ${Y}${BOLD}⚠ Partial: ${SUCCESS} removed, ${FAILED} failed.${NC}"
  echo -e "  ${DIM}Some packages may be system-level.${NC}"
else
  echo -e "  ${R}${BOLD}✗ Uninstall failed. Try a full root shell.${NC}"
fi
echo -e "${DIM}  ──────────────────────────────────────────${NC}"
