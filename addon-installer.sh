#!/bin/bash

# ============================================================
#                    BALE PTERODACTYL
#                 PANEL & BLUEPRINT MANAGER
#
# Features:
#   1. Install Pterodactyl Panel
#   2. Install Blueprint Framework
#   3. Install ALL local Blueprints
#   4. Install ONE local Blueprint
#   5. Load Blueprint from GitHub Release
#   6. List Installed Blueprint Addons
#   7. Remove Blueprint Addon
#   8. Update Blueprint Addon
#   9. Pterodactyl / System Status
#  10. Backup Pterodactyl
#  11. Clear Laravel Cache
#  12. Exit
# ============================================================

set -o pipefail

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

PTERODACTYL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/var/backups/pterodactyl"
TEMP_DIR="/tmp/bale-pterodactyl"

INSTALLER_URL="https://pterodactyl-installer.se/"

mkdir -p "$TEMP_DIR" 2>/dev/null

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

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
    echo -e "${WHITE} Panel: ${CYAN}${PTERODACTYL_DIR}${RESET}"
    echo -e "${GRAY}============================================================${RESET}"
    echo ""
}

# ------------------------------------------------------------
# Root Check
# ------------------------------------------------------------

check_root() {

    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}✗ This manager must be run as root.${RESET}"
        echo ""
        echo -e "${YELLOW}Run:${RESET}"
        echo "sudo bash bale.sh"
        echo ""
        exit 1
    fi
}

# ------------------------------------------------------------
# Pterodactyl Check
# ------------------------------------------------------------

check_pterodactyl() {

    if [ ! -d "$PTERODACTYL_DIR" ]; then
        return 1
    fi

    return 0
}

require_pterodactyl() {

    if ! check_pterodactyl; then

        echo ""
        echo -e "${RED}✗ Pterodactyl Panel was not found.${RESET}"
        echo ""
        echo -e "${YELLOW}Install Pterodactyl first using:${RESET}"
        echo -e "${CYAN}1. Install Pterodactyl Panel${RESET}"
        echo ""

        read -rp "Press Enter to continue..."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

install_dependencies() {

    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v tar >/dev/null 2>&1 || missing+=("tar")

    if [ "${#missing[@]}" -eq 0 ]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}⚙ Installing required dependencies...${RESET}"
    echo ""

    apt-get update -qq

    if ! apt-get install -y "${missing[@]}"; then
        echo ""
        echo -e "${RED}✗ Dependency installation failed.${RESET}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✓ Dependencies installed.${RESET}"

    return 0
}

# ------------------------------------------------------------
# Blueprint Check
# ------------------------------------------------------------

