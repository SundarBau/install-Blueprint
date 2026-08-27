#!/bin/bash

# ============================================================
#                    BALE PTERODACTYL
#                       MANAGER
#
#  Pterodactyl Installer
#  Blueprint Manager
#  GitHub Blueprint Loader
#  Install / Remove / Update / List
#  Backup / Cache / System Status
#
#  GitHub:
#  https://github.com/SundarBau/install-Blueprint
#
#  Direct:
#  bash <(curl -fsSL https://raw.githubusercontent.com/SundarBau/install-Blueprint/main/addon-installer.sh)
# ============================================================

set -o pipefail

# ============================================================
# CONFIG
# ============================================================

PTERODACTYL_DIR="/var/www/pterodactyl"

BACKUP_DIR="/var/backups/bale-pterodactyl"

TEMP_DIR="/tmp/bale-pterodactyl"

SCRIPT_URL="https://raw.githubusercontent.com/SundarBau/install-Blueprint/main/addon-installer.sh"

PTERODACTYL_INSTALLER="https://pterodactyl-installer.se/"

mkdir -p "$TEMP_DIR" 2>/dev/null

# ============================================================
# COLORS
# ============================================================

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
WHITE="\e[97m"
GRAY="\e[90m"
BOLD="\e[1m"
RESET="\e[0m"

# ============================================================
# ROOT HANDLING
# ============================================================

if [ "$(id -u)" -ne 0 ]; then

    clear

    echo ""
    echo -e "${CYAN}${BOLD}============================================================${RESET}"
    echo -e "${CYAN}${BOLD}              BALE PTERODACTYL MANAGER${RESET}"
    echo -e "${CYAN}${BOLD}============================================================${RESET}"
    echo ""
    echo -e "${YELLOW}⚠ Root privileges are required.${RESET}"
    echo ""

    if ! command -v sudo >/dev/null 2>&1; then

        echo -e "${RED}✗ sudo is not installed.${RESET}"
        echo ""
        echo "Please login as root and run the script again."

        exit 1
    fi

    if ! command -v curl >/dev/null 2>&1; then

        echo -e "${YELLOW}Installing curl...${RESET}"

        sudo apt-get update -qq
        sudo apt-get install -y curl

        if ! command -v curl >/dev/null 2>&1; then

            echo -e "${RED}✗ curl installation failed.${RESET}"

            exit 1
        fi
    fi

    echo -e "${CYAN}🔐 Requesting sudo access...${RESET}"
    echo ""

    # --------------------------------------------------------
    # IMPORTANT FIX
    #
    # This works with:
    #
    # bash <(curl ...)
    #
    # We do NOT use:
    #
    # sudo bash "$0"
    #
    # because $0 can be /dev/fd/...
    # --------------------------------------------------------

    exec sudo env BALE_ROOT=1 bash -c \
        'curl -fsSL "https://raw.githubusercontent.com/SundarBau/install-Blueprint/main/addon-installer.sh" | BALE_ROOT=1 bash'

fi

# ============================================================
# ROOT CONFIRMATION
# ============================================================

if [ "$(id -u)" -ne 0 ]; then

    echo -e "${RED}✗ Unable to obtain root privileges.${RESET}"

    exit 1
fi

# ============================================================
# BASIC DEPENDENCIES
# ============================================================

install_dependencies() {

    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    command -v file >/dev/null 2>&1 || missing+=("file")

    if [ "${#missing[@]}" -eq 0 ]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}⚙ Installing required dependencies...${RESET}"
    echo ""

    if ! command -v apt-get >/dev/null 2>&1; then

        echo -e "${RED}✗ apt-get is unavailable.${RESET}"

        return 1
    fi

    apt-get update -qq

    if ! apt-get install -y "${missing[@]}"; then

        echo -e "${RED}✗ Dependency installation failed.${RESET}"

        return 1
    fi

    echo ""
    echo -e "${GREEN}✓ Dependencies installed.${RESET}"

    return 0
}

install_dependencies >/dev/null 2>&1 || true

# ============================================================
# BANNER
# ============================================================

banner() {

    clear

    echo -e "${CYAN}${BOLD}"

    cat <<'EOF'

██████╗  █████╗ ██╗     ███████╗
██╔══██╗██╔══██╗██║     ██╔════╝
██████╔╝███████║██║     █████╗
██╔══██╗██╔══██║██║     ██╔══╝
██████╔╝██║  ██║███████╗███████╗
╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝

██████╗ ████████╗██████╗ ██████╗  ██████╗
██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██╔═══██╗
██████╔╝   ██║   ██████╔╝██████╔╝██║   ██║
██╔═══╝    ██║   ██╔═══╝ ██╔══██╗██║   ██║
██║        ██║   ██║     ██║  ██║╚██████╔╝
╚═╝        ╚═╝   ╚═╝     ╚═╝  ╚═╝ ╚═════╝

              BALE PTERODACTYL MANAGER

EOF

    echo -e "${RESET}"

    echo -e "${GRAY}============================================================${RESET}"

    if [ -d "$PTERODACTYL_DIR" ]; then
        echo -e "${WHITE}Pterodactyl:${RESET} ${GREEN}INSTALLED${RESET}"
    else
        echo -e "${WHITE}Pterodactyl:${RESET} ${RED}NOT INSTALLED${RESET}"
    fi

    if command -v blueprint >/dev/null 2>&1; then
        echo -e "${WHITE}Blueprint:${RESET}   ${GREEN}DETECTED${RESET}"
    else
        echo -e "${WHITE}Blueprint:${RESET}   ${YELLOW}NOT DETECTED${RESET}"
    fi

    echo -e "${WHITE}Panel Path:${RESET}  ${CYAN}${PTERODACTYL_DIR}${RESET}"

    echo -e "${GRAY}============================================================${RESET}"
    echo ""
}

