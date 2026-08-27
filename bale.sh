#!/usr/bin/env bash

# ============================================================
#                 BALE PTERODACTYL MANAGER
#        Panel + Blueprint Addon Management Tool
#
# GitHub:
# https://github.com/SundarBau/install-Blueprint
#
# Run:
# bash <(curl -fsSL https://raw.githubusercontent.com/SundarBau/install-Blueprint/main/bale.sh)
#
# Recommended:
# curl -fsSL https://raw.githubusercontent.com/SundarBau/install-Blueprint/main/bale.sh | sudo bash
# ============================================================

set -o pipefail

# ============================================================
# CONFIGURATION
# ============================================================

PTERODACTYL_DIR="/var/www/pterodactyl"
BACKUP_DIR="/var/backups/pterodactyl"
TEMP_DIR="/tmp/bale-pterodactyl-manager"

SCRIPT_URL="https://raw.githubusercontent.com/SundarBau/install-Blueprint/main/bale.sh"
INSTALLER_URL="https://pterodactyl-installer.se/"

SCRIPT_NAME="bale.sh"
SCRIPT_VERSION="2.0.0"

mkdir -p "$TEMP_DIR" 2>/dev/null || true

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
# GLOBALS
# ============================================================

FILES=()

# ============================================================
# CLEANUP
# ============================================================

cleanup() {
    find "$TEMP_DIR" \
        -type f \
        -mtime +1 \
        -delete 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================
# ROOT CHECK
# ============================================================

check_root() {

    if [ "$EUID" -eq 0 ]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}⚠ BALE Pterodactyl Manager requires administrator privileges.${RESET}"
    echo ""

    if ! command -v sudo >/dev/null 2>&1; then

        echo -e "${RED}✗ sudo is not installed.${RESET}"
        echo ""
        echo "Login as root and run the script again."
        exit 1
    fi

    if ! command -v curl >/dev/null 2>&1; then

        echo -e "${YELLOW}Installing curl...${RESET}"

        if command -v apt-get >/dev/null 2>&1; then

            apt-get update -qq || true
            apt-get install -y curl || {
                echo -e "${RED}✗ Failed to install curl.${RESET}"
                exit 1
            }

        else

            echo -e "${RED}✗ apt-get was not found.${RESET}"
            exit 1
        fi
    fi

    echo -e "${CYAN}🔐 Requesting sudo access...${RESET}"
    echo ""

    local bootstrap_file

    bootstrap_file="$(mktemp "$TEMP_DIR/bale-bootstrap.XXXXXX.sh")" || {
        echo -e "${RED}✗ Could not create temporary file.${RESET}"
        exit 1
    }

    # IMPORTANT:
    # This MUST point to bale.sh, not addon-installer.sh.
    if ! curl -fsSL \
        --connect-timeout 15 \
        --max-time 60 \
        -A "BALE-Pterodactyl-Manager" \
        "$SCRIPT_URL" \
        -o "$bootstrap_file"; then

        echo -e "${RED}✗ Failed to download BALE manager.${RESET}"
        echo ""
        echo -e "${YELLOW}URL:${RESET} $SCRIPT_URL"

        rm -f "$bootstrap_file"
        exit 1
    fi

    if [ ! -s "$bootstrap_file" ]; then

        echo -e "${RED}✗ Downloaded BALE manager is empty.${RESET}"

        rm -f "$bootstrap_file"
        exit 1
    fi

    chmod 700 "$bootstrap_file"

    sudo bash "$bootstrap_file" "$@"

    local status=$?

    rm -f "$bootstrap_file"

    exit "$status"
}

# ============================================================
# BANNER
# ============================================================

banner() {

    clear 2>/dev/null || true

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
        echo -e "${WHITE}Panel:${RESET}      ${GREEN}Installed${RESET}"
    else
        echo -e "${WHITE}Panel:${RESET}      ${YELLOW}Not Installed${RESET}"
    fi

    if command -v blueprint >/dev/null 2>&1; then
        echo -e "${WHITE}Blueprint:${RESET}  ${GREEN}Ready${RESET}"
    else
        echo -e "${WHITE}Blueprint:${RESET}  ${YELLOW}Not Detected${RESET}"
    fi

    echo -e "${WHITE}Version:${RESET}    ${CYAN}${SCRIPT_VERSION}${RESET}"
    echo -e "${WHITE}Directory:${RESET}  ${CYAN}${PTERODACTYL_DIR}${RESET}"

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
# CONFIRM
# ============================================================

confirm() {

    local question="$1"

    echo ""

    read -rp "$(echo -e "${YELLOW}${question} [y/N]: ${RESET}")" answer

    [[ "$answer" =~ ^[Yy]$ ]]
}

# ============================================================
# COMMAND CHECK
# ============================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# PTERODACTYL CHECK
# ============================================================

check_pterodactyl() {

    [ -d "$PTERODACTYL_DIR" ] &&
    [ -f "$PTERODACTYL_DIR/artisan" ]
}

require_pterodactyl() {

    if ! check_pterodactyl; then

        echo ""
        echo -e "${RED}✗ Pterodactyl Panel was not found.${RESET}"
        echo ""

        echo -e "${YELLOW}Expected:${RESET}"
        echo "$PTERODACTYL_DIR"
        echo ""

        echo -e "${YELLOW}Use menu option 1 to install Pterodactyl.${RESET}"

        pause_screen

        return 1
    fi

    return 0
}

# ============================================================
# DEPENDENCIES
# ============================================================

install_dependencies() {

    local missing=()

    command_exists curl || missing+=("curl")
    command_exists jq || missing+=("jq")
    command_exists tar || missing+=("tar")
    command_exists file || missing+=("file")

    if [ "${#missing[@]}" -eq 0 ]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}⚙ Installing required packages...${RESET}"
    echo ""

    if ! command_exists apt-get; then

        echo -e "${RED}✗ apt-get is not available.${RESET}"
        echo ""
        echo "Please install:"
        printf '  %s\n' "${missing[@]}"

        return 1
    fi

    apt-get update -qq || {
        echo -e "${RED}✗ apt update failed.${RESET}"
        return 1
    }

    if ! apt-get install -y "${missing[@]}"; then

        echo ""
        echo -e "${RED}✗ Failed to install dependencies.${RESET}"

        return 1
    fi

    echo ""
    echo -e "${GREEN}✓ Dependencies installed.${RESET}"

    return 0
}