check_blueprint() {

    if ! command -v blueprint >/dev/null 2>&1; then
        echo ""
        echo -e "${RED}✗ Blueprint CLI is not installed.${RESET}"
        echo ""
        echo -e "${YELLOW}Install Blueprint using menu option 2.${RESET}"
        echo ""

        read -rp "Press Enter to continue..."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Pause
# ------------------------------------------------------------

pause_screen() {
    echo ""
    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# Confirmation
# ------------------------------------------------------------

confirm() {

    local question="$1"

    echo ""
    read -rp "$(echo -e "${YELLOW}${question} [y/N]: ${RESET}")" answer

    [[ "$answer" =~ ^[Yy]$ ]]
}

# ------------------------------------------------------------
# Spinner
# ------------------------------------------------------------

spinner() {

    local pid="$1"
    local message="${2:-Working}"

    local spin=(
        '⠋'
        '⠙'
        '⠹'
        '⠸'
        '⠼'
        '⠴'
        '⠦'
        '⠧'
        '⠇'
        '⠏'
    )

    while kill -0 "$pid" 2>/dev/null; do

        for frame in "${spin[@]}"; do

            kill -0 "$pid" 2>/dev/null || break

            printf "\r${MAGENTA}${message} ${frame}${RESET}"
            sleep 0.1

        done

    done

    wait "$pid"
    local status=$?

    if [ "$status" -eq 0 ]; then
        printf "\r${GREEN}✓ ${message} complete!${RESET}          \n"
    else
        printf "\r${RED}✗ ${message} failed!${RESET}            \n"
    fi

    return "$status"
}

# ------------------------------------------------------------
# Find Blueprints
# ------------------------------------------------------------

find_blueprints() {

    FILES=()

    if [ ! -d "$PTERODACTYL_DIR" ]; then
        return
    fi

    mapfile -t FILES < <(
        find "$PTERODACTYL_DIR" \
            -maxdepth 1 \
            -type f \
            -name "*.blueprint" \
            -printf "%f\n" 2>/dev/null |
        sort -f
    )
}

# ------------------------------------------------------------
# Install Pterodactyl
# ------------------------------------------------------------

install_pterodactyl() {

    banner

    echo -e "${BLUE}${BOLD}🚀 PTERODACTYL PANEL INSTALLER${RESET}"
    echo ""
    echo -e "${WHITE}This will launch the official Pterodactyl installation script.${RESET}"
    echo ""
    echo -e "${YELLOW}Installer:${RESET}"
    echo -e "${CYAN}${INSTALLER_URL}${RESET}"
    echo ""

    if check_pterodactyl; then

        echo -e "${YELLOW}⚠ A Pterodactyl installation already exists.${RESET}"
        echo -e "${GRAY}${PTERODACTYL_DIR}${RESET}"
        echo ""

        if ! confirm "Continue anyway"; then
            echo -e "${YELLOW}Cancelled.${RESET}"
            sleep 2
            return
        fi
    else

        if ! confirm "Start Pterodactyl installer"; then
            echo -e "${YELLOW}Cancelled.${RESET}"
            sleep 2
            return
        fi
    fi

    echo ""
    echo -e "${CYAN}Downloading installer...${RESET}"
    echo ""

    if ! command -v curl >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y curl || {
            echo -e "${RED}✗ curl installation failed.${RESET}"
            pause_screen
            return
        }
    fi

    echo ""
    echo -e "${GREEN}✓ Starting Pterodactyl installer...${RESET}"
    echo ""

    # Use bash process substitution exactly as requested.
    bash <(curl -fsSL "$INSTALLER_URL")

    local status=$?

    echo ""

    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓ Pterodactyl installer finished.${RESET}"
    else
        echo -e "${RED}✗ Pterodactyl installer exited with code ${status}.${RESET}"
    fi

    pause_screen
}

# ------------------------------------------------------------
# Install Blueprint Framework
# ------------------------------------------------------------

install_blueprint_framework() {

    banner

    echo -e "${BLUE}${BOLD}🔧 BLUEPRINT FRAMEWORK INSTALLER${RESET}"
    echo ""

    if ! require_pterodactyl; then
        return
    fi

    if command -v blueprint >/dev/null 2>&1; then

        echo -e "${GREEN}✓ Blueprint CLI is already installed.${RESET}"
        echo ""

        if ! confirm "Reinstall / run Blueprint installer again"; then
            return
        fi
    fi

    echo ""
    echo -e "${YELLOW}Blueprint installation is environment-specific.${RESET}"
    echo -e "${WHITE}Make sure your Pterodactyl version is supported by Blueprint.${RESET}"
    echo ""

    if ! confirm "Continue"; then
        return
    fi

    echo ""
    echo -e "${CYAN}Opening Blueprint installation process...${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || {
        echo -e "${RED}✗ Cannot enter Pterodactyl directory.${RESET}"
        pause_screen
        return
    }

    if command -v blueprint >/dev/null 2>&1; then

        echo -e "${GREEN}✓ Blueprint command detected.${RESET}"

    else

        echo -e "${YELLOW}Blueprint CLI was not found automatically.${RESET}"
        echo ""
        echo -e "${WHITE}Install Blueprint using its official installation method for your panel version.${RESET}"
        echo ""

        pause_screen
        return
    fi

    pause_screen
}

# ------------------------------------------------------------
# Install One Blueprint
# ------------------------------------------------------------

install_one() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    if ! check_blueprint; then
        return
    fi

    find_blueprints

    if [ "${#FILES[@]}" -eq 0 ]; then

        echo -e "${RED}✗ No .blueprint files found.${RESET}"
        echo ""
        echo -e "${YELLOW}Use GitHub Addon Loader to download one first.${RESET}"

        pause_screen
        return
    fi

    echo -e "${BLUE}${BOLD}📦 LOCAL BLUEPRINTS${RESET}"
    echo ""

    local i=1

    for file in "${FILES[@]}"; do
        echo -e "  ${CYAN}${i}.${RESET} ${WHITE}${file}${RESET}"
        ((i++))
    done

    echo ""
    read -rp "$(echo -e "${YELLOW}Enter blueprint number: ${RESET}")" choice

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
    echo -e "${BLUE}⚡ Installing:${RESET} ${MAGENTA}${selected}${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    (
        blueprint -i -- "$selected"
    ) >"$TEMP_DIR/install.log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Installing $selected"; then

        echo ""
        echo -e "${GREEN}✓ Blueprint installed successfully.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Blueprint installation failed.${RESET}"
        echo ""
        echo -e "${YELLOW}Last installer output:${RESET}"
        tail -n 30 "$TEMP_DIR/install.log"
    fi

    pause_screen
}