# ============================================================
# PAUSE
# ============================================================

pause_screen() {

    echo ""

    read -rp "Press Enter to continue..."
}

# ============================================================
# PTERODACTYL CHECK
# ============================================================

check_pterodactyl() {

    if [ ! -d "$PTERODACTYL_DIR" ]; then

        echo ""
        echo -e "${RED}✗ Pterodactyl Panel directory was not found.${RESET}"
        echo ""
        echo -e "${YELLOW}Expected:${RESET}"
        echo "$PTERODACTYL_DIR"

        return 1
    fi

    return 0
}

# ============================================================
# BLUEPRINT CHECK
# ============================================================

check_blueprint() {

    if ! command -v blueprint >/dev/null 2>&1; then

        echo ""
        echo -e "${RED}✗ Blueprint CLI is not installed or not in PATH.${RESET}"
        echo ""
        echo -e "${YELLOW}Check with:${RESET}"
        echo "which blueprint"
        echo "blueprint --help"
        echo "blueprint --version"

        return 1
    fi

    return 0
}

# ============================================================
# CONFIRM
# ============================================================

confirm_action() {

    local message="$1"

    read -rp "$(echo -e "${YELLOW}${message} [y/N]: ${RESET}")" answer

    [[ "$answer" =~ ^[Yy]$ ]]
}

# ============================================================
# SPINNER
# ============================================================

spinner() {

    local pid="$1"
    local message="$2"

    local frames=(
        "⠋"
        "⠙"
        "⠹"
        "⠸"
        "⠼"
        "⠴"
        "⠦"
        "⠧"
        "⠇"
        "⠏"
    )

    while kill -0 "$pid" 2>/dev/null; do

        for frame in "${frames[@]}"; do

            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi

            printf "\r${MAGENTA}${message} ${frame}${RESET}"

            sleep 0.1

        done

    done

    wait "$pid"

    local status=$?

    if [ "$status" -eq 0 ]; then

        printf "\r${GREEN}✓ ${message} complete.${RESET}          \n"

    else

        printf "\r${RED}✗ ${message} failed.${RESET}            \n"
    fi

    return "$status"
}

# ============================================================
# FIND LOCAL BLUEPRINT FILES
# ============================================================

find_blueprints() {

    FILES=()

    if [ ! -d "$PTERODACTYL_DIR" ]; then
        return
    fi

    mapfile -t FILES < <(

        find "$PTERODACTYL_DIR" \
            -maxdepth 2 \
            -type f \
            -iname "*.blueprint" \
            -printf "%p\n" \
            2>/dev/null |
        sort -f

    )
}

# ============================================================
# INSTALL PTERODACTYL
# ============================================================

install_pterodactyl() {

    banner

    echo -e "${BLUE}${BOLD}🚀 PTERODACTYL INSTALLER${RESET}"
    echo ""

    echo -e "${WHITE}Official installer:${RESET}"
    echo -e "${CYAN}${PTERODACTYL_INSTALLER}${RESET}"
    echo ""

    if [ -d "$PTERODACTYL_DIR" ]; then

        echo -e "${YELLOW}⚠ Pterodactyl appears to already be installed.${RESET}"
        echo ""

        if ! confirm_action "Launch installer anyway"; then

            echo ""
            echo -e "${YELLOW}Cancelled.${RESET}"

            pause_screen

            return
        fi

    else

        if ! confirm_action "Start Pterodactyl installation"; then

            echo ""
            echo -e "${YELLOW}Cancelled.${RESET}"

            pause_screen

            return
        fi

    fi

    echo ""
    echo -e "${CYAN}Downloading installer...${RESET}"
    echo ""

    local installer_file

    installer_file="$TEMP_DIR/pterodactyl-installer.sh"

    rm -f "$installer_file"

    if ! curl -fsSL \
        --connect-timeout 15 \
        --max-time 120 \
        -A "BALE-Pterodactyl-Manager" \
        "$PTERODACTYL_INSTALLER" \
        -o "$installer_file"; then

        echo ""
        echo -e "${RED}✗ Failed to download Pterodactyl installer.${RESET}"

        pause_screen

        return
    fi

    chmod 700 "$installer_file"

    echo -e "${GREEN}✓ Installer downloaded.${RESET}"
    echo ""

    bash "$installer_file"

    local status=$?

    rm -f "$installer_file"

    echo ""

    if [ "$status" -eq 0 ]; then

        echo -e "${GREEN}✓ Pterodactyl installer completed.${RESET}"

    else

        echo -e "${RED}✗ Installer exited with code ${status}.${RESET}"

    fi

    pause_screen
}

