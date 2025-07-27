#!/usr/bin/env bash

resolve_dir() {
  SOURCE="${BASH_SOURCE[0]}"
  while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
  done
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  echo "$DIR"
}

SCRIPT_DIR="$(resolve_dir)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

write() {
  TEXT="$1"
  IDENTIFIER="$2"
  SECTION="$3"
  TARGET_IDENTIFIER="$4"
  write_placeholder="$5"

  if [ "$IDENTIFIER" = "PLACEHOLDER" ] && [ "$write_placeholder" = "false" ]; then
    echo -e "\033[31m'PLACEHOLDER' is a special identifier which you cannot use to write lines. Use '"$0" set-placeholder <PLACEHOLDER> <SECTION> [<TARGET_IDENTIFIER>]' if you want to add a placeholder.\033[0m"
    exit 1
  fi

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
    echo -e "\033[31mTarget with identifier '"$TARGET_IDENTIFIER"' does not exist.\033[0m"
    exit 1
  fi

  jq --arg target "$TARGET_IDENTIFIER" \
   --arg identifier "$IDENTIFIER" \
   --arg section "$SECTION" \
   --arg text "$TEXT" \
   '
   .targets[$target].sections[$section][$identifier] = $text
   ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

  if [ "$write_placeholder" = "true" ]; then
    echo -e "\033[32mSet placeholder for section '"$SECTION"' to '"$TEXT"'\033[0m"
  else
    echo -e "\033[32mWrote '"$TEXT"' with ID '"$IDENTIFIER"' in '"$SECTION"'\033[0m"
  fi
}

erase() {
  IDENTIFIER="$1"
  SECTION="$2"
  TARGET_IDENTIFIER="$3"

    if [ "$IDENTIFIER" = "PLACEHOLDER" ]; then
    echo -e "\033[31m'PLACEHOLDER' is a special identifier which you cannot erase. Use '"$0" set-placeholder \"\" <SECTION> [<TARGET_IDENTIFIER>]' if you want to unset the current placeholder.\033[0m"
    exit 1
  fi

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
        echo -e "\033[31mLine with identifier '"$IDENTIFIER"' does not exist in section '"$SECTION"'.\033[0m"
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
     echo -e "\033[32mErased '"$IDENTIFIER"' from '"$SECTION"'. Removed section '"$SECTION"' for it is empty now.\033[0m"
  else
     echo -e "\033[32mErased '"$IDENTIFIER"' from '"$SECTION"'\033[0m"
  fi
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
    echo -e "\033[31mTarget with identifier '"$TARGET_IDENTIFIER"' does not exist.\033[0m"
    exit 1
  fi

  if [ -z "$SECTION" ]; then
    if ! jq -e --arg target "$TARGET_IDENTIFIER" '.targets[$target].sections // empty' "$CONFIG_FILE" >/dev/null || [ "$(jq -r --arg target "$TARGET_IDENTIFIER" '.targets[$target].sections | length' "$CONFIG_FILE")" -eq 0 ]; then
      echo -e "\033[31mNo sections advailable.\033[0m"
      exit 1
    fi

    echo -e "\033[32mAvailable sections:"
    echo -e "$(jq -r --arg target "$TARGET_IDENTIFIER" '.targets[$target].sections | to_entries[] | "- \(.key)"' "$CONFIG_FILE")\033[0m"

  else
    if ! jq -e --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '.targets[$target].sections[$section] // empty' "$CONFIG_FILE" >/dev/null || [ "$(jq -r --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '.targets[$target].sections[$section] | length' "$CONFIG_FILE")" -eq 0 ]; then
      echo -e "\033[31mSection '"$SECTION"' does not exist.\033[0m"
      exit 1
    fi
    if jq -e --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" ' [.targets[$target].sections[$section] | to_entries[] | select(.key != "PLACEHOLDER")]  | length == 0' "$CONFIG_FILE" >/dev/null; then
      echo -e "\033[31mNo written lines\033[0m"
    else
      echo -e "\033[32mWritten lines:"
    fi

    jq -r --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" ' .targets[$target].sections[$section] | to_entries[] | select(.key != "PLACEHOLDER") | "- \(.key) (\"\(.value)\")"' "$CONFIG_FILE"

    echo -e "\033[0m-----------------"
    echo -e "\033[32mPlaceholder text: \""$(jq -r --arg target "$TARGET_IDENTIFIER" --arg section "$SECTION" '.targets[$target].sections[$section].PLACEHOLDER // empty' "$CONFIG_FILE")\""\033[0m"
  fi
}


"$SCRIPT_DIR"/gru-precondition.sh
if [ $? -ne 0 ]; then
  echo -e "\033[31mProcodition check failed! Unable to run script.\033[0m"
  exit 1
fi

case "$1" in
  "write")
    write "$2" "$3" "$4" "$5" "false"
    ;;
  "erase")
    erase "$2" "$3" "$4"
    ;;
  "set-placeholder")
    write "$2" "PLACEHOLDER" "$3" "$4" "true"
    ;;
  "read")
    read "$2" "$3" "$4"
    ;;
  "read-section")
    read --section "$2" "$3"
    ;;
  *)
    echo "Usage: $0 write <TEXT> <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]"
    echo "       $0 erase <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]"
    echo "       $0 set-placeholder <PLACEHOLDER> <SECTION> [<TARGET_IDENTIFIER>]"
    echo "       $0 read [--section|-s <SECTION>] [<TARGET_IDENTIFIER>]"
    echo "       $0 read-section <SECTION> [<TARGET_IDENTIFIER>]"
    exit 1
  ;;
esac
