#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

write() {
  TEXT="$1"
  IDENTIFIER="$2"
  SECTION="$3"
  TARGET_IDENTIFIER="$4"

  if [ -z "$TEXT" ] || [ -z "$IDENTIFIER" ] || [ -z "$SECTION" ]; then
    echo -e "\033[31mText, identifier, and section are required to write.\033[0m"
    exit 1
  fi

  if [ -z "$TARGET_IDENTIFIER" ]; then
    TARGET_IDENTIFIER=$(jq -r '.selected // empty' "$CONFIG_FILE")
    if [ -z "$TARGET_IDENTIFIER" ]; then
      echo -e "\033[31mTarget is neither selected nor explicitly specified. Use 'gru-target select <IDENTIFIER>' to select a target or append it's identifier to the end of this command.\033[0m"
      exit 1
    fi
  fi

  if ! jq -e ".targets[\"$TARGET_IDENTIFIER\"]" "$CONFIG_FILE" >/dev/null; then
    echo -e "\033[31mTarget with identifier '$TARGET_IDENTIFIER' does not exist.\033[0m"
    exit 1
  fi

  jq --arg target "$TARGET_IDENTIFIER" \
   --arg identifier "$IDENTIFIER" \
   --arg section "$SECTION" \
   --arg text "$TEXT" \
   '
   .targets[$target].sections[$section][$identifier] = $text
   ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  echo -e "\033[32mWrote '$TEXT' with ID '$IDENTIFIER' in '$SECTION'\033[0m"
}

erase() {
  IDENTIFIER="$1"
  SECTION="$2"
  TARGET_IDENTIFIER="$3"

  if [ -z "$IDENTIFIER" ] || [ -z "$SECTION" ]; then
    echo -e "\033[31mIdentifier and section are required to erase.\033[0m"
    exit 1
  fi

  if [ -z "$TARGET_IDENTIFIER" ]; then
    TARGET_IDENTIFIER=$(jq -r '.selected // empty' "$CONFIG_FILE")
    if [ -z "$TARGET_IDENTIFIER" ]; then
      echo -e "\033[31mTarget is neither selected nor explicitly specified. Use 'gru-target select <IDENTIFIER>' to select a target or append it's identifier to the end of this command.\033[0m"
      exit 1
    fi
  fi

  if ! jq -e ".targets[\"$TARGET_IDENTIFIER\"]" "$CONFIG_FILE" >/dev/null; then
    echo -e "\033[31mTarget with identifier '$TARGET_IDENTIFIER' does not exist.\033[0m"
    exit 1
  fi

  if ! jq -e --arg target "$TARGET_IDENTIFIER" \
        --arg section "$SECTION" \
        --arg identifier "$IDENTIFIER" \
        '.targets[$target].sections[$section][$identifier]? != null' "$CONFIG_FILE" > /dev/null; then
        echo -e "\033[31mLine with identifier '$IDENTIFIER' does not exist in section '$SECTION'.\033[0m"
        exit 1
  fi

  jq --arg target "$TARGET_IDENTIFIER" \
    --arg section "$SECTION" \
    --arg identifier "$IDENTIFIER" \
    '
    .targets[$target].sections[$section] |= del(.[$identifier])
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"


  if jq -e --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '(.targets[$target].sections[$section] | type == "object" and length == 0)' "$CONFIG_FILE" >/dev/null; then
      jq --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '
        del(.targets[$target].sections[$section])
      ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  fi

  echo -e "\033[32mErased '$IDENTIFIER' from '$SECTION\033[0m"
}

read() {
  SECTION=""
  TARGET_IDENTIFIER=""

  if [ "$1" = "--section" ] || [ "$1" = "-s" ]; then
    if [ -z "$2" ]; then
      echo -e "\033[31mSection name is required.\033[0m"
      exit 1
    fi
    SECTION="$2"
    TARGET_IDENTIFIER="$3"
  else 
    TARGET_IDENTIFIER="$1"
  fi

  if [ -z "$TARGET_IDENTIFIER" ]; then
    TARGET_IDENTIFIER=$(jq -r '.selected // empty' "$CONFIG_FILE")
    if [ -z "$TARGET_IDENTIFIER" ]; then
      echo -e "\033[31mTarget is neither selected nor explicitly specified. Use 'gru-target select <IDENTIFIER>' to select a target or append it's identifier to the end of this command.\033[0m"
      exit 1
    fi
  fi

  if ! jq -e ".targets[\"$TARGET_IDENTIFIER\"]" "$CONFIG_FILE" >/dev/null; then
    echo -e "\033[31mTarget with identifier '$TARGET_IDENTIFIER' does not exist.\033[0m"
    exit 1
  fi

  if [ -z "$SECTION" ]; then
    if ! jq -e --arg target "$TARGET_IDENTIFIER" '.targets[$target].sections // empty' "$CONFIG_FILE" >/dev/null || [ "$(jq -r --arg target "$TARGET_IDENTIFIER" '.targets[$target].sections | length' "$CONFIG_FILE")" -eq 0 ]; then
      echo -e "\033[31mNo sections advailable.\033[0m"
      return
    fi

    echo "Available sections:"
    jq -r --arg target "$TARGET_IDENTIFIER" '.targets[$target].sections | to_entries[] | "- \(.key)"' "$CONFIG_FILE"

  else
    if ! jq -e --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '.targets[$target].sections[$section] // empty' "$CONFIG_FILE" >/dev/null || [ "$(jq -r --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '.targets[$target].sections[$section] | length' "$CONFIG_FILE")" -eq 0 ]; then
      echo -e "\033[31mSection '$SECTION' does not exist.\033[0m"
      return
    fi

    echo "Written lines:"
    jq -r --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '.targets[$target].sections[$section] | to_entries[] | "- \(.key) (\"\(.value)\") "' "$CONFIG_FILE"
  fi
}


./gru-precondition.sh
if [ $? -ne 0 ]; then
  echo -e "\033[31mProcodition check failed! Unable to run script.\033[0m"
  exit 1
fi

case "$1" in
  "write")
    write "$2" "$3" "$4" "$5"
    ;;
  "erase")
    erase "$2" "$3" "$4"
    ;;
  "read")
    read "$2" "$3" "$4"
    ;;
  *)
    echo "Usage: $0 write <TEXT> <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]"
    echo "       $0 erase <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]"
    echo "       $0 read [--section|-s <SECTION>] [<TARGET_IDENTIFIER>]"
    exit 1
  ;;
esac