# ============================================================
# BLUEPRINT CHECK
# ============================================================

check_blueprint() {

    if ! command_exists blueprint; then

        echo ""
        echo -e "${RED}✗ Blueprint CLI is not installed.${RESET}"
        echo ""

        echo -e "${YELLOW}Install Blueprint Framework first.${RESET}"

        pause_screen

        return 1
    fi

    return 0
}

# ============================================================
# SPINNER
# ============================================================

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

# ============================================================
# RUN COMMAND WITH LOG
# ============================================================

run_logged() {

    local logfile="$1"
    shift

    "$@" >"$logfile" 2>&1 &

    local pid=$!

    spinner "$pid" "${RUN_MESSAGE:-Working}"

    return $?
}

# ============================================================
# FIND BLUEPRINTS
# ============================================================

find_blueprints() {

    FILES=()

    if [ ! -d "$PTERODACTYL_DIR" ]; then
        return
    fi

    mapfile -t FILES < <(
        find "$PTERODACTYL_DIR" \
            -maxdepth 1 \
            -type f \
            -iname "*.blueprint" \
            -printf "%f\n" 2>/dev/null |
        sort -f
    )
}

# ============================================================
# BACKUP BLUEPRINT
# ============================================================

backup_blueprint_file() {

    local blueprint_file="$1"
    local source="$PTERODACTYL_DIR/$blueprint_file"

    if [ ! -f "$source" ]; then
        return 0
    fi

    mkdir -p "$BACKUP_DIR/blueprints"

    local backup_name

    backup_name="${blueprint_file}.$(date '+%Y%m%d-%H%M%S').bak"

    if cp -f "$source" "$BACKUP_DIR/blueprints/$backup_name"; then

        echo -e "${GREEN}✓ Blueprint backup created:${RESET}"
        echo -e "${WHITE}$BACKUP_DIR/blueprints/$backup_name${RESET}"

        return 0

    else

        echo -e "${RED}✗ Failed to backup Blueprint.${RESET}"

        return 1
    fi
}

# ============================================================
# INSTALL PTERODACTYL
# ============================================================