# ============================================================
# BLUEPRINT INFORMATION
# ============================================================

blueprint_info() {

    banner

    echo -e "${BLUE}${BOLD}🔧 BLUEPRINT INFORMATION${RESET}"
    echo ""

    if ! check_blueprint; then

        pause_screen

        return
    fi

    echo -e "${GREEN}✓ Blueprint executable:${RESET}"
    echo -e "${WHITE}$(command -v blueprint)${RESET}"
    echo ""

    echo -e "${CYAN}Version:${RESET}"

    blueprint --version 2>&1 || true

    echo ""

    echo -e "${CYAN}Available commands:${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    blueprint --help 2>&1 | head -n 100

    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    pause_screen
}

# ============================================================
# INSTALL ONE BLUEPRINT
# ============================================================

install_one() {

    banner

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    if ! check_blueprint; then

        pause_screen

        return
    fi

    find_blueprints

    echo -e "${BLUE}${BOLD}📦 LOCAL BLUEPRINT FILES${RESET}"
    echo ""

    if [ "${#FILES[@]}" -eq 0 ]; then

        echo -e "${YELLOW}No .blueprint files found in the panel directory.${RESET}"
        echo ""

        echo "Use option 5 to download an addon from GitHub."

        pause_screen

        return
    fi

    local i=1

    for file in "${FILES[@]}"; do

        echo -e "  ${CYAN}${i}.${RESET} ${WHITE}$(basename "$file")${RESET}"

        ((i++))

    done

    echo ""

    read -rp "$(echo -e "${YELLOW}Select blueprint number: ${RESET}")" choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then

        echo -e "${RED}✗ Invalid selection.${RESET}"

        pause_screen

        return
    fi

    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#FILES[@]}" ]; then

        echo -e "${RED}✗ Invalid selection.${RESET}"

        pause_screen

        return
    fi

    local selected="${FILES[$((choice-1))]}"

    echo ""
    echo -e "${BLUE}⚡ Installing:${RESET}"
    echo -e "${MAGENTA}$(basename "$selected")${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    (
        blueprint -i "$(basename "$selected")"
    ) >"$TEMP_DIR/install.log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Installing Blueprint"; then

        echo ""
        echo -e "${GREEN}✓ Installation successful.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Installation failed.${RESET}"
        echo ""
        echo -e "${YELLOW}Last output:${RESET}"
        tail -n 40 "$TEMP_DIR/install.log"
    fi

    pause_screen
}

# ============================================================
# INSTALL ALL BLUEPRINTS
# ============================================================

install_all() {

    banner

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    if ! check_blueprint; then

        pause_screen

        return
    fi

    find_blueprints

    echo -e "${BLUE}${BOLD}📦 INSTALL ALL BLUEPRINTS${RESET}"
    echo ""

    if [ "${#FILES[@]}" -eq 0 ]; then

        echo -e "${YELLOW}No Blueprint files found.${RESET}"

        pause_screen

        return
    fi

    echo -e "${WHITE}Found ${#FILES[@]} Blueprint file(s):${RESET}"
    echo ""

    for file in "${FILES[@]}"; do

        echo -e "  ${CYAN}•${RESET} $(basename "$file")"

    done

    echo ""

    if ! confirm_action "Install all Blueprints"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    local success=0
    local failed=0

    for file in "${FILES[@]}"; do

        local filename

        filename="$(basename "$file")"

        echo ""
        echo -e "${CYAN}➡ Installing:${RESET} ${MAGENTA}${filename}${RESET}"

        (
            blueprint -i "$filename"
        ) >"$TEMP_DIR/install.log" 2>&1 &

        local pid=$!

        if spinner "$pid" "Installing $filename"; then

            ((success++))

        else

            ((failed++))

            echo ""
            echo -e "${RED}Installation output:${RESET}"

            tail -n 30 "$TEMP_DIR/install.log"

        fi

    done

    echo ""
    echo -e "${GRAY}============================================================${RESET}"
    echo -e "${GREEN}✓ Successful: ${success}${RESET}"
    echo -e "${RED}✗ Failed:     ${failed}${RESET}"
    echo -e "${GRAY}============================================================${RESET}"

    pause_screen
}

# ============================================================
# GITHUB ADDON LOADER
# ============================================================

