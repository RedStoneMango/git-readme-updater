#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

installJq() {
    echo "Installing jq..."
    if command -v apt-get >/dev/null 2>&1; then
        echo "Using apt-get to install jq"
        sudo apt-get update && sudo apt-get install jq
    elif command -v pacman >/dev/null 2>&1; then
        echo "Using pacman to install jq"
        sudo pacman -S jq
    elif command -v dnf >/dev/null 2>&1; then
        echo "Using dnf to install jq"
        sudo dnf install jq
    elif command -v brew >/dev/null 2>&1; then
        echo "Using Homebrew to install jq"
        brew install jq
    elif command -v yum >/dev/null 2>&1; then
        echo "Using yum to install jq"
        sudo yum install jq
    elif command -v zypper >/dev/null 2>&1; then
        echo "Using zypper to install jq"
        sudo zypper install jq
    elif command -v apk >/dev/null 2>&1; then
        echo "Using apk to install jq"
        sudo apk add jq
    elif command -v port >/dev/null 2>&1; then
        echo "Using MacPorts to install jq"
        sudo port install jq
    elif command -v scoop >/dev/null 2>&1; then
        echo "Using Scoop to install jq"
        scoop install jq
    elif command -v choco >/dev/null 2>&1; then
        echo "Using Chocolatey to install jq"
        choco install jq
    elif command -v flatpak >/dev/null 2>&1; then
        echo "Using Flatpak to install jq"
        flatpak install flathub org.jq.jq
    elif command -v snap >/dev/null 2>&1; then
        echo "Using Snap to install jq"
        sudo snap install jq
    else
        echo -e "\033[31mNo package manager not found. Please install jq manually.\033[0m"
        exit 1
    fi
}

checkJq() {
    if command -v jq >/dev/null 2>&1; then
        exit 0
    else
        echo -e "\033[31mRequired dependency jq not found.\033[0m"
        installJq

        if ! command -v jq >/dev/null 2>&1; then
            exit 1
        fi
    fi
}

initConfig() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "{}" > "$CONFIG_FILE"
    fi
}

initConfig
checkJq