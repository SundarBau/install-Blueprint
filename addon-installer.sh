#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
MAGENTA="\e[35m"
RESET="\e[0m"

banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"

           _____  _____   ____  _   _     _____ _   _  _____ _______       _      _       ______ _____  
     /\   |  __ \|  __ \ / __ \| \ | |   |_   _| \ | |/ ____|__   __|/\   | |    | |    |  ____|  __ \ 
    /  \  | |  | | |  | | |  | |  \| |     | | |  \| | (___    | |  /  \  | |    | |    | |__  | |__) |
   / /\ \ | |  | |  | | |  | | . ` |     | | | . ` |\___ \   | | / /\ \ | |    | |    |  __| |  _  / 
  / ____ \| |__| | |__| | |__| | |\  |    _| |_| |\  |____) |  | |/ ____ \| |____| |____| |____| | \ \ 
 /_/    \_\_____/|_____/ \____/|_| \_|   |_____|_| \_|_____/   |_/_/    \_\______|______|______|_|  \_\
EOF
    echo -e "${RESET}"
}

spinner() {
    local pid=$1
    local spin=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${spin[@]}"; do
            kill -0 "$pid" 2>/dev/null || break
            printf "\r${MAGENTA}Installing... ${frame}${RESET}"
            sleep 0.1
        done
    done

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        printf "\r${GREEN}✓ Installed successfully!${RESET}       \n"
    else
        printf "\r${RED}✗ Installation failed!${RESET}          \n"
    fi

    return $status
}

banner

echo -e "${YELLOW}🔍 Searching for .blueprint files...${RESET}"
sleep 1

mapfile -t FILES < <(find . -maxdepth 1 -type f -name "*.blueprint" -printf "%f\n" | sort)

if (( ${#FILES[@]} == 0 )); then
    echo -e "${RED}❌ No .blueprint files found!${RESET}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Found ${#FILES[@]} blueprint file(s):${RESET}"
echo ""

i=1
for file in "${FILES[@]}"; do
    echo -e "  ${CYAN}$i.${RESET} $file"
    ((i++))
done

echo ""

read -rp "$(echo -e "${YELLOW}Install ALL blueprints? (y/n): ${RESET}")" confirm

# =====================================================
# INSTALL ALL
# =====================================================

if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then

    echo ""
    echo -e "${BLUE}⚡ Installing ALL blueprints...${RESET}"
    echo ""

    failed=0

    for f in "${FILES[@]}"; do
        echo -e "${CYAN}➡ Installing: ${MAGENTA}$f${RESET}"

        ( blueprint -i "$f" ) &
        pid=$!

        if ! spinner "$pid"; then
            ((failed++))
        fi

        echo ""
    done

    if [ "$failed" -eq 0 ]; then
        echo -e "${GREEN}🎉 All blueprints installed successfully!${RESET}"
    else
        echo -e "${RED}⚠ $failed blueprint(s) failed to install.${RESET}"
    fi

# =====================================================
# INSTALL ONE
# =====================================================

else

    echo ""
    echo -e "${YELLOW}Select a blueprint to install:${RESET}"
    echo ""

    i=1
    for file in "${FILES[@]}"; do
        echo -e "  ${CYAN}$i.${RESET} $file"
        ((i++))
    done

    echo ""
    read -rp "$(echo -e "${YELLOW}Enter blueprint number: ${RESET}")" choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#FILES[@]}" ]; then
        echo -e "${RED}❌ Invalid selection!${RESET}"
        exit 1
    fi

    selected="${FILES[$((choice-1))]}"

    echo ""
    echo -e "${BLUE}⚡ Installing: ${MAGENTA}$selected${RESET}"
    echo ""

    ( blueprint -i "$selected" ) &
    pid=$!

    if spinner "$pid"; then
        echo ""
        echo -e "${GREEN}🎉 Blueprint installed successfully!${RESET}"
    else
        echo ""
        echo -e "${RED}❌ Blueprint installation failed!${RESET}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}✨ Blueprint Installer finished.${RESET}"
echo ""
