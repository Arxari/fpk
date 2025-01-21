#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
DEBUG=false

debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${CYAN}DEBUG: $1${NC}" >&2
    fi
}

setup_flatpak() {
    if ! command -v flatpak &> /dev/null; then
        echo -e "${RED}Error: Flatpak is not installed${NC}"
        exit 1
    fi
    if flatpak remotes | grep -q "^flathub"; then
        debug "Flathub remote already configured, skipping setup"
        return 0
    fi
    echo -e "${BLUE}Setting up Flathub remote...${NC}"
    if ! flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        echo -e "${RED}Error: Failed to add Flathub remote${NC}"
        exit 1
    fi
}

search_and_install() {
    search_term="$1"
    debug "Search term: $search_term"
    temp_file=$(mktemp)
    debug "Created temp file: $temp_file"

    flatpak remote-ls --updates >/dev/null 2>&1
    flatpak search --columns=application,name,description,version,branch "$search_term" > "$temp_file"
    debug "Raw search results:"
    debug "$(cat "$temp_file")"

    readarray -t results < <(grep -v "^$" "$temp_file" | tac)
    if [ ${#results[@]} -eq 0 ]; then
        echo -e "${RED}No packages found matching '$search_term'${NC}"
        rm "$temp_file"
        exit 1
    fi

    declare -a app_ids
    echo -e "${BLUE}Search results for '$search_term':${NC}\n"
    
    total=${#results[@]}
    for i in "${!results[@]}"; do
        line="${results[$i]}"
        debug "Processing line: $line"
        IFS=$'\t' read -r app_id name description version branch <<< "$line"
        debug "Extracted app_id: $app_id"
        debug "Extracted name: $name"
        debug "Extracted version: $version"
        debug "Extracted branch: $branch"
        
        number=$((total - i))
        app_ids[$((number-1))]="$app_id"
        echo -e "$number)) ${GREEN}$name${NC} / ${BLUE}$app_id${NC}"
        echo -e "   $description ${YELLOW}($version)${NC} ${BLUE}[$branch]${NC}"
    done

    rm "$temp_file"
    debug "Removed temp file"

    echo -e "\nEnter the number of the package to install (or 'q' to quit):"
    read -r selection
    debug "User selected: $selection"

    if [[ "$selection" == "q" ]]; then
        echo "Exiting..."
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#results[@]}" ]; then
        echo -e "${RED}Invalid selection${NC}"
        exit 1
    fi

    selected_app_id="${app_ids[$((selection-1))]}"
    debug "Selected app_id: $selected_app_id"
    echo -e "\n${BLUE}Installing $selected_app_id...${NC}"
    flatpak install --assumeyes flathub "$selected_app_id"
}

if [ $# -eq 0 ]; then
    echo "Usage: ${0##*/} <search-term>"
    echo "Example: ${0##*/} firefox"
    exit 1
fi

setup_flatpak
search_and_install "$1"
