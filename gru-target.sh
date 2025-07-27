#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

addOrLink() {
  IDENTIFIER="$1"
  TARGET_REPOSITORY="$2"
  REMOTE_FILE="$3"
  add="$4"
  if [[ -z "$REMOTE_FILE" && -n "$TARGET_REPOSITORY" ]] || [[ -z "$TARGET_REPOSITORY" && -n "$REMOTE_FILE" ]]; then
    echo -e "\033[31mFile path and identifier are required to define a remote repository for a target.\033[0m"
    exit 1
  fi
  if [[ ! "$TARGET_REPOSITORY" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+:[a-zA-Z0-9_.-]+$ ]] && [[ ! -z "$TARGET_REPOSITORY" ]]; then
    echo -e "\033[31mInvalid target repository format. Expected format: 'owner/repo:branch'.\033[0m"
    exit 1
  fi
  if [[ -z "$IDENTIFIER" ]]; then
    echo -e "\033[31mIdentifier is required to manage a target.\033[0m"
    exit 1
  fi

  exists=$(jq -e --arg key "$IDENTIFIER" '.targets[$key] // empty' "$CONFIG_FILE")
  if [ "$add" = "true" ] && [ -n "$exists" ]; then
    echo -e "\033[31mTarget with identifier '"$IDENTIFIER"' already exists.\033[0m"
    exit 1
  elif [ "$add" = "false" ] && [ -z "$exists" ]; then
    echo -e "\033[31mTarget with identifier '"$IDENTIFIER"' does not exist.\033[0m"
    exit 1
  fi
  
  jq --arg identifier "$IDENTIFIER" \
    --arg repo "$TARGET_REPOSITORY" \
    --arg file "$REMOTE_FILE" '
    .targets = (.targets // {}) |
    .targets[$identifier] = (
      (.targets[$identifier] // {}) |
      if $repo != "" then . + {repo: $repo} else del(.repo) end |
      if $file != "" then . + {file: $file} else del(.file) end
    )
  ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  

  if [ $add = "true" ]; then

    if [ -n "$TARGET_REPOSITORY" ]; then
      echo -e "\033[32mSuccessfully added target '"$IDENTIFIER"' (linked to '"$REMOTE_FILE"' in '"$TARGET_REPOSITORY"').\033[0m"
    else
      echo -e "\033[32mSuccessfully added target '"$IDENTIFIER"' (no remote links).\033[0m"
    fi

  else

    if [ -n "$TARGET_REPOSITORY" ]; then
      echo -e "\033[32mTarget '"$IDENTIFIER"' successfully linked to '"$REMOTE_FILE"' in '"$TARGET_REPOSITORY"'.\033[0m"
    else
      echo -e "\033[32mSuccessfully removed remote link from target '"$IDENTIFIER"'.\033[0m"
    fi

  fi
}

remove() {
  IDENTIFIER="$1"
  if [ -z "$IDENTIFIER" ]; then
    echo -e "\033[31mIdentifier is required to remove a target.\033[0m"
    exit 1
  fi
  if ! jq -e ".targets[\"$IDENTIFIER\"]" "$CONFIG_FILE" >/dev/null; then
    echo -e "\033[31mTarget with identifier '"$IDENTIFIER"' does not exist.\033[0m"
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
    exit 0
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
    echo -e "\033[31mTarget with identifier '"$IDENTIFIER"' does not exist.\033[0m"
    exit 1
  fi
  echo -e "\033[32mSelected target: "$SELECTED""
  echo "Repository: $(echo "$TARGET" | jq -r '.repo // "NONE"')"
  echo -e "Remote File: $(echo "$TARGET" | jq -r '.file // "NONE"')\033[0m"
}

list() {
  if ! jq -e '.targets // empty' "$CONFIG_FILE" >/dev/null || [ "$(jq -r '.targets | length' "$CONFIG_FILE")" -eq 0 ]; then
    echo -e "\033[31mNo targets available.\033[0m"
    exit 1
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

  info "$SELECTED"
}

./gru-precondition.sh
if [ $? -ne 0 ]; then
  echo -e "\033[31mProcodition check failed! Unable to run script.\033[0m"
  exit 1
fi

case "$1" in
  "add")
    addOrLink "$2" "$3" "$4" "true"
    ;;
  "remove")
    remove "$2"
    ;;
  "link")
    addOrLink "$2" "$3" "$4" "false"
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
    echo "Usage: $0 add <IDENTIFIER> [<USER/REPO:BRANCH> <PATH/TO/FILE>]"
    echo "       $0 remove <IDENTIFIER>"
    echo "       $0 link <IDENTIFIER> [<USER/REPO:BRANCH> <PATH/TO/FILE>]"
    echo "       $0 select [<IDENTIFIER>]"
    echo "       $0 info [<IDENTIFIER>]"
    echo "       $0 list"
    echo "       $0 selected"
    exit 1
  ;;
esac