install_pterodactyl() {

    banner

    echo -e "${BLUE}${BOLD}🚀 PTERODACTYL PANEL INSTALLER${RESET}"
    echo ""

    echo -e "${WHITE}Installer:${RESET}"
    echo -e "${CYAN}${INSTALLER_URL}${RESET}"
    echo ""

    if check_pterodactyl; then

        echo -e "${YELLOW}⚠ Pterodactyl already exists.${RESET}"
        echo ""
        echo -e "${WHITE}Path:${RESET} $PTERODACTYL_DIR"
        echo ""

        if ! confirm "Launch installer anyway"; then

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
    echo -e "${CYAN}Downloading official installer...${RESET}"
    echo ""

    local installer_file

    installer_file="$(mktemp "$TEMP_DIR/pterodactyl-installer.XXXXXX.sh")" || {
        echo -e "${RED}✗ Could not create temporary installer file.${RESET}"
        pause_screen
        return
    }

    if ! curl -fsSL \
        --connect-timeout 15 \
        --max-time 120 \
        -A "BALE-Pterodactyl-Manager" \
        "$INSTALLER_URL" \
        -o "$installer_file"; then

        echo ""
        echo -e "${RED}✗ Failed to download installer.${RESET}"

        rm -f "$installer_file"

        pause_screen

        return
    fi

    if [ ! -s "$installer_file" ]; then

        echo -e "${RED}✗ Installer file is empty.${RESET}"

        rm -f "$installer_file"

        pause_screen

        return
    fi

    chmod 700 "$installer_file"

    echo -e "${GREEN}✓ Installer downloaded.${RESET}"
    echo ""
    echo -e "${BLUE}🚀 Starting installer...${RESET}"
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
# BLUEPRINT FRAMEWORK
# ============================================================

blueprint_framework() {

    banner

    echo -e "${BLUE}${BOLD}🔧 BLUEPRINT FRAMEWORK${RESET}"
    echo ""

    if ! require_pterodactyl; then
        return
    fi

    if command_exists blueprint; then

        echo -e "${GREEN}✓ Blueprint CLI detected.${RESET}"
        echo ""
        echo -e "${WHITE}Location:${RESET} $(command -v blueprint)"
        echo ""

        local version

        version="$(blueprint --version 2>/dev/null || true)"

        if [ -n "$version" ]; then
            echo -e "${WHITE}Version:${RESET} $version"
        fi

        echo ""

        cd "$PTERODACTYL_DIR" || return

        if confirm "Show installed Blueprints"; then

            echo ""

            if ! blueprint -list; then

                echo ""
                echo -e "${RED}✗ Blueprint list command failed.${RESET}"
            fi
        fi

    else

        echo -e "${RED}✗ Blueprint CLI is not detected.${RESET}"
        echo ""
        echo -e "${YELLOW}Install Blueprint using its official method for your Pterodactyl version.${RESET}"
    fi

    pause_screen
}

# ============================================================
# INSTALL ONE BLUEPRINT
# ============================================================

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
        echo -e "${YELLOW}Use GitHub Addon Loader first.${RESET}"

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
    echo -e "${BLUE}⚡ Selected:${RESET} ${MAGENTA}${selected}${RESET}"
    echo ""

    if ! confirm "Create backup and install this Blueprint"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    backup_blueprint_file "$selected" || true

    cd "$PTERODACTYL_DIR" || return

    local logfile="$TEMP_DIR/install-one.log"

    echo ""
    echo -e "${BLUE}⚡ Installing:${RESET} ${MAGENTA}${selected}${RESET}"
    echo ""

    (
        blueprint -i "$selected"
    ) >"$logfile" 2>&1 &

    local pid=$!

    if spinner "$pid" "Installing $selected"; then

        echo ""
        echo -e "${GREEN}✓ Blueprint installed successfully.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Blueprint installation failed.${RESET}"
        echo ""
        echo -e "${YELLOW}Last output:${RESET}"
        tail -n 40 "$logfile"
    fi

    pause_screen
}

