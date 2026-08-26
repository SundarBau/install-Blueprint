#!/bin/bash

# ============================================================
#  Blueprint Addon Manager
#  Install / Remove / Update / List / Load GitHub Addons
# ============================================================

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
WHITE="\e[97m"
RESET="\e[0m"

PTERODACTYL_DIR="/var/www/pterodactyl"

# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

banner() {
    clear

    echo -e "${CYAN}"
    cat << "EOF"

           _____  _____   ____  _   _     _____ _   _  _____ _______       _      _       ______ _____
     /\   |  __ \|  __ \ / __ \| \ | |   |_   _| \ | |/ ____|__   __|/\   | |    | |    |  ____|  __ \
    /  \  | |  | | |  | | |  | |  \| |     | | |  \| | (___    | |  /  \  | |    | |    | |__  | |__) |
   / /\ \ | |  | |  | |  | | . ` |     | | | . ` |\___ \   | | / /\ \ | |    | |    |  __| |  _  /
  / ____ \| |__| | |__| | |__| | |\  |    _| |_| |\  |____) |  | |/ ____ \| |____| |____| |____| | \ \
 /_/    \_\_____/|_____/ \____/|_| \_|   |_____|_| \_|_____/   |_/_/    \_\______|______|______|_|  \_\

                         BLUEPRINT ADDON MANAGER
EOF
    echo -e "${RESET}"
}

# ------------------------------------------------------------
# Check Blueprint
# ------------------------------------------------------------

