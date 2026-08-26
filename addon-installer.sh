#!/bin/bash

# ============================================================
#  Blueprint Addon Manager
#  Install / Remove / Update / List Blueprint Addons
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
# Spinner
# ------------------------------------------------------------

spinner() {
    local pid=$1
    local message="${2:-Working}"
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

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

    spinner "$pid"

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

        if spinner "$pid"; then
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
        find . -maxdepth 1 -type f -name "*.blueprint" -printf "  • %f\n" | sort
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

    if ! command -v blueprint >/dev/null 2>&1; then
        echo -e "${RED}✗ Blueprint CLI not found.${RESET}"
        sleep 2
        return
    fi

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

    spinner "$pid"

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

    if ! command -v blueprint >/dev/null 2>&1; then
        echo -e "${RED}✗ Blueprint CLI not found.${RESET}"
        sleep 2
        return
    fi

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

    spinner "$pid"

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
    echo -e "${CYAN}║${RESET}  ${GREEN}3.${RESET} List Installed Addons              ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${YELLOW}4.${RESET} Remove / Uninstall Addon           ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${BLUE}5.${RESET} Update Addon                       ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${RED}6.${RESET} Exit                                ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${RESET}"
    echo ""

    read -rp "$(echo -e "${YELLOW}Select an option [1-6]: ${RESET}")" option

    case "$option" in

        1)
            check_blueprint && install_all
            ;;

        2)
            check_blueprint && install_one
            ;;

        3)
            check_blueprint && list_installed
            ;;

        4)
            check_blueprint && remove_addon
            ;;

        5)
            check_blueprint && update_addon
            ;;

        6)
            clear
            echo -e "${GREEN}👋 Blueprint Addon Manager closed.${RESET}"
            echo ""
            exit 0
            ;;

        *)
            echo ""
            echo -e "${RED}✗ Invalid option! Choose 1-6.${RESET}"
            sleep 2
            ;;

    esac

done