# ============================================================
# INSTALL ALL
# ============================================================

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

    for file in "${FILES[@]}"; do
        echo -e "  ${CYAN}•${RESET} ${file}"
    done

    echo ""

    if ! confirm "Backup and install all ${#FILES[@]} blueprint(s)"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    local success=0
    local failed=0
    local file
    local logfile="$TEMP_DIR/install-all.log"

    for file in "${FILES[@]}"; do

        echo ""
        echo -e "${CYAN}➡ Installing:${RESET} ${MAGENTA}${file}${RESET}"

        backup_blueprint_file "$file" || true

        (
            blueprint -i "$file"
        ) >"$logfile" 2>&1 &

        local pid=$!

        if spinner "$pid" "Installing $file"; then

            ((success++))

        else

            ((failed++))

            echo ""
            echo -e "${RED}Last output:${RESET}"

            tail -n 30 "$logfile"
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
    echo -e "${WHITE}Loads the latest .blueprint asset from a GitHub Release.${RESET}"
    echo ""

    if ! require_pterodactyl; then
        return
    fi

    if ! install_dependencies; then
        pause_screen
        return
    fi

    if ! check_blueprint; then
        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo -e "${YELLOW}GitHub Repository URL:${RESET}"
    echo ""
    echo -e "${GRAY}Example:${RESET}"
    echo "https://github.com/OWNER/REPOSITORY"
    echo ""

    read -rp "$(echo -e "${CYAN}GitHub Repo: ${RESET}")" repo_url

    # Remove spaces.
    repo_url="${repo_url//[[:space:]]/}"

    # Remove trailing slash.
    repo_url="${repo_url%/}"

    # Remove .git.
    repo_url="${repo_url%.git}"

    if [ -z "$repo_url" ]; then

        echo ""
        echo -e "${RED}✗ No repository URL entered.${RESET}"

        pause_screen

        return
    fi

    if [[ ! "$repo_url" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then

        echo ""
        echo -e "${RED}✗ Invalid GitHub repository URL.${RESET}"
        echo ""
        echo -e "${YELLOW}Correct:${RESET}"
        echo "https://github.com/OWNER/REPOSITORY"

        pause_screen

        return
    fi

    local repo_path="${repo_url#https://github.com/}"

    echo ""
    echo -e "${CYAN}🔎 Checking GitHub Release...${RESET}"
    echo ""

    local release_api="https://api.github.com/repos/${repo_path}/releases/latest"

    local release_json

    release_json=$(curl -fsSL \
        --connect-timeout 15 \
        --max-time 60 \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: BALE-Pterodactyl-Manager" \
        "$release_api" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$release_json" ]; then

        echo -e "${RED}✗ Unable to access GitHub Release.${RESET}"
        echo ""
        echo "Possible reasons:"
        echo "  • Repository does not exist"
        echo "  • Repository is private"
        echo "  • No published release"
        echo "  • GitHub API error"

        pause_screen

        return
    fi

    if ! echo "$release_json" | jq empty >/dev/null 2>&1; then

        echo -e "${RED}✗ GitHub returned invalid JSON.${RESET}"

        pause_screen

        return
    fi

    local api_message

    api_message=$(echo "$release_json" |
        jq -r '.message // empty')

    if [ -n "$api_message" ]; then

        echo -e "${RED}✗ GitHub API: ${api_message}${RESET}"

        pause_screen

        return
    fi

    local tag_name
    local release_name

    tag_name=$(echo "$release_json" |
        jq -r '.tag_name // empty')

    release_name=$(echo "$release_json" |
        jq -r '.name // empty')

    if [ -z "$tag_name" ]; then

        echo -e "${RED}✗ No published release found.${RESET}"
        echo ""
        echo -e "${YELLOW}The repository needs a GitHub Release.${RESET}"

        pause_screen

        return
    fi

    echo -e "${GREEN}✓ Latest Release:${RESET} ${MAGENTA}${tag_name}${RESET}"

    if [ -n "$release_name" ] && [ "$release_name" != "null" ]; then
        echo -e "${WHITE}Name:${RESET} ${release_name}"
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

        echo -e "${RED}✗ No .blueprint file found in this release.${RESET}"
        echo ""

        echo -e "${YELLOW}Available assets:${RESET}"

        local assets

        assets=$(echo "$release_json" |
            jq -r '.assets[]?.name')

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

        echo -e "${YELLOW}⚠ Blueprint already exists.${RESET}"
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

    if ! curl -fL \
        --progress-bar \
        --connect-timeout 15 \
        --max-time 300 \
        -H "User-Agent: BALE-Pterodactyl-Manager" \
        "$blueprint_url" \
        -o "$temp_file"; then

        echo ""
        echo -e "${RED}✗ Download failed.${RESET}"

        rm -f "$temp_file"

        pause_screen

        return
    fi

    echo ""
    echo -e "${GREEN}✓ Download completed.${RESET}"

    if [ ! -s "$temp_file" ]; then

        echo -e "${RED}✗ Downloaded file is empty.${RESET}"

        rm -f "$temp_file"

        pause_screen

        return
    fi

    if command_exists file; then

        echo ""
        echo -e "${GRAY}File type:${RESET} $(file -b "$temp_file")"
    fi

    # Backup existing Blueprint.
    if [ -f "$destination" ]; then

        backup_blueprint_file "$blueprint_file" || {

            echo ""
            echo -e "${RED}✗ Backup failed. Installation cancelled for safety.${RESET}"

            rm -f "$temp_file"

            pause_screen

            return
        }
    fi

    # Atomic-ish replacement.
    if ! mv -f "$temp_file" "$destination"; then

        echo -e "${RED}✗ Could not move Blueprint into Pterodactyl directory.${RESET}"

        rm -f "$temp_file"

        pause_screen

        return
    fi

    chmod 644 "$destination"

    echo ""
    echo -e "${GREEN}✓ Blueprint saved:${RESET}"
    echo -e "${WHITE}$destination${RESET}"

    echo ""
    echo -e "${BLUE}⚡ Installing Blueprint...${RESET}"
    echo ""

    local install_log="$TEMP_DIR/github-install.log"

    (
        blueprint -i "$blueprint_file"
    ) >"$install_log" 2>&1 &

    local pid=$!

    if spinner "$pid" "Installing $blueprint_file"; then

        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║       ✓ ADDON INSTALLED SUCCESSFULLY      ║${RESET}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${RESET}"

    else

        echo ""
        echo -e "${RED}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║          ✗ ADDON INSTALL FAILED            ║${RESET}"
        echo -e "${RED}╚════════════════════════════════════════════╝${RESET}"
        echo ""
        echo -e "${YELLOW}Last output:${RESET}"
        tail -n 50 "$install_log"
        echo ""
        echo -e "${YELLOW}The downloaded Blueprint has been kept for debugging.${RESET}"
    fi

    pause_screen
}

# ============================================================
# LIST ADDONS
# ============================================================

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

    if blueprint -list; then

        :

    else

        echo ""
        echo -e "${YELLOW}⚠ Blueprint list command failed.${RESET}"
        echo ""

        find_blueprints

        if [ "${#FILES[@]}" -gt 0 ]; then

            echo -e "${CYAN}Local Blueprint files:${RESET}"

            for file in "${FILES[@]}"; do
                echo -e "  ${WHITE}• ${file}${RESET}"
            done

        else

            echo -e "${GRAY}No local Blueprint files found.${RESET}"
        fi
    fi

    pause_screen
}