# ------------------------------------------------------------
# Install All Blueprints
# ------------------------------------------------------------

install_all() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    if ! check_blueprint; then
        return
    fi

    find_blueprints

    if [ "${#FILES[@]}" -eq 0 ]; then

        echo -e "${RED}✗ No .blueprint files found.${RESET}"
        pause_screen
        return
    fi

    echo -e "${BLUE}${BOLD}📦 INSTALL ALL BLUEPRINTS${RESET}"
    echo ""

    echo -e "${WHITE}Found ${#FILES[@]} blueprint(s):${RESET}"
    echo ""

    for file in "${FILES[@]}"; do
        echo -e "  ${CYAN}•${RESET} $file"
    done

    echo ""

    if ! confirm "Install all blueprints"; then
        echo -e "${YELLOW}Cancelled.${RESET}"
        pause_screen
        return
    fi

    cd "$PTERODACTYL_DIR" || return

    local success=0
    local failed=0

    for file in "${FILES[@]}"; do

        echo ""
        echo -e "${CYAN}➡ Installing:${RESET} ${MAGENTA}${file}${RESET}"

        (
            blueprint -i -- "$file"
        ) >"$TEMP_DIR/install.log" 2>&1 &

        local pid=$!

        if spinner "$pid" "Installing $file"; then
            ((success++))
        else
            ((failed++))
            echo ""
            echo -e "${RED}Error output:${RESET}"
            tail -n 15 "$TEMP_DIR/install.log"
        fi
    done

    echo ""
    echo -e "${GRAY}============================================================${RESET}"
    echo -e "${GREEN}✓ Successful: ${success}${RESET}"
    echo -e "${RED}✗ Failed:     ${failed}${RESET}"
    echo -e "${GRAY}============================================================${RESET}"

    pause_screen
}

# ------------------------------------------------------------
# GitHub Addon Loader
# ------------------------------------------------------------