addon_load() {

    banner

    echo -e "${BLUE}${BOLD}📥 GITHUB BLUEPRINT ADDON LOADER${RESET}"
    echo ""

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    if ! check_blueprint; then

        pause_screen

        return
    fi

    if ! install_dependencies; then

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo -e "${YELLOW}GitHub repository:${RESET}"
    echo ""
    echo -e "${GRAY}Example:${RESET}"
    echo "https://github.com/OWNER/REPOSITORY"
    echo ""

    read -rp "$(echo -e "${CYAN}Repository URL: ${RESET}")" repo_url

    repo_url="${repo_url//[[:space:]]/}"
    repo_url="${repo_url%/}"
    repo_url="${repo_url%.git}"

    if [ -z "$repo_url" ]; then

        echo -e "${RED}✗ Repository URL is empty.${RESET}"

        pause_screen

        return
    fi

    if [[ ! "$repo_url" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then

        echo ""
        echo -e "${RED}✗ Invalid GitHub URL.${RESET}"
        echo ""
        echo "Correct:"
        echo "https://github.com/OWNER/REPOSITORY"

        pause_screen

        return
    fi

    local repo_path

    repo_path="${repo_url#https://github.com/}"

    local api

    api="https://api.github.com/repos/${repo_path}/releases/latest"

    echo ""
    echo -e "${CYAN}🔎 Checking latest GitHub release...${RESET}"
    echo ""

    local release_json

    release_json=$(curl -fsSL \
        --connect-timeout 15 \
        --max-time 60 \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: BALE-Pterodactyl-Manager" \
        "$api" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$release_json" ]; then

        echo -e "${RED}✗ Could not access GitHub repository/release.${RESET}"

        pause_screen

        return
    fi

    local github_message

    github_message=$(echo "$release_json" | jq -r '.message // empty')

    if [ -n "$github_message" ]; then

        echo -e "${RED}✗ GitHub: ${github_message}${RESET}"

        pause_screen

        return
    fi

    local tag_name
    local release_name

    tag_name=$(echo "$release_json" | jq -r '.tag_name // empty')

    release_name=$(echo "$release_json" | jq -r '.name // empty')

    if [ -z "$tag_name" ]; then

        echo -e "${RED}✗ No published GitHub Release found.${RESET}"
        echo ""
        echo -e "${YELLOW}The repository needs a Release containing a .blueprint asset.${RESET}"

        pause_screen

        return
    fi

    echo -e "${GREEN}✓ Release:${RESET} ${MAGENTA}${tag_name}${RESET}"

    if [ -n "$release_name" ] && [ "$release_name" != "null" ]; then

        echo -e "${WHITE}Name:${RESET} $release_name"

    fi

    echo ""

    local blueprint_file
    local blueprint_url

    blueprint_file=$(echo "$release_json" |
        jq -r '
        .assets[]?
        | select(.name | ascii_downcase | endswith(".blueprint"))
        | .name
        ' |
        head -n 1)

    blueprint_url=$(echo "$release_json" |
        jq -r '
        .assets[]?
        | select(.name | ascii_downcase | endswith(".blueprint"))
        | .browser_download_url
        ' |
        head -n 1)

    if [ -z "$blueprint_file" ] || [ -z "$blueprint_url" ]; then

        echo -e "${RED}✗ No .blueprint asset found.${RESET}"
        echo ""

        echo -e "${YELLOW}Available assets:${RESET}"

        echo "$release_json" |
            jq -r '.assets[]?.name' |
            while IFS= read -r asset; do

                [ -n "$asset" ] &&
                    echo -e "  ${WHITE}• ${asset}${RESET}"

            done

        pause_screen

        return
    fi

    echo -e "${GREEN}✓ Blueprint:${RESET} ${MAGENTA}${blueprint_file}${RESET}"
    echo ""

    local destination="$PTERODACTYL_DIR/$blueprint_file"
    local temporary="$TEMP_DIR/$blueprint_file"

    if [ -f "$destination" ]; then

        echo -e "${YELLOW}⚠ Blueprint already exists.${RESET}"
        echo ""

        if ! confirm_action "Replace existing Blueprint"; then

            echo -e "${YELLOW}Cancelled.${RESET}"

            pause_screen

            return
        fi

        mkdir -p "$BACKUP_DIR/blueprints"

        local backup_file

        backup_file="$BACKUP_DIR/blueprints/${blueprint_file}.$(date '+%Y%m%d-%H%M%S').bak"

        cp -f "$destination" "$backup_file"

        echo -e "${GREEN}✓ Old Blueprint backed up.${RESET}"
    fi

    rm -f "$temporary"

    echo ""
    echo -e "${BLUE}📥 Downloading...${RESET}"
    echo ""

    if ! curl -fL \
        --progress-bar \
        --connect-timeout 15 \
        --max-time 300 \
        -H "User-Agent: BALE-Pterodactyl-Manager" \
        "$blueprint_url" \
        -o "$temporary"; then

        echo ""
        echo -e "${RED}✗ Download failed.${RESET}"

        rm -f "$temporary"

        pause_screen

        return
    fi

    if [ ! -s "$temporary" ]; then

        echo -e "${RED}✗ Downloaded file is empty.${RESET}"

        rm -f "$temporary"

        pause_screen

        return
    fi

    echo ""
    echo -e "${GREEN}✓ Download completed.${RESET}"

    mv -f "$temporary" "$destination"

    chmod 644 "$destination"

    echo ""
    echo -e "${GREEN}✓ Blueprint saved.${RESET}"

    echo ""
    echo -e "${BLUE}⚡ Installing Blueprint...${RESET}"
    echo ""

    if blueprint -i "$blueprint_file"; then

        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║       ✓ ADDON INSTALLED SUCCESSFULLY              ║${RESET}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════╝${RESET}"

    else

        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║          ✗ ADDON INSTALL FAILED                   ║${RESET}"
        echo -e "${RED}╚════════════════════════════════════════════════════╝${RESET}"

    fi

    pause_screen
}

# ============================================================
# LIST INSTALLED ADDONS
#
# FIXED:
#
# 1. Try blueprint -list
# 2. Try blueprint list
# 3. Try blueprint --list
# 4. Show Blueprint help if needed
# 5. Search actual Blueprint manifests
# 6. Search installed Blueprint directories
# 7. Search .blueprint files
#
# ============================================================

list_installed() {

    banner

    echo -e "${BLUE}${BOLD}📋 INSTALLED BLUEPRINT ADDONS${RESET}"
    echo ""

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    if ! check_blueprint; then

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    local listed=0

    # --------------------------------------------------------
    # METHOD 1
    # --------------------------------------------------------

    echo -e "${CYAN}🔎 Method 1: blueprint -list${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    local output

    output=$(blueprint -list 2>&1)

    local status=$?

    if [ "$status" -eq 0 ] && [ -n "$output" ]; then

        echo "$output"

        listed=1

    else

        echo -e "${GRAY}Not supported or returned no results.${RESET}"
    fi

    echo ""

    # --------------------------------------------------------
    # METHOD 2
    # --------------------------------------------------------

    if [ "$listed" -eq 0 ]; then

        echo -e "${CYAN}🔎 Method 2: blueprint list${RESET}"
        echo -e "${GRAY}------------------------------------------------------------${RESET}"

        output=$(blueprint list 2>&1)

        status=$?

        if [ "$status" -eq 0 ] && [ -n "$output" ]; then

            echo "$output"

            listed=1

        else

            echo -e "${GRAY}Not supported or returned no results.${RESET}"
        fi

        echo ""
    fi

    # --------------------------------------------------------
    # METHOD 3
    # --------------------------------------------------------

    if [ "$listed" -eq 0 ]; then

        echo -e "${CYAN}🔎 Method 3: blueprint --list${RESET}"
        echo -e "${GRAY}------------------------------------------------------------${RESET}"

        output=$(blueprint --list 2>&1)

        status=$?

        if [ "$status" -eq 0 ] && [ -n "$output" ]; then

            echo "$output"

            listed=1

        else

            echo -e "${GRAY}Not supported or returned no results.${RESET}"
        fi

        echo ""
    fi

    # --------------------------------------------------------
    # FILESYSTEM SCAN
    # --------------------------------------------------------

    echo -e "${CYAN}🔎 Filesystem Blueprint scan${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    local manifest_count=0
    local blueprint_count=0
    local directory_count=0

    # --------------------------------------------------------
    # Find .blueprint files
    # --------------------------------------------------------

    while IFS= read -r -d '' file; do

        ((blueprint_count++))

        echo -e "${GREEN}✓ Blueprint file:${RESET}"
        echo -e "  ${WHITE}$(basename "$file")${RESET}"
        echo -e "  ${GRAY}$file${RESET}"

    done < <(

        find "$PTERODACTYL_DIR" \
            -type f \
            -iname "*.blueprint" \
            -print0 \
            2>/dev/null

    )

    if [ "$blueprint_count" -eq 0 ]; then

        echo -e "${GRAY}No .blueprint files found.${RESET}"

    fi

    echo ""

    # --------------------------------------------------------
    # Find conf.yml / blueprint.yml manifests
    # --------------------------------------------------------

    echo -e "${CYAN}🔎 Blueprint manifest scan${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    while IFS= read -r -d '' file; do

        ((manifest_count++))

        local manifest_dir

        manifest_dir="$(dirname "$file")"

        echo -e "${GREEN}✓ Manifest:${RESET}"
        echo -e "  ${WHITE}$file${RESET}"

        # Try extracting common name fields.
        if grep -qiE '^(name|id|identifier):' "$file" 2>/dev/null; then

            grep -iE '^(name|id|identifier):' "$file" |
                head -n 5 |
                sed 's/^/  /'

        fi

        echo ""

    done < <(

        find "$PTERODACTYL_DIR" \
            -type f \
            \( \
                -iname "conf.yml" \
                -o \
                -iname "blueprint.yml" \
                -o \
                -iname "blueprint.yaml" \
            \) \
            -print0 \
            2>/dev/null

    )

    if [ "$manifest_count" -eq 0 ]; then

        echo -e "${GRAY}No Blueprint manifests found.${RESET}"

    fi

    echo ""

    # --------------------------------------------------------
    # Common Blueprint directories
    # --------------------------------------------------------

    echo -e "${CYAN}🔎 Blueprint directory scan${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    local dirs=(
        "$PTERODACTYL_DIR/blueprints"
        "$PTERODACTYL_DIR/app/blueprints"
        "$PTERODACTYL_DIR/storage/blueprint"
        "$PTERODACTYL_DIR/storage/blueprints"
        "$PTERODACTYL_DIR/resources/blueprints"
    )

    for dir in "${dirs[@]}"; do

        if [ -d "$dir" ]; then

            ((directory_count++))

            echo -e "${GREEN}✓${RESET} ${WHITE}$dir${RESET}"

            find "$dir" \
                -mindepth 1 \
                -maxdepth 2 \
                -type d \
                -printf "    • %f\n" \
                2>/dev/null |
            head -n 50

        fi

    done

    if [ "$directory_count" -eq 0 ]; then

        echo -e "${GRAY}No common Blueprint directories detected.${RESET}"

    fi

    echo ""

    # --------------------------------------------------------
    # If nothing detected
    # --------------------------------------------------------

    if [ "$listed" -eq 0 ] &&
       [ "$blueprint_count" -eq 0 ] &&
       [ "$manifest_count" -eq 0 ] &&
       [ "$directory_count" -eq 0 ]; then

        echo -e "${YELLOW}⚠ BALE could not detect installed addons automatically.${RESET}"
        echo ""

        echo -e "${CYAN}Your Blueprint CLI commands:${RESET}"
        echo -e "${GRAY}------------------------------------------------------------${RESET}"

        blueprint --help 2>&1 | head -n 100

        echo -e "${GRAY}------------------------------------------------------------${RESET}"

        echo ""
        echo -e "${YELLOW}This means your installed Blueprint version may store addon${RESET}"
        echo -e "${YELLOW}information somewhere different from the standard locations.${RESET}"

    fi

    echo ""
    echo -e "${GRAY}============================================================${RESET}"
    echo -e "${GREEN}✓ Addon scan completed.${RESET}"
    echo -e "${GRAY}============================================================${RESET}"

    pause_screen
}

# ============================================================
# REMOVE ADDON
# ============================================================

remove_addon() {

    banner

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    if ! check_blueprint; then

        pause_screen

        return
    fi

    echo -e "${YELLOW}${BOLD}🗑 REMOVE BLUEPRINT ADDON${RESET}"
    echo ""

    echo -e "${GRAY}Example: universalmanager${RESET}"
    echo ""

    read -rp "$(echo -e "${CYAN}Addon name: ${RESET}")" addon

    addon="${addon//[[:space:]]/}"

    if [ -z "$addon" ]; then

        echo -e "${RED}✗ No addon name entered.${RESET}"

        pause_screen

        return
    fi

    if [[ "$addon" =~ [^a-zA-Z0-9_.-] ]]; then

        echo -e "${RED}✗ Invalid addon name.${RESET}"

        pause_screen

        return
    fi

    echo ""

    if ! confirm_action "Remove $addon"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    (
        blueprint -remove "$addon"
    ) >"$TEMP_DIR/remove.log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Removing $addon"; then

        echo ""
        echo -e "${GREEN}✓ Remove command completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Remove command failed.${RESET}"
        echo ""

        tail -n 40 "$TEMP_DIR/remove.log"

    fi

    pause_screen
}

# ============================================================
# UPDATE ADDON
# ============================================================

update_addon() {

    banner

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    if ! check_blueprint; then

        pause_screen

        return
    fi

    echo -e "${BLUE}${BOLD}🔄 UPDATE BLUEPRINT ADDON${RESET}"
    echo ""

    read -rp "$(echo -e "${CYAN}Addon name: ${RESET}")" addon

    addon="${addon//[[:space:]]/}"

    if [ -z "$addon" ]; then

        echo -e "${RED}✗ No addon name entered.${RESET}"

        pause_screen

        return
    fi

    if [[ "$addon" =~ [^a-zA-Z0-9_.-] ]]; then

        echo -e "${RED}✗ Invalid addon name.${RESET}"

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo ""

    (
        blueprint -update "$addon"
    ) >"$TEMP_DIR/update.log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Updating $addon"; then

        echo ""
        echo -e "${GREEN}✓ Update completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Update failed.${RESET}"
        echo ""

        tail -n 40 "$TEMP_DIR/update.log"

    fi

    pause_screen
}

# ============================================================
# SYSTEM STATUS
# ============================================================

system_status() {

    banner

    echo -e "${BLUE}${BOLD}📊 SYSTEM STATUS${RESET}"
    echo ""

    echo -e "${CYAN}SYSTEM${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    if [ -f /etc/os-release ]; then

        . /etc/os-release

        echo -e "${WHITE}OS:${RESET}         $PRETTY_NAME"

    fi

    echo -e "${WHITE}Kernel:${RESET}     $(uname -r)"
    echo -e "${WHITE}Hostname:${RESET}   $(hostname)"

    echo ""

    echo -e "${CYAN}PTERODACTYL${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    if [ -d "$PTERODACTYL_DIR" ]; then

        echo -e "${WHITE}Panel:${RESET}      ${GREEN}INSTALLED${RESET}"

        if [ -f "$PTERODACTYL_DIR/composer.json" ]; then

            echo -e "${WHITE}Composer:${RESET}   ${GREEN}Detected${RESET}"

        fi

    else

        echo -e "${WHITE}Panel:${RESET}      ${RED}NOT INSTALLED${RESET}"

    fi

    echo ""

    echo -e "${CYAN}BLUEPRINT${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    if command -v blueprint >/dev/null 2>&1; then

        echo -e "${WHITE}CLI:${RESET}        ${GREEN}INSTALLED${RESET}"
        echo -e "${WHITE}Path:${RESET}       $(command -v blueprint)"

        echo -e "${WHITE}Version:${RESET}"

        blueprint --version 2>&1 || true

    else

        echo -e "${WHITE}CLI:${RESET}        ${RED}NOT FOUND${RESET}"

    fi

    echo ""

    echo -e "${CYAN}SERVICES${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    local services=(
        nginx
        mysql
        mariadb
        redis-server
        redis
        pteroq
        wings
        docker
    )

    for service in "${services[@]}"; do

        if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then

            if systemctl is-active --quiet "$service" 2>/dev/null; then

                echo -e "  ${GREEN}●${RESET} ${service}: ${GREEN}RUNNING${RESET}"

            else

                echo -e "  ${RED}●${RESET} ${service}: ${RED}STOPPED${RESET}"

            fi

        fi

    done

    echo ""

    echo -e "${CYAN}DISK${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    df -h "$PTERODACTYL_DIR" 2>/dev/null || df -h /

    echo ""

    echo -e "${CYAN}MEMORY${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    free -h 2>/dev/null || true

    pause_screen
}