# ============================================================
# REMOVE ADDON
# ============================================================

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
    echo -e "${YELLOW}Addon:${RESET} ${MAGENTA}${addon}${RESET}"

    if ! confirm "Remove this addon"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    local logfile="$TEMP_DIR/remove.log"

    (
        blueprint -remove "$addon"
    ) >"$logfile" 2>&1 &

    local pid=$!

    if spinner "$pid" "Removing $addon"; then

        echo ""
        echo -e "${GREEN}✓ Addon removal completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Addon removal failed.${RESET}"
        echo ""
        tail -n 40 "$logfile"
    fi

    pause_screen
}

# ============================================================
# UPDATE ADDON
# ============================================================

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

    cd "$PTERODACTYL_DIR" || return

    echo ""
    echo -e "${BLUE}⚡ Updating:${RESET} ${MAGENTA}${addon}${RESET}"
    echo ""

    local logfile="$TEMP_DIR/update.log"

    (
        blueprint -update "$addon"
    ) >"$logfile" 2>&1 &

    local pid=$!

    if spinner "$pid" "Updating $addon"; then

        echo ""
        echo -e "${GREEN}✓ Addon update completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Addon update failed.${RESET}"
        echo ""
        tail -n 40 "$logfile"
    fi

    pause_screen
}

# ============================================================
# SYSTEM STATUS
# ============================================================

system_status() {

    banner

    echo -e "${BLUE}${BOLD}📊 BALE SYSTEM STATUS${RESET}"
    echo ""

    echo -e "${CYAN}SYSTEM${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    if [ -f /etc/os-release ]; then

        . /etc/os-release

        echo -e "${WHITE}OS:${RESET}         ${PRETTY_NAME}"
    fi

    echo -e "${WHITE}Kernel:${RESET}     $(uname -r)"
    echo -e "${WHITE}Hostname:${RESET}   $(hostname)"
    echo -e "${WHITE}Uptime:${RESET}     $(uptime -p 2>/dev/null || uptime)"
    echo ""

    echo -e "${CYAN}BALE MANAGER${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    echo -e "${WHITE}Version:${RESET}    ${SCRIPT_VERSION}"
    echo -e "${WHITE}Script:${RESET}     ${SCRIPT_URL}"
    echo ""

    echo -e "${CYAN}PTERODACTYL${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    if check_pterodactyl; then

        echo -e "${WHITE}Panel:${RESET}      ${GREEN}INSTALLED${RESET}"
        echo -e "${WHITE}Directory:${RESET}  $PTERODACTYL_DIR"

        if [ -f "$PTERODACTYL_DIR/composer.json" ]; then

            local panel_version

            panel_version=$(
                grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
                    "$PTERODACTYL_DIR/composer.json" 2>/dev/null |
                head -n 1 |
                sed -E 's/.*"([^"]+)".*/\1/'
            )

            if [ -n "$panel_version" ]; then
                echo -e "${WHITE}Version:${RESET}    $panel_version"
            fi
        fi

    else

        echo -e "${WHITE}Panel:${RESET}      ${RED}NOT INSTALLED${RESET}"
    fi

    echo ""

    echo -e "${CYAN}BLUEPRINT${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    if command_exists blueprint; then

        echo -e "${WHITE}CLI:${RESET}        ${GREEN}INSTALLED${RESET}"
        echo -e "${WHITE}Path:${RESET}       $(command -v blueprint)"

        local blueprint_version

        blueprint_version="$(blueprint --version 2>/dev/null || true)"

        if [ -n "$blueprint_version" ]; then
            echo -e "${WHITE}Version:${RESET}    $blueprint_version"
        fi

    else

        echo -e "${WHITE}CLI:${RESET}        ${RED}NOT INSTALLED${RESET}"
    fi

    echo ""

    echo -e "${CYAN}SERVICES${RESET}"
    echo -e "${GRAY}------------------------------------------------------------${RESET}"

    local services=(
        nginx
        mysql
        mariadb
        redis-server
        pteroq
        wings
        docker
    )

    local service

    for service in "${services[@]}"; do

        if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then

            if systemctl is-active --quiet "$service"; then

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

    if ! require_pterodactyl; then
        return
    fi

    echo -e "${BLUE}${BOLD}💾 PTERODACTYL BACKUP${RESET}"
    echo ""

    mkdir -p "$BACKUP_DIR"

    local timestamp

    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"

    local backup_file

    backup_file="$BACKUP_DIR/pterodactyl-$timestamp.tar.gz"

    echo -e "${WHITE}Backup:${RESET}"
    echo -e "${CYAN}$backup_file${RESET}"
    echo ""

    if ! confirm "Create backup"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    echo ""
    echo -e "${BLUE}Creating backup...${RESET}"
    echo ""

    local logfile="$TEMP_DIR/backup.log"

    (
        tar \
            --exclude='pterodactyl/storage/logs/*' \
            --exclude='pterodactyl/storage/framework/cache/*' \
            --exclude='pterodactyl/storage/framework/sessions/*' \
            --exclude='pterodactyl/storage/framework/views/*' \
            -czf "$backup_file" \
            -C /var/www \
            pterodactyl
    ) >"$logfile" 2>&1 &

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

        tail -n 40 "$logfile"

        rm -f "$backup_file"
    fi

    pause_screen
}