addon_load() {

    banner

    echo -e "${BLUE}${BOLD}📥 GITHUB BLUEPRINT ADDON LOADER${RESET}"
    echo ""
    echo -e "${WHITE}Downloads the latest .blueprint asset from a GitHub Release.${RESET}"
    echo ""

    if ! require_pterodactyl; then
        return
    fi

    if ! install_dependencies; then
        pause_screen
        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo -e "${YELLOW}GitHub Repository URL:${RESET}"
    echo ""
    echo -e "${GRAY}Example:${RESET}"
    echo "https://github.com/OWNER/REPOSITORY"
    echo ""

    read -rp "$(echo -e "${CYAN}GitHub Repo: ${RESET}")" repo_url

    repo_url="${repo_url//[[:space:]]/}"
    repo_url="${repo_url%/}"
    repo_url="${repo_url%.git}"

    if [ -z "$repo_url" ]; then
        echo -e "${RED}✗ No repository URL entered.${RESET}"
        pause_screen
        return
    fi

    if [[ ! "$repo_url" =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then

        echo ""
        echo -e "${RED}✗ Invalid GitHub repository URL.${RESET}"
        echo ""
        echo -e "${YELLOW}Correct format:${RESET}"
        echo "https://github.com/OWNER/REPOSITORY"

        pause_screen
        return
    fi

    local repo_path="${repo_url#https://github.com/}"

    echo ""
    echo -e "${CYAN}🔎 Checking GitHub Releases...${RESET}"
    echo ""

    local release_api="https://api.github.com/repos/${repo_path}/releases/latest"

    local release_json

    release_json=$(curl -fsSL \
        --connect-timeout 10 \
        --max-time 30 \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: BALE-Pterodactyl-Manager" \
        "$release_api" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$release_json" ]; then

        echo -e "${RED}✗ Unable to access the latest GitHub release.${RESET}"
        echo ""
        echo -e "${YELLOW}Possible reasons:${RESET}"
        echo "  • Repository does not exist"
        echo "  • Repository is private"
        echo "  • Repository has no published release"
        echo "  • GitHub API request failed"

        pause_screen
        return
    fi

    local api_message
    api_message=$(echo "$release_json" | jq -r '.message // empty')

    if [ -n "$api_message" ]; then
        echo -e "${RED}✗ GitHub API: ${api_message}${RESET}"
        pause_screen
        return
    fi

    local tag_name
    local release_name

    tag_name=$(echo "$release_json" | jq -r '.tag_name // empty')
    release_name=$(echo "$release_json" | jq -r '.name // empty')

    if [ -z "$tag_name" ]; then

        echo -e "${RED}✗ No published release found.${RESET}"
        echo ""
        echo -e "${YELLOW}This loader requires a GitHub Release containing a .blueprint asset.${RESET}"

        pause_screen
        return
    fi

    echo -e "${GREEN}✓ Latest Release:${RESET} ${MAGENTA}${tag_name}${RESET}"

    if [ -n "$release_name" ] && [ "$release_name" != "null" ]; then
        echo -e "${WHITE}  Name: ${release_name}${RESET}"
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

        echo -e "${RED}✗ No .blueprint asset found in the latest release.${RESET}"
        echo ""

        echo -e "${YELLOW}Available release assets:${RESET}"

        local assets
        assets=$(echo "$release_json" | jq -r '.assets[]?.name')

        if [ -n "$assets" ]; then
            while IFS= read -r asset; do
                echo -e "  ${WHITE}• ${asset}${RESET}"
            done <<< "$assets"
        else
            echo -e "  ${GRAY}No release assets.${RESET}"
        fi

        pause_screen
        return
    fi

    echo -e "${GREEN}✓ Blueprint found:${RESET} ${MAGENTA}${blueprint_file}${RESET}"
    echo ""

    local destination="$PTERODACTYL_DIR/$blueprint_file"
    local temp_file="$TEMP_DIR/$blueprint_file"

    mkdir -p "$TEMP_DIR"

    if [ -f "$destination" ]; then

        echo -e "${YELLOW}⚠ This Blueprint already exists.${RESET}"
        echo -e "${WHITE}$blueprint_file${RESET}"
        echo ""

        if ! confirm "Replace existing Blueprint"; then
            echo -e "${YELLOW}Cancelled.${RESET}"
            pause_screen
            return
        fi
    fi

    rm -f "$temp_file"

    echo ""
    echo -e "${BLUE}📥 Downloading Blueprint...${RESET}"
    echo ""

    if curl -fL \
        --progress-bar \
        --connect-timeout 15 \
        --max-time 300 \
        -H "User-Agent: BALE-Pterodactyl-Manager" \
        -o "$temp_file" \
        "$blueprint_url"; then

        echo ""
        echo -e "${GREEN}✓ Download completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Download failed.${RESET}"

        rm -f "$temp_file"

        pause_screen
        return
    fi

    if [ ! -s "$temp_file" ]; then

        echo -e "${RED}✗ Downloaded file is empty.${RESET}"

        rm -f "$temp_file"

        pause_screen
        return
    fi

    # Basic file signature check.
    if ! file "$temp_file" 2>/dev/null | grep -qiE 'zip|archive|binary'; then

        echo -e "${YELLOW}⚠ File type could not be verified automatically.${RESET}"
        echo -e "${GRAY}The file will still be passed to Blueprint.${RESET}"
    fi

    # Atomic-ish replacement.
    mv -f "$temp_file" "$destination"

    echo ""
    echo -e "${GREEN}✓ Blueprint saved:${RESET}"
    echo -e "${WHITE}$destination${RESET}"

    echo ""
    echo -e "${BLUE}⚡ Installing Blueprint...${RESET}"
    echo ""

    if blueprint -i -- "$blueprint_file"; then

        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║       ✓ ADDON INSTALLED SUCCESSFULLY       ║${RESET}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${RESET}"

    else

        echo ""
        echo -e "${RED}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║          ✗ ADDON INSTALL FAILED            ║${RESET}"
        echo -e "${RED}╚════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "${YELLOW}The .blueprint file was kept for troubleshooting.${RESET}"
    fi

    pause_screen
}

# ------------------------------------------------------------
# List Installed Addons
# ------------------------------------------------------------

list_installed() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    if ! check_blueprint; then
        return
    fi

    echo -e "${BLUE}${BOLD}📦 INSTALLED BLUEPRINT ADDONS${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    echo -e "${CYAN}Blueprint CLI:${RESET}"
    echo ""

    if blueprint -list; then
        :
    else

        echo ""
        echo -e "${YELLOW}⚠ Blueprint list command failed or is unavailable.${RESET}"
        echo ""

        find_blueprints

        if [ "${#FILES[@]}" -gt 0 ]; then

            echo -e "${CYAN}Local .blueprint files:${RESET}"

            for file in "${FILES[@]}"; do
                echo -e "  ${WHITE}• ${file}${RESET}"
            done

        else

            echo -e "${GRAY}No local .blueprint files found.${RESET}"
        fi
    fi

    pause_screen
}

# ------------------------------------------------------------
# Remove Addon
# ------------------------------------------------------------

remove_addon() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    if ! check_blueprint; then
        return
    fi

    echo -e "${YELLOW}${BOLD}🗑 REMOVE BLUEPRINT ADDON${RESET}"
    echo ""

    echo -e "${WHITE}Enter the Blueprint addon/package name.${RESET}"
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
    echo -e "${YELLOW}You are about to remove:${RESET} ${MAGENTA}${addon}${RESET}"

    if ! confirm "Continue removal"; then
        echo -e "${YELLOW}Cancelled.${RESET}"
        pause_screen
        return
    fi

    echo ""
    echo -e "${BLUE}⚡ Removing:${RESET} ${MAGENTA}${addon}${RESET}"
    echo ""

    (
        cd "$PTERODACTYL_DIR" &&
        blueprint -remove "$addon"
    ) >"$TEMP_DIR/remove.log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Removing $addon"; then

        echo ""
        echo -e "${GREEN}✓ Addon removal completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Addon removal failed.${RESET}"
        echo ""
        tail -n 30 "$TEMP_DIR/remove.log"
    fi

    pause_screen
}

