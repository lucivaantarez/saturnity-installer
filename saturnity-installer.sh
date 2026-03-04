#!/data/data/com.termux/files/usr/bin/bash

# ╔══════════════════════════════════════════╗
# ║       SATURNITY AUTO INSTALLER           ║
# ║         by lanavienrose                  ║
# ╚══════════════════════════════════════════╝

# ── SET YOUR URL HERE ─────────────────────────
APK_URL="https://lucivaantarez.github.io/saturnity-installer/"
# ─────────────────────────────────────────────

R='\033[0;31m'
G='\033[0;32m'
C='\033[0;36m'
Y='\033[1;33m'
W='\033[1;37m'
D='\033[2;37m'
X='\033[0m'

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

check_root() {
    su -c "id" &>/dev/null && echo "root" || echo "normal"
}

get_apk_links() {
    local url="$1"
    python3 - "$url" <<'PYEOF'
import sys, re, json
from urllib.request import urlopen, Request
from urllib.parse import urljoin

url = sys.argv[1].rstrip("/")

def fetch(u):
    req = Request(u, headers={"User-Agent": "SaturnityInstaller/1.0"})
    return urlopen(req, timeout=15).read().decode("utf-8", errors="ignore")

def is_apk(name):
    n = name.lower()
    return n.endswith(".apk") or n.endswith(".apk.apk")

try:
    gh = re.match(r'https?://([^.]+)\.github\.io/([^/?#]+)', url)
    pd = re.match(r'https?://pixeldrain\.com/l/([^/?#]+)', url)

    if gh:
        owner, repo = gh.group(1), gh.group(2)
        data = json.loads(fetch(f"https://api.github.com/repos/{owner}/{repo}/releases/latest"))
        links = [a["browser_download_url"] for a in data.get("assets", []) if is_apk(a["name"])]
        print("\n".join(links))

    elif pd:
        list_id = pd.group(1)
        data = json.loads(fetch(f"https://pixeldrain.com/api/list/{list_id}"))
        links = [f"https://pixeldrain.com/api/file/{f['id']}?download"
                 for f in data.get("files", []) if is_apk(f["name"])]
        print("\n".join(links))

    else:
        html = fetch(url)
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

install_apk() {
    local url="$1"
    local mode="$2"
    local raw_name
    raw_name=$(basename "$url" | sed 's/?.*//' | python3 -c \
        "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
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

    if [[ "$mode" == "root" ]]; then
        echo -e "  ${W}Status :${X} ${Y}Installing silently (root)...${X}"
        local result
        result=$(su -c "pm install -r \"$filepath\"" 2>&1)
        if echo "$result" | grep -qi "success"; then
            echo -e "  ${G}✓ Installed successfully!${X}"
        else
            echo -e "  ${R}✗ Install failed: $result${X}"
            rm -f "$filepath"
            return 1
        fi
    else
        echo -e "  ${W}Status :${X} ${Y}Launching installer...${X}"
        termux-open "$filepath" 2>/dev/null \
        || am start -a android.intent.action.VIEW \
              -d "file://$filepath" \
              -t "application/vnd.android.package-archive" 2>/dev/null
        echo -e "  ${D}Press [Enter] once install is complete...${X}"
        read -r
    fi

    rm -f "$filepath"
    echo -e "  ${G}✓ APK deleted from device.${X}"
    sleep 1
}

main() {
    check_deps

    # ── Root check ────────────────────────────
    header
    echo -e "  ${Y}Checking root access...${X}"
    ROOT_MODE=$(check_root)
    if [[ "$ROOT_MODE" == "root" ]]; then
        echo -e "  ${G}✓ Root detected — silent install enabled!${X}"
    else
        echo -e "  ${Y}⚠ No root — manual confirm required per APK.${X}"
    fi
    sleep 1

    while true; do
        header
        [[ "$ROOT_MODE" == "root" ]] \
            && echo -e "  ${G}● Silent Install (Root)${X}" \
            || echo -e "  ${Y}● Manual Install (No Root)${X}"
        echo ""
        echo -e "  ${Y}Fetching available files...${X}"
        echo ""

        mapfile -t LINKS < <(get_apk_links "$APK_URL" 2>/dev/null)

        if [[ ${#LINKS[@]} -eq 0 ]]; then
            echo -e "  ${R}✗ No APK files found. Check your APK_URL.${X}"
            echo -ne "  Press [Enter] to retry..."
            read -r
            continue
        fi

        header
        [[ "$ROOT_MODE" == "root" ]] \
            && echo -e "  ${G}● Silent Install (Root)${X}" \
            || echo -e "  ${Y}● Manual Install (No Root)${X}"
        echo ""
        echo -e "  ${W}Available Files:${X}"
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

        header
        echo -e "  ${W}Installing ${#SELECTED[@]} file(s)...${X}"

        local failed=0
        for idx in "${SELECTED[@]}"; do
            install_apk "${LINKS[$idx]}" "$ROOT_MODE" || ((failed++))
        done

        header
        if [[ $failed -eq 0 ]]; then
            echo -e "  ${G}✓ All installs complete!${X}"
        else
            echo -e "  ${Y}⚠ Done with $failed failed install(s).${X}"
        fi
        echo ""
        echo -e "  ${D}Press [Enter] to go back...${X}"
        read -r

    done
}

main