# ============================================================
# CLEAR CACHE
# ============================================================

clear_cache() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    echo -e "${BLUE}${BOLD}🧹 CLEAR PTERODACTYL CACHE${RESET}"
    echo ""

    if ! confirm "Clear Laravel cache"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo ""
    echo -e "${CYAN}Running optimize:clear...${RESET}"
    echo ""

    if php artisan optimize:clear; then

        echo ""
        echo -e "${GREEN}✓ Laravel cache cleared.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Laravel cache clear failed.${RESET}"
    fi

    echo ""
    echo -e "${CYAN}Fixing storage permissions...${RESET}"

    chown -R www-data:www-data \
        "$PTERODACTYL_DIR/storage" \
        "$PTERODACTYL_DIR/bootstrap/cache" \
        2>/dev/null || true

    chmod -R 775 \
        "$PTERODACTYL_DIR/storage" \
        "$PTERODACTYL_DIR/bootstrap/cache" \
        2>/dev/null || true

    echo -e "${GREEN}✓ Permission check completed.${RESET}"

    echo ""

    if systemctl is-active --quiet pteroq 2>/dev/null; then

        if systemctl restart pteroq 2>/dev/null; then
            echo -e "${GREEN}✓ pteroq restarted.${RESET}"
        else
            echo -e "${YELLOW}⚠ Could not restart pteroq.${RESET}"
        fi
    fi

    if systemctl is-active --quiet nginx 2>/dev/null; then

        if systemctl reload nginx 2>/dev/null; then
            echo -e "${GREEN}✓ nginx reloaded.${RESET}"
        else
            echo -e "${YELLOW}⚠ Could not reload nginx.${RESET}"
        fi
    fi

    pause_screen
}

# ============================================================
# REPAIR PANEL
# ============================================================

repair_panel() {

    banner

    if ! require_pterodactyl; then
        return
    fi

    echo -e "${BLUE}${BOLD}🛠 PTERODACTYL REPAIR${RESET}"
    echo ""

    echo "This will:"
    echo "  • Fix ownership"
    echo "  • Fix storage permissions"
    echo "  • Fix bootstrap/cache permissions"
    echo "  • Clear Laravel cache"
    echo "  • Restart pteroq"
    echo "  • Reload nginx"
    echo ""

    if ! confirm "Run Pterodactyl repair"; then

        echo -e "${YELLOW}Cancelled.${RESET}"

        pause_screen

        return
    fi

    echo ""

    echo -e "${CYAN}1. Fixing ownership...${RESET}"

    chown -R www-data:www-data \
        "$PTERODACTYL_DIR/storage" \
        "$PTERODACTYL_DIR/bootstrap/cache" \
        2>/dev/null || true

    echo -e "${GREEN}✓ Ownership processed.${RESET}"

    echo ""
    echo -e "${CYAN}2. Fixing permissions...${RESET}"

    chmod -R 775 \
        "$PTERODACTYL_DIR/storage" \
        "$PTERODACTYL_DIR/bootstrap/cache" \
        2>/dev/null || true

    echo -e "${GREEN}✓ Permissions processed.${RESET}"

    echo ""
    echo -e "${CYAN}3. Clearing Laravel cache...${RESET}"

    cd "$PTERODACTYL_DIR" || return

    if php artisan optimize:clear; then
        echo -e "${GREEN}✓ Laravel cache cleared.${RESET}"
    else
        echo -e "${RED}✗ Laravel cache clear failed.${RESET}"
    fi

    echo ""
    echo -e "${CYAN}4. Restarting services...${RESET}"

    if systemctl restart pteroq 2>/dev/null; then
        echo -e "${GREEN}✓ pteroq restarted.${RESET}"
    else
        echo -e "${YELLOW}⚠ pteroq not restarted.${RESET}"
    fi

    if systemctl reload nginx 2>/dev/null; then
        echo -e "${GREEN}✓ nginx reloaded.${RESET}"
    else
        echo -e "${YELLOW}⚠ nginx not reloaded.${RESET}"
    fi

    echo ""
    echo -e "${GREEN}✓ Repair completed.${RESET}"

    pause_screen
}

# ============================================================
# SERVICE MANAGER
# ============================================================