# ------------------------------------------------------------
# Update Addon
# ------------------------------------------------------------

update_addon() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    if ! check_blueprint; then
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

    echo ""
    echo -e "${BLUE}⚡ Updating:${RESET} ${MAGENTA}${addon}${RESET}"
    echo ""

    (
        cd "$PTERODACTYL_DIR" &&
        blueprint -update "$addon"
    ) >"$TEMP_DIR/update.log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Updating $addon"; then

        echo ""
        echo -e "${GREEN}✓ Addon update completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Addon update failed.${RESET}"
        echo ""
        tail -n 30 "$TEMP_DIR/update.log"
    fi

    pause_screen
}

# ------------------------------------------------------------
# Pterodactyl Status
# ------------------------------------------------------------

system_status() {

    banner

    echo -e "${BLUE}${BOLD}📊 BALE SYSTEM STATUS${RESET}"
    echo ""

    echo -e "${CYAN}System:${RESET}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "  OS:       ${WHITE}${PRETTY_NAME}${RESET}"
    fi

    echo -e "  Kernel:   ${WHITE}$(uname -r)${RESET}"
    echo -e "  Hostname: ${WHITE}$(hostname)${RESET}"
    echo ""

    echo -e "${CYAN}Pterodactyl:${RESET}"

    if check_pterodactyl; then
        echo -e "  Panel:    ${GREEN}FOUND${RESET}"
        echo -e "  Path:     ${WHITE}${PTERODACTYL_DIR}${RESET}"
    else
        echo -e "  Panel:    ${RED}NOT FOUND${RESET}"
    fi

    echo ""

    echo -e "${CYAN}Blueprint:${RESET}"

    if command -v blueprint >/dev/null 2>&1; then
        echo -e "  CLI:      ${GREEN}INSTALLED${RESET}"
        echo -e "  Location: ${WHITE}$(command -v blueprint)${RESET}"
    else
        echo -e "  CLI:      ${RED}NOT INSTALLED${RESET}"
    fi

    echo ""

    echo -e "${CYAN}Services:${RESET}"

    for service in nginx php8.3-fpm mysql redis-server pteroq wings docker; do

        if systemctl list-unit-files "$service.service" >/dev/null 2>&1; then

            if systemctl is-active --quiet "$service"; then
                echo -e "  ${GREEN}●${RESET} ${service}: ${GREEN}RUNNING${RESET}"
            else
                echo -e "  ${RED}●${RESET} ${service}: ${RED}STOPPED${RESET}"
            fi
        fi
    done

    echo ""

    echo -e "${CYAN}Disk:${RESET}"
    df -h "$PTERODACTYL_DIR" 2>/dev/null | tail -n 1

    echo ""

    echo -e "${CYAN}Memory:${RESET}"
    free -h

    pause_screen
}

# ------------------------------------------------------------
# Backup Pterodactyl
# ------------------------------------------------------------