# ============================================================
# BACKUP PTERODACTYL
# ============================================================

backup_pterodactyl() {

    banner

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    echo -e "${BLUE}${BOLD}💾 PTERODACTYL BACKUP${RESET}"
    echo ""

    mkdir -p "$BACKUP_DIR"

    local timestamp

    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"

    local backup_file

    backup_file="$BACKUP_DIR/pterodactyl-$timestamp.tar.gz"

    echo -e "${WHITE}Backup file:${RESET}"
    echo -e "${CYAN}$backup_file${RESET}"
    echo ""

    if ! confirm_action "Create backup"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    echo ""

    (
        tar \
            --exclude="$PTERODACTYL_DIR/storage/logs/*" \
            --exclude="$PTERODACTYL_DIR/storage/framework/cache/*" \
            -czf "$backup_file" \
            -C /var/www \
            pterodactyl
    ) >"$TEMP_DIR/backup.log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Creating backup"; then

        echo ""
        echo -e "${GREEN}✓ Backup created.${RESET}"
        echo ""

        ls -lh "$backup_file"

    else

        echo ""
        echo -e "${RED}✗ Backup failed.${RESET}"
        echo ""

        tail -n 40 "$TEMP_DIR/backup.log"

        rm -f "$backup_file"

    fi

    pause_screen
}

