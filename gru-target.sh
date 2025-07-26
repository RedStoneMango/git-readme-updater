#!/bin/bash

registerNew() {
  TRIMMED_TARGET_REPOSITORY=$(echo "$TARGET_REPOSITORY" | tr '/:' '+#')
  TARGET_STORAGE="$SCRIPT_DIR/targets/"$TRIMMED_TARGET_REPOSITORY".json"

  mkdir -p "$SCRIPT_DIR/targets"
  if [ ! -f "$TARGET_STORAGE" ]; then
    echo "{}" > "$TARGET_STORAGE"
  fi
}

./gru-precondition.sh
if [ $? -ne 0 ]; then
  echo -e "\033[31mProcodition check failed! Unable to run script.\033[0m"
  exit 1
fi

if { [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; } && [ -n "$1" ]; then
  echo "Usage: $0 <Target Repository> <File Name> <Name>"
  echo "       $0 <Name>"
  exit 1
fi

TARGET_REPOSITORY="$1"
TARGET_FILE="$2"
TARGET_NAME="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

if [[ ! -z "$TARGET_FILE" ]]; then # User registred new target

  if [[ ! "$TARGET_REPOSITORY" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+:[a-zA-Z0-9_.-]+$ ]]; then
    echo -e "\033[31mInvalid target repository format. Expected format: 'owner/repo:branch'.\033[0m"
    exit 1
  fi

  registerNew

  jq --arg name "$TARGET_NAME" \
    --arg repo "$TARGET_REPOSITORY" \
    --arg file "$TARGET_FILE" \
    '
    .targets = (.targets // {}) | .targets[$name] = {repo: $repo, file: $file}
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

fi



echo "Targeted repository '$TARGET_REPOSITORY' as gru target."