backup_pterodactyl() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    echo -e "${BLUE}${BOLD}💾 PTERODACTYL BACKUP${RESET}"
    echo ""

    mkdir -p "$BACKUP_DIR"

    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')

    local backup_file="$BACKUP_DIR/pterodactyl-$timestamp.tar.gz"

    echo -e "${WHITE}Backup location:${RESET}"
    echo -e "${CYAN}$backup_file${RESET}"
    echo ""

    if ! confirm "Create Pterodactyl file backup"; then
        echo -e "${YELLOW}Cancelled.${RESET}"
        pause_screen
        return
    fi

    echo ""
    echo -e "${BLUE}Creating backup...${RESET}"
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
        echo -e "${GREEN}✓ Backup created successfully.${RESET}"
        echo ""
        ls -lh "$backup_file"

    else

        echo ""
        echo -e "${RED}✗ Backup failed.${RESET}"
        echo ""
        tail -n 30 "$TEMP_DIR/backup.log"

        rm -f "$backup_file"
    fi

    pause_screen
}

# ------------------------------------------------------------
# Laravel Cache
# ------------------------------------------------------------

clear_cache() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    echo -e "${BLUE}${BOLD}🧹 CLEAR LARAVEL CACHE${RESET}"
    echo ""

    if ! confirm "Clear Pterodactyl Laravel caches"; then
        echo -e "${YELLOW}Cancelled.${RESET}"
        pause_screen
        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo ""
    echo -e "${CYAN}Running Laravel cache cleanup...${RESET}"
    echo ""

    php artisan optimize:clear

    local status=$?

    echo ""

    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓ Laravel cache cleared.${RESET}"
    else
        echo -e "${RED}✗ Cache cleanup failed.${RESET}"
    fi

    echo ""
    echo -e "${CYAN}Fixing common Pterodactyl permissions...${RESET}"

    chown -R www-data:www-data \
        "$PTERODACTYL_DIR/storage" \
        "$PTERODACTYL_DIR/bootstrap/cache" 2>/dev/null

    chmod -R 775 \
        "$PTERODACTYL_DIR/storage" \
        "$PTERODACTYL_DIR/bootstrap/cache" 2>/dev/null

    echo -e "${GREEN}✓ Permission check completed.${RESET}"

    pause_screen
}

# ------------------------------------------------------------
# Main Menu
# ------------------------------------------------------------

check_root
install_dependencies >/dev/null 2>&1

while true; do

    banner

    if check_pterodactyl; then
        PANEL_STATUS="${GREEN}● Installed${RESET}"
    else
        PANEL_STATUS="${RED}● Not Installed${RESET}"
    fi

    if command -v blueprint >/dev/null 2>&1; then
        BLUEPRINT_STATUS="${GREEN}● Ready${RESET}"
    else
        BLUEPRINT_STATUS="${YELLOW}● Not Installed${RESET}"
    fi

    echo -e "${WHITE}Pterodactyl:${RESET} $PANEL_STATUS"
    echo -e "${WHITE}Blueprint:${RESET}   $BLUEPRINT_STATUS"
    echo ""

    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}BALE PTERODACTYL MANAGER${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}1.${RESET} 🚀 Install Pterodactyl Panel                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}2.${RESET} 🔧 Blueprint Framework                         ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}3.${RESET} 📦 Install ALL Blueprints                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}4.${RESET} 📦 Install ONE Blueprint                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}5.${RESET} 📥 Load Addon from GitHub                    ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}6.${RESET} 📋 List Installed Addons                     ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${YELLOW}7.${RESET} 🗑  Remove / Uninstall Addon                  ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}8.${RESET} 🔄 Update Addon                              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${CYAN}9.${RESET} 📊 System / Pterodactyl Status               ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${MAGENTA}10.${RESET} 💾 Backup Pterodactyl                       ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}11.${RESET} 🧹 Clear Laravel Cache                      ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${RED}12.${RESET} ✕ Exit                                     ${CYAN}║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""

    read -rp "$(echo -e "${YELLOW}Select an option [1-12]: ${RESET}")" option

    case "$option" in

        1)
            install_pterodactyl
            ;;

        2)
            install_blueprint_framework
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
            clear
            echo ""
            echo -e "${CYAN}${BOLD}============================================================${RESET}"
            echo -e "${GREEN}        👋 BALE Pterodactyl Manager closed.${RESET}"
            echo -e "${CYAN}${BOLD}============================================================${RESET}"
            echo ""
            exit 0
            ;;

        *)
            echo ""
            echo -e "${RED}✗ Invalid option. Choose 1-12.${RESET}"
            sleep 2
            ;;

    esac

done