service_manager() {

    banner

    echo -e "${BLUE}${BOLD}⚙ PTERODACTYL SERVICE MANAGER${RESET}"
    echo ""

    echo "1. Restart pteroq"
    echo "2. Restart Wings"
    echo "3. Restart nginx"
    echo "4. Restart Docker"
    echo "5. Restart all common services"
    echo "6. Back"
    echo ""

    read -rp "$(echo -e "${YELLOW}Select [1-6]: ${RESET}")" choice

    case "$choice" in

        1)

            systemctl restart pteroq &&
                echo -e "${GREEN}✓ pteroq restarted.${RESET}" ||
                echo -e "${RED}✗ Failed to restart pteroq.${RESET}"

            pause_screen
            ;;

        2)

            systemctl restart wings &&
                echo -e "${GREEN}✓ Wings restarted.${RESET}" ||
                echo -e "${RED}✗ Failed to restart Wings.${RESET}"

            pause_screen
            ;;

        3)

            nginx -t || {
                echo -e "${RED}✗ nginx configuration test failed.${RESET}"
                pause_screen
                return
            }

            systemctl reload nginx &&
                echo -e "${GREEN}✓ nginx reloaded.${RESET}" ||
                echo -e "${RED}✗ Failed to reload nginx.${RESET}"

            pause_screen
            ;;

        4)

            systemctl restart docker &&
                echo -e "${GREEN}✓ Docker restarted.${RESET}" ||
                echo -e "${RED}✗ Failed to restart Docker.${RESET}"

            pause_screen
            ;;

        5)

            echo ""

            systemctl restart docker 2>/dev/null &&
                echo -e "${GREEN}✓ Docker restarted.${RESET}" ||
                echo -e "${YELLOW}⚠ Docker restart failed/skipped.${RESET}"

            systemctl restart wings 2>/dev/null &&
                echo -e "${GREEN}✓ Wings restarted.${RESET}" ||
                echo -e "${YELLOW}⚠ Wings restart failed/skipped.${RESET}"

            systemctl restart pteroq 2>/dev/null &&
                echo -e "${GREEN}✓ pteroq restarted.${RESET}" ||
                echo -e "${YELLOW}⚠ pteroq restart failed/skipped.${RESET}"

            nginx -t >/dev/null 2>&1 && \
                systemctl reload nginx 2>/dev/null &&
                echo -e "${GREEN}✓ nginx reloaded.${RESET}" ||
                echo -e "${YELLOW}⚠ nginx reload failed/skipped.${RESET}"

            pause_screen
            ;;

        6)
            return
            ;;

        *)
            echo -e "${RED}✗ Invalid option.${RESET}"
            sleep 2
            ;;
    esac
}

# ============================================================
# VIEW LOGS
# ============================================================

view_logs() {

    banner

    echo -e "${BLUE}${BOLD}📜 BALE LOGS${RESET}"
    echo ""

    echo "1. Install Blueprint"
    echo "2. GitHub Addon"
    echo "3. Remove Addon"
    echo "4. Update Addon"
    echo "5. Backup"
    echo "6. Back"
    echo ""

    read -rp "$(echo -e "${YELLOW}Select [1-6]: ${RESET}")" choice

    local logfile=""

    case "$choice" in

        1)
            logfile="$TEMP_DIR/install-one.log"
            ;;

        2)
            logfile="$TEMP_DIR/github-install.log"
            ;;

        3)
            logfile="$TEMP_DIR/remove.log"
            ;;

        4)
            logfile="$TEMP_DIR/update.log"
            ;;

        5)
            logfile="$TEMP_DIR/backup.log"
            ;;

        6)
            return
            ;;

        *)
            echo -e "${RED}✗ Invalid option.${RESET}"
            sleep 2
            return
            ;;
    esac

    echo ""

    if [ -f "$logfile" ]; then

        echo -e "${CYAN}File:${RESET} $logfile"
        echo ""
        echo -e "${GRAY}------------------------------------------------------------${RESET}"

        cat "$logfile"

        echo -e "${GRAY}------------------------------------------------------------${RESET}"

    else

        echo -e "${YELLOW}No log file found.${RESET}"
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

    echo -e "${WHITE}Current version:${RESET} ${SCRIPT_VERSION}"
    echo -e "${WHITE}Source:${RESET}"
    echo -e "${CYAN}${SCRIPT_URL}${RESET}"
    echo ""

    if ! command_exists curl; then

        echo -e "${RED}✗ curl is not installed.${RESET}"

        pause_screen

        return
    fi

    local new_file

    new_file="$(mktemp "$TEMP_DIR/bale-update.XXXXXX.sh")" || {

        echo -e "${RED}✗ Could not create update file.${RESET}"

        pause_screen

        return
    }

    echo -e "${CYAN}Checking GitHub...${RESET}"
    echo ""

    if ! curl -fsSL \
        --connect-timeout 15 \
        --max-time 60 \
        -A "BALE-Pterodactyl-Manager" \
        "$SCRIPT_URL" \
        -o "$new_file"; then

        echo -e "${RED}✗ Failed to download latest version.${RESET}"

        rm -f "$new_file"

        pause_screen

        return
    fi

    if [ ! -s "$new_file" ]; then

        echo -e "${RED}✗ Downloaded update is empty.${RESET}"

        rm -f "$new_file"

        pause_screen

        return
    fi

    if ! head -n 1 "$new_file" | grep -qE '^#!.*bash'; then

        echo -e "${RED}✗ Downloaded file does not look like a valid Bash script.${RESET}"

        rm -f "$new_file"

        pause_screen

        return
    fi

    if ! bash -n "$new_file"; then

        echo ""
        echo -e "${RED}✗ Downloaded script contains syntax errors.${RESET}"
        echo ""
        echo "The current manager was NOT changed."

        rm -f "$new_file"

        pause_screen

        return
    fi

    local new_version

    new_version="$(
        grep -E '^SCRIPT_VERSION=' "$new_file" |
        head -n 1 |
        sed -E 's/^SCRIPT_VERSION="([^"]*)".*/\1/'
    )"

    echo -e "${GREEN}✓ Downloaded latest manager.${RESET}"

    if [ -n "$new_version" ]; then
        echo -e "${WHITE}Remote version:${RESET} ${new_version}"
    fi

    echo -e "${WHITE}Current version:${RESET} ${SCRIPT_VERSION}"
    echo ""

    echo -e "${YELLOW}BALE is normally run directly from GitHub.${RESET}"
    echo ""
    echo "The safest update is to run:"
    echo ""
    echo -e "${CYAN}curl -fsSL $SCRIPT_URL | sudo bash${RESET}"
    echo ""

    if confirm "Run the downloaded latest version now"; then

        chmod 700 "$new_file"

        echo ""
        echo -e "${BLUE}Starting updated BALE Manager...${RESET}"
        echo ""

        exec bash "$new_file"
    fi

    rm -f "$new_file"

    pause_screen
}