# ============================================================
# CLEAR PTERODACTYL CACHE
# ============================================================

clear_cache() {

    banner

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    echo -e "${BLUE}${BOLD}🧹 CLEAR PTERODACTYL CACHE${RESET}"
    echo ""

    if ! confirm_action "Clear Laravel cache"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo ""
    echo -e "${CYAN}Running php artisan optimize:clear...${RESET}"
    echo ""

    if php artisan optimize:clear; then

        echo ""
        echo -e "${GREEN}✓ Laravel cache cleared.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Cache clear failed.${RESET}"

    fi

    echo ""
    echo -e "${CYAN}Fixing permissions...${RESET}"

    if [ -d "$PTERODACTYL_DIR/storage" ]; then

        chown -R www-data:www-data \
            "$PTERODACTYL_DIR/storage" \
            2>/dev/null || true

        chmod -R 775 \
            "$PTERODACTYL_DIR/storage" \
            2>/dev/null || true

    fi

    if [ -d "$PTERODACTYL_DIR/bootstrap/cache" ]; then

        chown -R www-data:www-data \
            "$PTERODACTYL_DIR/bootstrap/cache" \
            2>/dev/null || true

        chmod -R 775 \
            "$PTERODACTYL_DIR/bootstrap/cache" \
            2>/dev/null || true

    fi

    echo -e "${GREEN}✓ Permissions checked.${RESET}"

    echo ""

    if systemctl list-unit-files pteroq.service >/dev/null 2>&1; then

        if systemctl is-active --quiet pteroq; then

            systemctl restart pteroq 2>/dev/null || true

            echo -e "${GREEN}✓ pteroq restarted.${RESET}"

        fi

    fi

    if systemctl is-active --quiet nginx 2>/dev/null; then

        systemctl reload nginx 2>/dev/null || true

        echo -e "${GREEN}✓ nginx reloaded.${RESET}"

    fi

    pause_screen
}

