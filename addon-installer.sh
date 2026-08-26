# ------------------------------------------------------------
# ADDON LOAD FROM GITHUB
# Supports:
# https://github.com/OWNER/REPO
# https://github.com/OWNER/REPO.git
# https://github.com/OWNER/REPO/releases
# https://github.com/OWNER/REPO/releases/latest
# https://github.com/OWNER/REPO/releases/tag/V1.0
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

    echo -e "${YELLOW}GitHub Repository / Release URL:${RESET}"
    echo ""
    echo -e "${WHITE}Examples:${RESET}"
    echo "https://github.com/Gamer100309/pterodactyl-universal-manager"
    echo "https://github.com/fernsehheft/Abyss-Purple/releases/tag/1.0"
    echo ""

    read -rp "$(echo -e "${CYAN}GitHub URL: ${RESET}")" input_url

    if [ -z "$input_url" ]; then
        echo ""
        echo -e "${RED}✗ No GitHub URL entered.${RESET}"
        sleep 2
        return
    fi

    # --------------------------------------------------------
    # Clean URL
    # --------------------------------------------------------

    input_url="${input_url#"${input_url%%[![:space:]]*}"}"
    input_url="${input_url%"${input_url##*[![:space:]]}"}"

    input_url="${input_url%/}"
    input_url="${input_url%.git}"

    # Remove query string / fragment
    input_url="${input_url%%\?*}"
    input_url="${input_url%%\#*}"

    # --------------------------------------------------------
    # Validate GitHub domain
    # --------------------------------------------------------

    if [[ ! "$input_url" =~ ^https://github\.com/ ]]; then

        echo ""
        echo -e "${RED}✗ Invalid GitHub URL.${RESET}"
        echo ""
        echo -e "${YELLOW}Supported format:${RESET}"
        echo "https://github.com/OWNER/REPOSITORY"
        echo "https://github.com/OWNER/REPOSITORY/releases/tag/VERSION"

        sleep 3
        return
    fi

    # --------------------------------------------------------
    # Extract repository path
    # --------------------------------------------------------

    repo_path="${input_url#https://github.com/}"

    # Remove release paths
    repo_path="${repo_path%%/releases/*}"
    repo_path="${repo_path%%/releases}"

    # Remove other GitHub paths if supplied
    repo_path="${repo_path%%/tree/*}"
    repo_path="${repo_path%%/commit/*}"
    repo_path="${repo_path%%/actions/*}"

    # Remove trailing slash
    repo_path="${repo_path%/}"

    # --------------------------------------------------------
    # Validate OWNER/REPOSITORY
    # --------------------------------------------------------

    if [[ ! "$repo_path" =~ ^[^/]+/[^/]+$ ]]; then

        echo ""
        echo -e "${RED}✗ Invalid GitHub repository URL.${RESET}"
        echo ""
        echo -e "${YELLOW}Correct examples:${RESET}"
        echo "https://github.com/OWNER/REPOSITORY"
        echo "https://github.com/OWNER/REPOSITORY/releases/tag/V1.0"

        sleep 3
        return
    fi

    owner="${repo_path%%/*}"
    repository="${repo_path#*/}"

    echo ""
    echo -e "${GREEN}✓ Repository:${RESET} ${WHITE}${owner}/${repository}${RESET}"
    echo ""

    # --------------------------------------------------------
    # Detect requested release
    # --------------------------------------------------------

    requested_tag=""

    if [[ "$input_url" =~ /releases/tag/([^/]+)$ ]]; then
        requested_tag="${BASH_REMATCH[1]}"
    fi

    # URL decode basic release tag
    requested_tag="${requested_tag//%2F/\/}"
    requested_tag="${requested_tag//%20/ }"

    # --------------------------------------------------------
    # GitHub API
    # --------------------------------------------------------

    api_base="https://api.github.com/repos/${repo_path}"

    echo -e "${CYAN}🔎 Checking GitHub repository...${RESET}"
    echo ""

    repo_json=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: Blueprint-Addon-Manager" \
        "$api_base" 2>/dev/null) || {

        echo -e "${RED}✗ Unable to access GitHub repository.${RESET}"
        echo ""
        echo -e "${YELLOW}Possible reasons:${RESET}"
        echo "  • Repository does not exist"
        echo "  • Repository is private"
        echo "  • GitHub API request failed"
        echo "  • Network/DNS problem"
        echo ""

        read -rp "Press Enter to continue..."
        return
    }

    # Check API error
    api_message=$(echo "$repo_json" | jq -r '.message // empty')

    if [ -n "$api_message" ]; then

        echo -e "${RED}✗ GitHub API error:${RESET} $api_message"
        echo ""

        read -rp "Press Enter to continue..."
        return
    fi

    repo_name=$(echo "$repo_json" | jq -r '.full_name // empty')

    if [ -z "$repo_name" ]; then

        echo -e "${RED}✗ Repository could not be verified.${RESET}"
        echo ""

        read -rp "Press Enter to continue..."
        return
    fi

    echo -e "${GREEN}✓ Repository verified:${RESET} ${repo_name}"
    echo ""

    # --------------------------------------------------------
    # Get release
    # --------------------------------------------------------

    release_json=""

    if [ -n "$requested_tag" ]; then

        echo -e "${CYAN}🔎 Checking requested release:${RESET} ${MAGENTA}${requested_tag}${RESET}"
        echo ""

        encoded_tag=$(printf '%s' "$requested_tag" | jq -sRr @uri)

        release_json=$(curl -fsSL \
            -H "Accept: application/vnd.github+json" \
            -H "User-Agent: Blueprint-Addon-Manager" \
            "$api_base/releases/tags/$encoded_tag" 2>/dev/null) || {

            echo -e "${RED}✗ Release '${requested_tag}' was not found.${RESET}"
            echo ""

            read -rp "Press Enter to continue..."
            return
        }

    else

        echo -e "${CYAN}🔎 Searching latest GitHub release...${RESET}"
        echo ""

        release_json=$(curl -fsSL \
            -H "Accept: application/vnd.github+json" \
            -H "User-Agent: Blueprint-Addon-Manager" \
            "$api_base/releases/latest" 2>/dev/null) || {

            echo -e "${RED}✗ Unable to access latest release.${RESET}"
            echo ""
            echo -e "${YELLOW}This repository may not have a published release.${RESET}"
            echo ""

            read -rp "Press Enter to continue..."
            return
        }

    fi

    # --------------------------------------------------------
    # Check release API response
    # --------------------------------------------------------

    api_message=$(echo "$release_json" | jq -r '.message // empty')

    if [ -n "$api_message" ]; then

        echo -e "${RED}✗ GitHub release error:${RESET} $api_message"
        echo ""

        read -rp "Press Enter to continue..."
        return
    fi

    tag_name=$(echo "$release_json" | jq -r '.tag_name // empty')
    release_name=$(echo "$release_json" | jq -r '.name // empty')
    prerelease=$(echo "$release_json" | jq -r '.prerelease // false')
    draft=$(echo "$release_json" | jq -r '.draft // false')

    if [ -z "$tag_name" ]; then

        echo -e "${RED}✗ No valid GitHub release found.${RESET}"
        echo ""

        read -rp "Press Enter to continue..."
        return
    fi

    echo -e "${GREEN}✓ Release:${RESET} ${MAGENTA}${tag_name}${RESET}"

    if [ -n "$release_name" ] && [ "$release_name" != "null" ]; then
        echo -e "${WHITE}  Name: ${release_name}${RESET}"
    fi

    if [ "$prerelease" = "true" ]; then
        echo -e "${YELLOW}  ⚠ This is a pre-release.${RESET}"
    fi

    if [ "$draft" = "true" ]; then
        echo -e "${YELLOW}  ⚠ This is a draft release.${RESET}"
    fi

    echo ""

    # --------------------------------------------------------
    # Find Blueprint asset
    # --------------------------------------------------------

    blueprint_data=$(echo "$release_json" | jq -r '
        .assets[]?
        | select(.name | ascii_downcase | endswith(".blueprint"))
        | [.name, .browser_download_url]
        | @tsv
    ' | head -n 1)

    blueprint_file=""
    blueprint_url=""

    if [ -n "$blueprint_data" ]; then

        blueprint_file=$(echo "$blueprint_data" | cut -f1)
        blueprint_url=$(echo "$blueprint_data" | cut -f2-)

    fi

    # --------------------------------------------------------
    # If no blueprint asset, show available files
    # --------------------------------------------------------

    if [ -z "$blueprint_file" ] || [ -z "$blueprint_url" ]; then

        echo -e "${RED}✗ No .blueprint asset found in this release.${RESET}"
        echo ""

        assets=$(echo "$release_json" | jq -r '.assets[]?.name')

        if [ -n "$assets" ]; then

            echo -e "${YELLOW}Available release files:${RESET}"
            echo ""

            while IFS= read -r asset; do
                [ -n "$asset" ] &&
                    echo -e "  ${WHITE}• ${asset}${RESET}"
            done <<< "$assets"

        else

            echo -e "${YELLOW}No release assets found.${RESET}"

        fi

        echo ""
        echo -e "${YELLOW}The release must contain a .blueprint file.${RESET}"
        echo ""

        read -rp "Press Enter to continue..."
        return
    fi

    # --------------------------------------------------------
    # Display Blueprint
    # --------------------------------------------------------

    echo -e "${GREEN}✓ Blueprint found:${RESET} ${MAGENTA}${blueprint_file}${RESET}"
    echo -e "${WHITE}  Download:${RESET} ${blueprint_url}"
    echo ""

    # --------------------------------------------------------
    # Existing file
    # --------------------------------------------------------

    target_file="$PTERODACTYL_DIR/$blueprint_file"

    if [ -f "$target_file" ]; then

        echo -e "${YELLOW}⚠ Blueprint already exists:${RESET}"
        echo -e "  ${WHITE}${blueprint_file}${RESET}"
        echo ""

        read -rp "$(echo -e "${YELLOW}Replace existing file? [y/N]: ${RESET}")" replace

        if [[ ! "$replace" =~ ^[Yy]$ ]]; then

            echo ""
            echo -e "${YELLOW}Cancelled.${RESET}"

            sleep 2
            return
        fi

        rm -f "$target_file"

    fi

    # --------------------------------------------------------
    # Download
    # --------------------------------------------------------

    temp_file="${target_file}.download"

    rm -f "$temp_file"

    echo ""
    echo -e "${BLUE}📥 Downloading Blueprint...${RESET}"
    echo ""

    if curl -fL \
        --progress-bar \
        --retry 3 \
        --connect-timeout 15 \
        -H "User-Agent: Blueprint-Addon-Manager" \
        -o "$temp_file" \
        "$blueprint_url"; then

        echo ""
        echo -e "${GREEN}✓ Download completed.${RESET}"

    else

        echo ""
        echo -e "${RED}✗ Download failed.${RESET}"

        rm -f "$temp_file"

        echo ""
        read -rp "Press Enter to continue..."
        return
    fi

    # --------------------------------------------------------
    # Verify download
    # --------------------------------------------------------

    if [ ! -s "$temp_file" ]; then

        echo ""
        echo -e "${RED}✗ Downloaded file is empty.${RESET}"

        rm -f "$temp_file"

        sleep 2
        return
    fi

    # Check file type / ZIP signature
    if ! file "$temp_file" 2>/dev/null | grep -Eqi \
        'Zip archive|Java archive|archive'; then

        echo ""
        echo -e "${YELLOW}⚠ Warning: downloaded file does not look like an archive.${RESET}"

        echo ""
        echo -e "${WHITE}File information:${RESET}"
        file "$temp_file" 2>/dev/null || true
        echo ""

        read -rp "$(echo -e "${YELLOW}Continue installation anyway? [y/N]: ${RESET}")" continue_install

        if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then

            rm -f "$temp_file"

            echo ""
            echo -e "${YELLOW}Installation cancelled.${RESET}"

            sleep 2
            return
        fi
    fi

    mv -f "$temp_file" "$target_file"

    # --------------------------------------------------------
    # Permissions
    # --------------------------------------------------------

    if id www-data >/dev/null 2>&1; then
        chown www-data:www-data "$target_file" 2>/dev/null || true
    fi

    chmod 644 "$target_file" 2>/dev/null || true

    # --------------------------------------------------------
    # Install Blueprint
    # --------------------------------------------------------

    echo ""
    echo -e "${BLUE}⚡ Installing Blueprint...${RESET}"
    echo ""
    echo -e "${WHITE}File:${RESET} ${MAGENTA}${blueprint_file}${RESET}"
    echo -e "${WHITE}Version:${RESET} ${MAGENTA}${tag_name}${RESET}"
    echo ""

    if blueprint -i "$target_file"; then

        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║       ✓ ADDON INSTALLED SUCCESSFULLY       ║${RESET}"
        echo -e "${GREEN}╠════════════════════════════════════════════╣${RESET}"
        printf "${GREEN}║${RESET} %-42s ${GREEN}║${RESET}\n" "Addon: $blueprint_file"
        printf "${GREEN}║${RESET} %-42s ${GREEN}║${RESET}\n" "Version: $tag_name"
        echo -e "${GREEN}╚════════════════════════════════════════════╝${RESET}"
        echo ""

    else

        echo ""
        echo -e "${RED}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║          ✗ ADDON INSTALL FAILED            ║${RESET}"
        echo -e "${RED}╠════════════════════════════════════════════╣${RESET}"
        printf "${RED}║${RESET} %-42s ${RED}║${RESET}\n" "File: $blueprint_file"
        echo -e "${RED}╚════════════════════════════════════════════╝${RESET}"
        echo ""

        echo -e "${YELLOW}The .blueprint file was kept at:${RESET}"
        echo -e "${WHITE}$target_file${RESET}"
        echo ""

    fi

    read -rp "Press Enter to continue..."
}