# ============================================================
# CLEAN OLD BACKUPS
# ============================================================

cleanup_old_backups() {

    banner

    echo -e "${BLUE}${BOLD}🧹 BACKUP CLEANUP${RESET}"
    echo ""

    mkdir -p "$BACKUP_DIR"

    echo -e "${WHITE}Backup directory:${RESET}"
    echo "$BACKUP_DIR"
    echo ""

    echo -e "${YELLOW}Files older than 30 days can be removed.${RESET}"
    echo ""

    find "$BACKUP_DIR" \
        -type f \
        -mtime +30 \
        -print 2>/dev/null

    echo ""

    if confirm "Delete backups older than 30 days"; then

        find "$BACKUP_DIR" \
            -type f \
            -mtime +30 \
            -delete 2>/dev/null || true

        echo ""
        echo -e "${GREEN}✓ Old backups cleaned.${RESET}"

    else

        echo -e "${YELLOW}Cancelled.${RESET}"
    fi

    pause_screen
}

# ============================================================
# MAIN MENU
# ============================================================

main_menu() {

    while true; do

        banner

        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}║${RESET}             ${MAGENTA}${BOLD}BALE PTERODACTYL MANAGER${RESET}             ${CYAN}║${RESET}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"

        echo -e "${CYAN}║${RESET}  ${GREEN}1.${RESET}  🚀 Install Pterodactyl Panel                 ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}2.${RESET}  🔧 Blueprint Framework                      ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}3.${RESET}  📦 Install ALL Blueprints                   ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}4.${RESET}  📦 Install ONE Blueprint                    ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${BLUE}5.${RESET}  📥 Load Addon from GitHub                   ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${GREEN}6.${RESET}  📋 List Installed Addons                    ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${YELLOW}7.${RESET}  🗑  Remove / Uninstall Addon                 ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${BLUE}8.${RESET}  🔄 Update Addon                             ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${CYAN}9.${RESET}  📊 System / Pterodactyl Status              ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${MAGENTA}10.${RESET} 💾 Backup Pterodactyl                      ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${WHITE}11.${RESET} 🧹 Clear Laravel Cache                     ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${CYAN}12.${RESET} 🔄 Update BALE Manager                      ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${BLUE}13.${RESET} 🛠  Repair Pterodactyl                      ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${BLUE}14.${RESET} ⚙  Service Manager                         ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${BLUE}15.${RESET} 📜 View BALE Logs                          ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${BLUE}16.${RESET} 🧹 Cleanup Old Backups                     ${CYAN}║${RESET}"
        echo -e "${CYAN}║${RESET}  ${RED}17.${RESET} ✕ Exit                                      ${CYAN}║${RESET}"

        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"

        echo ""

        read -rp "$(echo -e "${YELLOW}Select an option [1-17]: ${RESET}")" option

        case "$option" in

            1)
                install_pterodactyl
                ;;

            2)
                blueprint_framework
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
                repair_panel
                ;;

            14)
                service_manager
                ;;

            15)
                view_logs
                ;;

            16)
                cleanup_old_backups
                ;;

            17)

                clear 2>/dev/null || true

                echo ""
                echo -e "${CYAN}${BOLD}============================================================${RESET}"
                echo -e "${GREEN}       👋 BALE Pterodactyl Manager closed.${RESET}"
                echo -e "${CYAN}${BOLD}============================================================${RESET}"
                echo ""

                exit 0
                ;;

            *)

                echo ""
                echo -e "${RED}✗ Invalid option. Choose 1-17.${RESET}"
                sleep 2
                ;;
        esac
    done
}

# ============================================================
# START
# ============================================================

check_root "$@"

mkdir -p "$TEMP_DIR" 2>/dev/null || true

# Install dependencies silently at startup.
# If installation fails, individual features will report
# the missing dependency instead of crashing the manager.
install_dependencies >/dev/null 2>&1 || true

main_menu