# ============================================================
# UPDATE MANAGER
# ============================================================

update_manager() {

    banner

    echo -e "${BLUE}${BOLD}🔄 UPDATE BALE MANAGER${RESET}"
    echo ""

    echo -e "${WHITE}Source:${RESET}"
    echo -e "${CYAN}${SCRIPT_URL}${RESET}"
    echo ""

    if ! command -v curl >/dev/null 2>&1; then

        echo -e "${RED}✗ curl is unavailable.${RESET}"

        pause_screen

        return
    fi

    local test_file

    test_file="$TEMP_DIR/latest-bale.sh"

    rm -f "$test_file"

    if curl -fsSL \
        --connect-timeout 15 \
        --max-time 60 \
        -A "BALE-Pterodactyl-Manager" \
        "$SCRIPT_URL" \
        -o "$test_file"; then

        if [ -s "$test_file" ]; then

            echo -e "${GREEN}✓ Latest BALE script is available.${RESET}"
            echo ""
            echo -e "${YELLOW}Because you launch BALE directly from GitHub,${RESET}"
            echo -e "${YELLOW}the next GitHub launch automatically uses the latest version.${RESET}"

        else

            echo -e "${RED}✗ Downloaded update is empty.${RESET}"

        fi

    else

        echo -e "${RED}✗ Could not download latest BALE version.${RESET}"

    fi

    rm -f "$test_file"

    pause_screen
}