check_blueprint() {
    if ! command -v blueprint >/dev/null 2>&1; then
        echo -e "${RED}✗ Blueprint CLI is not installed.${RESET}"
        echo ""
        echo -e "${YELLOW}Install Blueprint Framework first.${RESET}"
        echo ""
        read -rp "Press Enter to continue..."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Check Pterodactyl
# ------------------------------------------------------------

check_pterodactyl() {
    if [ ! -d "$PTERODACTYL_DIR" ]; then
        echo -e "${RED}✗ Pterodactyl directory not found:${RESET}"
        echo "$PTERODACTYL_DIR"
        echo ""
        read -rp "Press Enter to continue..."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------
# Check Dependencies
# ------------------------------------------------------------

check_dependencies() {

    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if [ "${#missing[@]}" -gt 0 ]; then

        echo -e "${YELLOW}⚙ Installing required dependencies...${RESET}"
        echo ""

        apt-get update -qq

        apt-get install -y "${missing[@]}"

        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Failed to install dependencies.${RESET}"
            return 1
        fi

        echo ""
        echo -e "${GREEN}✓ Dependencies installed.${RESET}"
    fi

    return 0
}

# ------------------------------------------------------------
# Spinner
# ------------------------------------------------------------

spinner() {

    local pid=$1
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

        printf "\r${RED}✗ ${message} failed!${RESET}           \n"

    fi

    return "$status"
}

# ------------------------------------------------------------
# Find Blueprints
# ------------------------------------------------------------

find_blueprints() {

    mapfile -t FILES < <(
        find "$PTERODACTYL_DIR" \
            -maxdepth 1 \
            -type f \
            -name "*.blueprint" \
            -printf "%f\n" 2>/dev/null |
        sort
    )
}

# ------------------------------------------------------------
# Install One
# ------------------------------------------------------------

install_one() {

    find_blueprints

    if [ "${#FILES[@]}" -eq 0 ]; then

        echo -e "${RED}✗ No .blueprint files found!${RESET}"
        echo ""

        read -rp "Press Enter to continue..."

        return
    fi

    echo ""
    echo -e "${YELLOW}Available Blueprints:${RESET}"
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

        sleep 2

        return
    fi

    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#FILES[@]}" ]; then

        echo -e "${RED}✗ Invalid selection.${RESET}"

        sleep 2

        return
    fi

    selected="${FILES[$((choice-1))]}"

    echo ""
    echo -e "${BLUE}⚡ Installing:${RESET} ${MAGENTA}${selected}${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    ( blueprint -i "$selected" ) &

    pid=$!

    spinner "$pid" "Installing $selected"

    echo ""

    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# Install All
# ------------------------------------------------------------

install_all() {

    find_blueprints

    if [ "${#FILES[@]}" -eq 0 ]; then

        echo -e "${RED}✗ No .blueprint files found!${RESET}"
        echo ""

        read -rp "Press Enter to continue..."

        return
    fi

    echo ""
    echo -e "${BLUE}⚡ Installing ${#FILES[@]} blueprint(s)...${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    failed=0
    success=0

    for file in "${FILES[@]}"; do

        echo -e "${CYAN}➡ Installing:${RESET} ${MAGENTA}${file}${RESET}"

        ( blueprint -i "$file" ) &

        pid=$!

        if spinner "$pid" "Installing $file"; then
            ((success++))
        else
            ((failed++))
        fi

        echo ""

    done

    echo -e "${CYAN}============================================${RESET}"
    echo -e "${GREEN}✓ Successful: ${success}${RESET}"
    echo -e "${RED}✗ Failed:     ${failed}${RESET}"
    echo -e "${CYAN}============================================${RESET}"

    echo ""

    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# ADDON LOAD FROM GITHUB
# ------------------------------------------------------------

addon_load() {

    echo ""
    echo -e "${BLUE}📥 ADDON LOAD${RESET}"
    echo -e "${CYAN}Load a Blueprint addon directly from GitHub${RESET}"
    echo ""

    if ! check_dependencies; then

        echo ""
        read -rp "Press Enter to continue..."

        return
    fi

    cd "$PTERODACTYL_DIR" || return

    echo -e "${YELLOW}GitHub Repository URL:${RESET}"
    echo ""
    echo -e "${WHITE}Example:${RESET}"
    echo "https://github.com/Gamer100309/pterodactyl-universal-manager"
    echo ""

    read -rp "$(echo -e "${CYAN}GitHub Repo: ${RESET}")" repo_url

    if [ -z "$repo_url" ]; then

        echo ""
        echo -e "${RED}✗ No repository URL entered.${RESET}"

        sleep 2

        return
    fi

    # Remove trailing slash
    repo_url="${repo_url%/}"

    # Remove .git if supplied
    repo_url="${repo_url%.git}"

    # Validate GitHub URL
    if [[ ! "$repo_url" =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then

        echo ""
        echo -e "${RED}✗ Invalid GitHub repository URL.${RESET}"
        echo ""
        echo -e "${YELLOW}Correct format:${RESET}"
        echo "https://github.com/OWNER/REPOSITORY"

        sleep 3

        return
    fi

    # Extract owner/repository
    repo_path="${repo_url#https://github.com/}"

    echo ""
    echo -e "${CYAN}🔎 Searching GitHub releases...${RESET}"
    echo ""

    release_api="https://api.github.com/repos/${repo_path}/releases/latest"

    release_json=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: Blueprint-Addon-Manager" \
        "$release_api" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$release_json" ]; then

        echo -e "${RED}✗ Unable to access GitHub release.${RESET}"
        echo ""
        echo -e "${YELLOW}Possible reasons:${RESET}"
        echo "  • Repository does not exist"
        echo "  • Repository has no releases"
        echo "  • GitHub API request failed"
        echo ""

        read -rp "Press Enter to continue..."

        return
    fi

    # Latest release
    tag_name=$(echo "$release_json" | jq -r '.tag_name // empty')

    release_name=$(echo "$release_json" | jq -r '.name // empty')

    if [ -z "$tag_name" ]; then

        echo -e "${RED}✗ No published release found.${RESET}"
        echo ""
        echo -e "${YELLOW}The repository must contain a GitHub Release.${RESET}"
        echo ""

        read -rp "Press Enter to continue..."

        return
    fi

    echo -e "${GREEN}✓ Latest Release:${RESET} ${MAGENTA}${tag_name}${RESET}"

    if [ -n "$release_name" ] && [ "$release_name" != "null" ]; then

        echo -e "${WHITE}  Name: ${release_name}${RESET}"

    fi

    echo ""

    # Find .blueprint asset
    blueprint_file=$(echo "$release_json" | jq -r '
        .assets[]?
        | select(.name | ascii_downcase | endswith(".blueprint"))
        | .name
    ' | head -n 1)

    blueprint_url=$(echo "$release_json" | jq -r '
        .assets[]?
        | select(.name | ascii_downcase | endswith(".blueprint"))
        | .browser_download_url
    ' | head -n 1)

    if [ -z "$blueprint_file" ] || [ -z "$blueprint_url" ]; then

        echo -e "${RED}✗ No .blueprint asset found in this release.${RESET}"
        echo ""

        echo -e "${YELLOW}Available release files:${RESET}"

        assets=$(echo "$release_json" | jq -r '.assets[]?.name')

        if [ -n "$assets" ]; then

            echo "$assets" | while read -r asset; do
                echo -e "  ${WHITE}• ${asset}${RESET}"
            done

        else

            echo -e "  ${YELLOW}No release assets found.${RESET}"

        fi

        echo ""

        read -rp "Press Enter to continue..."

        return
    fi

    echo -e "${GREEN}✓ Blueprint found:${RESET} ${MAGENTA}${blueprint_file}${RESET}"
    echo ""

    # Check existing file
    if [ -f "$PTERODACTYL_DIR/$blueprint_file" ]; then

        echo -e "${YELLOW}⚠ Blueprint already exists:${RESET}"
        echo -e "  ${WHITE}$blueprint_file${RESET}"
        echo ""

        read -rp "$(echo -e "${YELLOW}Replace existing file? [y/N]: ${RESET}")" replace

        if [[ ! "$replace" =~ ^[Yy]$ ]]; then

            echo ""
            echo -e "${YELLOW}Cancelled.${RESET}"

            sleep 2

            return
        fi

        rm -f "$PTERODACTYL_DIR/$blueprint_file"

    fi

    # Download
    echo ""
    echo -e "${BLUE}📥 Downloading Blueprint...${RESET}"
    echo ""

    if curl -fL \
        --progress-bar \
        -H "User-Agent: Blueprint-Addon-Manager" \
        -o "$PTERODACTYL_DIR/$blueprint_file" \
        "$blueprint_url"; then

        echo ""
        echo -e "${GREEN}✓ Download completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Download failed.${RESET}"

        rm -f "$PTERODACTYL_DIR/$blueprint_file"

        echo ""

        read -rp "Press Enter to continue..."

        return
    fi

    # Verify file
    if [ ! -s "$PTERODACTYL_DIR/$blueprint_file" ]; then

        echo -e "${RED}✗ Downloaded file is empty.${RESET}"

        rm -f "$PTERODACTYL_DIR/$blueprint_file"

        sleep 2

        return
    fi

    echo ""
    echo -e "${BLUE}⚡ Installing Blueprint...${RESET}"
    echo ""
    echo -e "${WHITE}File:${RESET} ${MAGENTA}${blueprint_file}${RESET}"
    echo ""

    if blueprint -i "$blueprint_file"; then

        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║       ✓ ADDON INSTALLED SUCCESSFULLY       ║${RESET}"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${RESET}"
        echo ""

    else

        echo ""
        echo -e "${RED}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║          ✗ ADDON INSTALL FAILED            ║${RESET}"
        echo -e "${RED}╚════════════════════════════════════════════╝${RESET}"
        echo ""

    fi

    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# List Installed Addons
# ------------------------------------------------------------

list_installed() {

    echo ""
    echo -e "${BLUE}📦 Installed Blueprint Addons${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    if blueprint -list 2>/dev/null; then
        :
    else

        echo -e "${YELLOW}Blueprint list command unavailable.${RESET}"
        echo ""

        echo -e "${CYAN}Local .blueprint files:${RESET}"

        find . \
            -maxdepth 1 \
            -type f \
            -name "*.blueprint" \
            -printf "  • %f\n" |
        sort

    fi

    echo ""

    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# Remove Addon
# ------------------------------------------------------------

remove_addon() {

    echo ""
    echo -e "${YELLOW}⚠ Addon Removal${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    echo -e "${CYAN}Enter the addon name to remove.${RESET}"
    echo -e "${YELLOW}Example: universalmanager${RESET}"
    echo ""

    read -rp "Addon name: " addon

    if [ -z "$addon" ]; then

        echo -e "${RED}✗ No addon name entered.${RESET}"

        sleep 2

        return
    fi

    echo ""
    echo -e "${BLUE}⚡ Removing:${RESET} ${MAGENTA}${addon}${RESET}"
    echo ""

    ( blueprint -remove "$addon" ) &

    pid=$!

    spinner "$pid" "Removing $addon"

    echo ""

    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# Update Addon
# ------------------------------------------------------------

update_addon() {

    echo ""
    echo -e "${BLUE}🔄 Update Blueprint Addon${RESET}"
    echo ""

    cd "$PTERODACTYL_DIR" || return

    echo -e "${CYAN}Enter the addon name to update.${RESET}"
    echo ""

    read -rp "Addon name: " addon

    if [ -z "$addon" ]; then

        echo -e "${RED}✗ No addon name entered.${RESET}"

        sleep 2

        return
    fi

    echo ""
    echo -e "${BLUE}⚡ Updating:${RESET} ${MAGENTA}${addon}${RESET}"
    echo ""

    ( blueprint -update "$addon" ) &

    pid=$!

    spinner "$pid" "Updating $addon"

    echo ""

    read -rp "Press Enter to continue..."
}

# ------------------------------------------------------------
# Main Menu
# ------------------------------------------------------------

while true; do

    banner

    if ! check_pterodactyl; then
        exit 1
    fi

    echo -e "${WHITE}Pterodactyl:${RESET} ${CYAN}${PTERODACTYL_DIR}${RESET}"
    echo ""

    echo -e "${CYAN}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}        ${MAGENTA}BLUEPRINT ADDON MANAGER${RESET}         ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}1.${RESET} Install ${WHITE}ALL${RESET} Blueprints             ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}2.${RESET} Install ${WHITE}ONE${RESET} Blueprint             ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}3.${RESET} Addon Load from ${WHITE}GitHub${RESET}            ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}4.${RESET} List Installed Addons              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${YELLOW}5.${RESET} Remove / Uninstall Addon           ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}6.${RESET} Update Addon                       ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${RED}7.${RESET} Exit                                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${RESET}"
    echo ""

    read -rp "$(echo -e "${YELLOW}Select an option [1-7]: ${RESET}")" option

    case "$option" in

        1)
            check_blueprint && install_all
            ;;

        2)
            check_blueprint && install_one
            ;;

        3)
            check_blueprint && addon_load
            ;;

        4)
            check_blueprint && list_installed
            ;;

        5)
            check_blueprint && remove_addon
            ;;

        6)
            check_blueprint && update_addon
            ;;

        7)
            clear
            echo -e "${GREEN}👋 Blueprint Addon Manager closed.${RESET}"
            echo ""
            exit 0
            ;;

        *)
            echo ""
            echo -e "${RED}✗ Invalid option! Choose 1-7.${RESET}"
            sleep 2
            ;;

    esac

done
