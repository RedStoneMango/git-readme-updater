#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

add() {
  TARGET_REPOSITORY="$1"
  REMOTE_FILE="$2"
  IDENTIFIER="$3"
  if [ -z "$REMOTE_FILE" ] || [ -z "$IDENTIFIER" ]; then
    echo -e "\033[31mFile path and identifier are required to add a target.\033[0m"
    exit 1
  fi
  if [[ ! "$TARGET_REPOSITORY" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+:[a-zA-Z0-9_.-]+$ ]]; then
    echo -e "\033[31mInvalid target repository format. Expected format: 'owner/repo:branch'.\033[0m"
    exit 1
  fi
  if jq -e ".targets[\"$IDENTIFIER\"]" "$CONFIG_FILE" >/dev/null; then
    echo -e "\033[31mTarget with identifier '$IDENTIFIER' already exists.\033[0m"
    exit 1
  fi
  
  jq --arg identifier "$IDENTIFIER" \
    --arg repo "$TARGET_REPOSITORY" \
    --arg file "$REMOTE_FILE" \
    '
    .targets = (.targets // {}) | .targets[$identifier] = {repo: $repo, file: $file}
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  echo -e "\033[32mTarget '"$IDENTIFIER"' added successfully.\033[0m"
}

remove() {
  IDENTIFIER="$1"
  if [ -z "$IDENTIFIER" ]; then
    echo -e "\033[31mIdentifier is required to remove a target.\033[0m"
    exit 1
  fi
  if ! jq -e ".targets[\"$IDENTIFIER\"]" "$CONFIG_FILE" >/dev/null; then
    echo -e "\033[31mTarget with identifier '$IDENTIFIER' does not exist.\033[0m"
    exit 1
  fi
  
  jq --arg identifier "$IDENTIFIER" 'del(.targets[$identifier])' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  if [ "$(jq -r '.selected // empty' "$CONFIG_FILE")" = "$IDENTIFIER" ]; then
    jq 'del(.selected)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  fi

  echo -e "\033[32mTarget '"$IDENTIFIER"' removed successfully.\033[0m"
}

selectTarget() {
  IDENTIFIER="$1"
  if [ -z "$IDENTIFIER" ]; then
    jq 'del(.selected)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo -e "\033[32mUnselected target.\033[0m"
    return
  fi
  if ! jq -e ".targets[\"$IDENTIFIER\"]" "$CONFIG_FILE" >/dev/null; then
    echo -e "\033[31mTarget with identifier '$IDENTIFIER' does not exist.\033[0m"
    exit 1
  fi
  
  jq --arg identifier "$IDENTIFIER" '.selected = $identifier' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  echo -e "\033[32mTarget '"$IDENTIFIER"' selected successfully.\033[0m"
}

info() {
  IDENTIFIER="$1"
  TARGET=$(jq -r ".targets[\"$IDENTIFIER\"] // empty" "$CONFIG_FILE")
  if [ -z "$TARGET" ]; then
    echo -e "\033[31mTarget with identifier '$IDENTIFIER' does not exist.\033[0m"
    exit 1
  fi
  echo -e "\033[32mIdentifier: $IDENTIFIER"
  echo "Repository: $(echo "$TARGET" | jq -r '.repo')"
  echo -e "Remote File: $(echo "$TARGET" | jq -r '.file')\033[0m"
}

list() {
  if ! jq -e '.targets // empty' "$CONFIG_FILE" >/dev/null || [ "$(jq -r '.targets | length' "$CONFIG_FILE")" -eq 0 ]; then
    echo -e "\033[31mNo targets available.\033[0m"
    return
  fi

  echo "Available targets:"
  jq -r '.targets | to_entries[] | "- \(.key)"' "$CONFIG_FILE"
}

selected() {
  SELECTED=$(jq -r '.selected // empty' "$CONFIG_FILE")
  if [ -z "$SELECTED" ]; then
    echo -e "\033[31mNo target selected.\033[0m"
    exit 1
  fi

  TARGET=$(jq -r ".targets[\"$SELECTED\"] // empty" "$CONFIG_FILE")
  if [ -z "$TARGET" ]; then
    echo -e "\033[31;1m[CRITICAL]: Selected target is not registered! Unselecting target...\033[0m"
    jq 'del(.selected)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    exit 1
  fi

  echo -e "\033[32mSelected target: $SELECTED"
  echo "Repository: $(echo "$TARGET" | jq -r '.repo')"
  echo -e "Remote File: $(echo "$TARGET" | jq -r '.file')\033[0m"
}

./gru-precondition.sh
if [ $? -ne 0 ]; then
  echo -e "\033[31mProcodition check failed! Unable to run script.\033[0m"
  exit 1
fi

case "$1" in
  "add")
    add "$2" "$3" "$4"
    ;;
  "remove")
    remove "$2"
    ;;
  "select")
    selectTarget "$2"
    ;;
  "info")
    info "$2"
    ;;
  "list")
    list
    ;;
  "selected")
    selected
    ;;
  *)
    echo "Usage: $0 add <USER/REPO:BRANCH> <PATH/TO/FILE> <IDENTIFIER>"
    echo "       $0 remove <IDENTIFIER>"
    echo "       $0 select [<IDENTIFIER>]"
    echo "       $0 info [<IDENTIFIER>]"
    echo "       $0 list"
    echo "       $0 selected"
    exit 1
  ;;
esac