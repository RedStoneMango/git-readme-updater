#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

build() {
    TEMPLATE_PATH="$1"
    OUTPUT_PATH="$2"
    TARGET_IDENTIFIER="$3"
    
    if [ -z "$TEMPLATE_PATH" ] || [ -z "$OUTPUT_PATH" ]; then
        echo -e "\033[31mTemplate path and output path are required.\033[0m"
        exit 1
    fi
    
    if [ ! -f "$TEMPLATE_PATH" ]; then
        echo -e "\033[31mTemplate file '"$TEMPLATE_PATH"' does not exist.\033[0m"
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

    if [ ! -d "$(dirname "$OUTPUT_PATH")" ]; then
        echo -e "\033[33mOutput directory does not exist. Creating it...\033[0m"
        mkdir -p "$(dirname "$OUTPUT_PATH")"
    fi

    TEMPLATE=$(jq -r --arg target "$TARGET_IDENTIFIER" --arg template "$(cat "$TEMPLATE_PATH")" '
    def replace_all_placeholders(tmpl; sections):
        reduce (sections | to_entries[]) as $entry (
        tmpl;
        gsub("\\{@"+$entry.key+"\\}"; ($entry.value | to_entries | map(.value) | join("\n")))
        );

    .targets[$target].sections as $sections
    | replace_all_placeholders($template; $sections)
    ' "$CONFIG_FILE")

    echo "$TEMPLATE" > "$OUTPUT_PATH"

    echo -e "\033[32mBuild output saved to '"$OUTPUT_PATH"'.\033[0m"
}

./gru-precondition.sh
if [ $? -ne 0 ]; then
  echo -e "\033[31mProcodition check failed! Unable to run script.\033[0m"
  exit 1
fi

case "$1" in
  "build")
    build "$2" "$3" "$4"
    ;;
  "remoteUpdate")
    echo -e "\033[31mThis functionality is not implemented yet.\033[0m"
    ;;
  *)
    echo "Usage: $0 build <TEMPLATE_PATH> <OUTPUT_PATH> [<TARGET_IDENTIFIER>]"
    echo "       $0 remoteUpdate <BUILT_FILE_PATH> [--message|-m <COMMIT_MESSAGE>] [<TARGET_IDENTIFIER>]"
    exit 1
  ;;
esac