# ============================================================
# RESTART PTERODACTYL SERVICES
# ============================================================

restart_services() {

    banner

    echo -e "${BLUE}${BOLD}🔄 RESTART PTERODACTYL SERVICES${RESET}"
    echo ""

    if ! check_pterodactyl; then

        pause_screen

        return
    fi

    local restarted=0

    if systemctl list-unit-files nginx.service >/dev/null 2>&1; then

        echo -e "${CYAN}Restarting nginx...${RESET}"

        systemctl restart nginx 2>/dev/null && {

            echo -e "${GREEN}✓ nginx restarted.${RESET}"

            ((restarted++))

        } || {

            echo -e "${RED}✗ nginx failed.${RESET}"

        }

    fi

    if systemctl list-unit-files pteroq.service >/dev/null 2>&1; then

        echo -e "${CYAN}Restarting pteroq...${RESET}"

        systemctl restart pteroq 2>/dev/null && {

            echo -e "${GREEN}✓ pteroq restarted.${RESET}"

            ((restarted++))

        } || {

            echo -e "${RED}✗ pteroq failed.${RESET}"

        }

    fi

    if systemctl list-unit-files wings.service >/dev/null 2>&1; then

        echo -e "${CYAN}Restarting Wings...${RESET}"

        systemctl restart wings 2>/dev/null && {

            echo -e "${GREEN}✓ Wings restarted.${RESET}"

            ((restarted++))

        } || {

            echo -e "${RED}✗ Wings failed.${RESET}"

        }

    fi

    echo ""
    echo -e "${GREEN}✓ Restart operation completed.${RESET}"

    pause_screen
}

# ============================================================
# CLEAN TEMP
# ============================================================

cleanup_temp() {

    mkdir -p "$TEMP_DIR"

    find "$TEMP_DIR" \
        -type f \
        -mtime +2 \
        -delete \
        2>/dev/null || true
}

cleanup_temp

# ============================================================
# MAIN MENU
# ============================================================

while true; do

    banner

    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}          ${MAGENTA}${BOLD}BALE PTERODACTYL MANAGER${RESET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

    echo -e "${CYAN}║${RESET}  ${GREEN}1.${RESET}  🚀 Install Pterodactyl Panel                ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}2.${RESET}  🔧 Blueprint Information                   ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}3.${RESET}  📦 Install ALL Blueprints                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}4.${RESET}  📦 Install ONE Blueprint                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}5.${RESET}  📥 Load Addon from GitHub                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}6.${RESET}  📋 List Installed Addons                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${YELLOW}7.${RESET}  🗑  Remove / Uninstall Addon               ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}8.${RESET}  🔄 Update Addon                           ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${CYAN}9.${RESET}  📊 System / Pterodactyl Status            ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${MAGENTA}10.${RESET} 💾 Backup Pterodactyl                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}11.${RESET} 🧹 Clear Laravel Cache                   ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${CYAN}12.${RESET} 🔄 Update BALE Manager                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}13.${RESET} 🔁 Restart Pterodactyl Services          ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${RED}14.${RESET} ✕ Exit                                    ${CYAN}║${RESET}"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"

    echo ""

    read -rp "$(echo -e "${YELLOW}Select an option [1-14]: ${RESET}")" option

    case "$option" in

        1)
            install_pterodactyl
            ;;

        2)
            blueprint_info
            ;;

        3)
            install_all
            ;;

        4)
            install_one
            ;;

        5)
            addon_load
            ;;

        6)
            list_installed
            ;;

        7)
            remove_addon
            ;;

        8)
            update_addon
            ;;

        9)
            system_status
            ;;

        10)
            backup_pterodactyl
            ;;

        11)
            clear_cache
            ;;

        12)
            update_manager
            ;;

        13)
            restart_services
            ;;

        14)

            clear

            echo ""
            echo -e "${CYAN}${BOLD}============================================================${RESET}"
            echo -e "${GREEN}       👋 BALE Pterodactyl Manager closed.${RESET}"
            echo -e "${CYAN}${BOLD}============================================================${RESET}"
            echo ""

            exit 0
            ;;

        *)

            echo ""
            echo -e "${RED}✗ Invalid option.${RESET}"

            sleep 2
            ;;

    esac

done
