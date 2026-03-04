#!/data/data/com.termux/files/usr/bin/bash

# ╔══════════════════════════════════════════╗
# ║       SATURNITY AUTO INSTALLER           ║
# ║         by lanavienrose                  ║
# ╚══════════════════════════════════════════╝

# ── Colors ──────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
C='\033[0;36m'
Y='\033[1;33m'
W='\033[1;37m'
D='\033[2;37m'
X='\033[0m'

# ── Header ───────────────────────────────────
header() {
    clear
    echo -e "${C}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║       SATURNITY AUTO INSTALLER           ║"
    echo "  ╠══════════════════════════════════════════╣"
    echo "  ║           by lanavienrose                ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${X}"
}

# ── Install dependencies ──────────────────────
check_deps() {
    local missing=()
    for dep in curl wget python3; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${Y}  Installing dependencies: ${missing[*]}${X}"
        pkg install "${missing[@]}" -y &>/dev/null
    fi
}

# ── Fetch APK links from a URL ────────────────
get_apk_links() {
    local url="$1"
    python3 - "$url" <<'PYEOF'
import sys, re
from urllib.request import urlopen, Request
from urllib.parse import urljoin, unquote

url = sys.argv[1]
try:
    req = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    html = urlopen(req, timeout=12).read().decode("utf-8", errors="ignore")
    hrefs = re.findall(r'href=["\']([^"\']+\.apk(?:\.apk)?)["\']', html, re.IGNORECASE)
    seen, out = set(), []
    for h in hrefs:
        full = urljoin(url, h)
        if full not in seen:
            seen.add(full)
            out.append(full)
    print("\n".join(out))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# ── Parse selection string → indices ─────────
parse_selection() {
    local input="$1"
    local max="$2"
    local -n result_ref=$3
    result_ref=()

    if [[ "$input" == "all" ]]; then
        for ((i=0; i<max; i++)); do result_ref+=("$i"); done
        return
    fi

    if [[ "$input" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local s="${BASH_REMATCH[1]}" e="${BASH_REMATCH[2]}"
        for ((i=s; i<=e; i++)); do
            local idx=$((i-1))
            [[ $idx -ge 0 && $idx -lt max ]] && result_ref+=("$idx")
        done
        return
    fi

    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        part="${part// /}"
        [[ "$part" =~ ^[0-9]+$ ]] || continue
        local idx=$((part-1))
        [[ $idx -ge 0 && $idx -lt max ]] && result_ref+=("$idx")
    done
}

# ── Install one APK ───────────────────────────
install_apk() {
    local url="$1"
    local raw_name
    raw_name=$(basename "$url" | sed 's/?.*//' | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
    local filepath="/sdcard/Download/$raw_name"

    echo ""
    echo -e "  ${D}────────────────────────────────────────${X}"
    echo -e "  ${W}File   :${X} $raw_name"
    echo -e "  ${W}Status :${X} ${Y}Downloading...${X}"
    echo ""

    if ! wget -q --show-progress -O "$filepath" "$url" 2>&1; then
        echo -e "  ${R}✗ Download failed!${X}"
        sleep 2
        return 1
    fi

    echo ""
    echo -e "  ${G}✓ Download complete!${X}"
    echo -e "  ${W}Status :${X} ${Y}Launching installer...${X}"
    echo ""

    # Try multiple install methods
    termux-open "$filepath" 2>/dev/null \
    || am start -a android.intent.action.VIEW \
          -d "file://$filepath" \
          -t "application/vnd.android.package-archive" 2>/dev/null \
    || xdg-open "$filepath" 2>/dev/null

    echo -e "  ${D}Press [Enter] once the install is complete...${X}"
    read -r

    rm -f "$filepath"
    echo -e "  ${G}✓ APK deleted from device.${X}"
    sleep 1
}

# ── Main loop ─────────────────────────────────
main() {
    check_deps

    while true; do
        header
        echo -e "  ${W}Enter the APK download page URL:${X}"
        echo -ne "  ${C}>${X} "
        read -r URL

        [[ -z "$URL" ]] && continue

        echo ""
        echo -e "  ${Y}Fetching file list, please wait...${X}"
        echo ""

        mapfile -t LINKS < <(get_apk_links "$URL" 2>/dev/null)

        if [[ ${#LINKS[@]} -eq 0 ]]; then
            echo -e "  ${R}✗ No APK files found at that URL.${X}"
            echo -ne "  Press [Enter] to try again..."
            read -r
            continue
        fi

        # ── Selection loop ────────────────────
        while true; do
            header
            echo -e "  ${W}APK Files Found:${X}"
            echo -e "  ${D}────────────────────────────────────────${X}"
            echo ""

            for i in "${!LINKS[@]}"; do
                local fname
                fname=$(basename "${LINKS[$i]}" | sed 's/?.*//' | python3 -c \
                    "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
                printf "  ${C}[%2d]${X}  %s\n" "$((i+1))" "$fname"
            done

            echo ""
            echo -e "  ${D}────────────────────────────────────────${X}"
            echo -e "  ${W}Select files to install:${X}"
            echo -e "  ${D}Examples: ${Y}1,3,5${D}  |  ${Y}2-4${D}  |  ${Y}all${X}"
            echo -ne "  ${C}>${X} "
            read -r SELECTION

            [[ -z "$SELECTION" ]] && continue

            declare -a SELECTED
            parse_selection "$SELECTION" "${#LINKS[@]}" SELECTED

            if [[ ${#SELECTED[@]} -eq 0 ]]; then
                echo -e "  ${R}✗ Invalid selection, try again.${X}"
                sleep 1
                continue
            fi

            # ── Install selected ──────────────
            header
            echo -e "  ${W}Installing ${#SELECTED[@]} file(s)...${X}"

            local failed=0
            for idx in "${SELECTED[@]}"; do
                install_apk "${LINKS[$idx]}" || ((failed++))
            done

            header
            if [[ $failed -eq 0 ]]; then
                echo -e "  ${G}✓ All installs complete!${X}"
            else
                echo -e "  ${Y}⚠ Done with $failed failed download(s).${X}"
            fi
            echo ""
            echo -e "  ${D}Press [Enter] to return to main menu...${X}"
            read -r
            break  # back to URL input
        done

    done
}

main
