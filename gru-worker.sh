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
        reduce (
            sections | to_entries[]
        ) as $section (
            tmpl;
            gsub("\\{@"+$section.key+"\\}"; (
            # Extract entries excluding PLACEHOLDER
            ($section.value | to_entries | map(select(.key != "PLACEHOLDER"))) as $entries
            |
            if ($entries | length) > 0 then
                # If there are non-PLACEHOLDER entries, join their values
                ($entries | map(.value) | join("\n"))
            elif ($section.value | has("PLACEHOLDER")) then
                # Otherwise, if PLACEHOLDER exists, use its value
                $section.value["PLACEHOLDER"]
            else
                # Fallback: empty string
                ""
            end
            ))
        );

    .targets[$target].sections as $sections
    | replace_all_placeholders($template; $sections)
    ' "$CONFIG_FILE")

    echo "$TEMPLATE" > "$OUTPUT_PATH"

    echo -e "\033[32mBuild output saved to '"$OUTPUT_PATH"'.\033[0m"
}

remoteUpdate() {
    BUILT_FILE_PATH=$(readlink -f "$1")
    COMMIT_MESSAGE=""
    TARGET_IDENTIFIER=""

    if [ "$2" = "--message" ] || [ "$2" = "-m" ]; then
        COMMIT_MESSAGE="$3"
        TARGET_IDENTIFIER="$4"
    else
        TARGET_IDENTIFIER="$2"
    fi

    if [ -z "$BUILT_FILE_PATH" ]; then
        echo -e "\033[31mPath to built file is required.\033[0m"
        exit 1
    fi

    if [ ! -f "$BUILT_FILE_PATH" ]; then
        echo -e "\033[31mFile '"$BUILT_FILE_PATH"' does not exist.\033[0m"
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

    if ! jq -e ".targets[\"$TARGET_IDENTIFIER\"].repo" "$CONFIG_FILE" >/dev/null || ! jq -e ".targets[\"$TARGET_IDENTIFIER\"].file" "$CONFIG_FILE" >/dev/null; then
        echo -e "\033[31mTarget with '"$TARGET_IDENTIFIER"' is not linked to a remote repository + file.\033[0m"
        exit 1
    fi


    TMP_REPO_DIR="$SCRIPT_DIR/remote_update_temp/"
    if [ -d "$TMP_REPO_DIR" ]; then
      echo -e "\033[33mTemporary repository directory already exists! This may be due to a previous failed execution. Removing directory recursively to clean up older data...\033[0m"
      rm -rf "$TMP_REPO_DIR" || {
        echo -e "\033[31mFailed to remove existing temporary repository directory '$TMP_REPO_DIR'.\033[0m"
        exit 1
      }
    fi
    mkdir -p "$TMP_REPO_DIR"

    REPO=$(jq -r ".targets[\"$TARGET_IDENTIFIER\"].repo" "$CONFIG_FILE")
    if [[ ! "$REPO" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+:[a-zA-Z0-9_.-]+$ ]]; then
      echo -e "\033[31;1m[Critical]: Remote repository format is incorrect. Expected format: 'owner/repo:branch'.\033[0m"
      exit 1
    fi
    REPO_PATH="${REPO%%:*}"
    GITHUB_URL="https://github.com/"${REPO_PATH}".git"
    REPO_BRANCH="${REPO#*:}"
    START_DIR="$(pwd)"
    REPO_NAME="${REPO_PATH##*/}"
    REPO_FILE=$(jq -r ".targets[\"$TARGET_IDENTIFIER\"].file" "$CONFIG_FILE")

    cd "$TMP_REPO_DIR"
    
    echo -e "\033[32mCloning repository '"$REPO_NAME"' from branch '"$REPO_BRANCH"'! In: '"$GITHUB_URL"' Out: '"$TMP_REPO_DIR"'...\033[0m"
    git clone --depth 1 --branch "$REPO_BRANCH" "$GITHUB_URL" || {
        echo -e "\033[31mFailed to clone brach '"$REPO_BRANCH"' in repository '"$GITHUB_URL"' with a depth of 1.\033[0m"
        exit 1
    }

    cd "$REPO_NAME" || {
        echo -e "\033[31mFailed to change directory to cloned repository '"$REPO_NAME"'.\033[0m"
        exit 1
    }

    echo -e "\033[32mUpdating file '"$REPO_FILE"' by replacing it with '"$BUILT_FILE_PATH"'...\033[0m"
    cp "$BUILT_FILE_PATH" "$REPO_FILE" || {
        echo -e "\033[31mFailed to copy file '"$BUILT_FILE_PATH"' to '"$REPO_FILE"'.\033[0m"
        exit 1
    }

    echo -e "\033[32mStaging changes...\033[0m"
    git add . || {
        echo -e "\033[31mFailed to stage changes in file '"$(pwd)"'.\033[0m"
        exit 1
    }

    if [ -z "$COMMIT_MESSAGE" ]; then
        COMMIT_MESSAGE="Dynamic update of '"$REPO_FILE"'"
    fi
    echo -e "\033[32mCommitting changes with message: '"$COMMIT_MESSAGE"'...\033[0m"
    git commit -m "$COMMIT_MESSAGE" || {
        echo -e "\033[31mFailed to commit changes with message '"$COMMIT_MESSAGE"'.\033[0m"
        exit 1
    }
    
    echo -e "\033[32mPushing changes to remote repository...\033[0m"
    git push origin "$REPO_BRANCH" || {
        echo -e "\033[31mFailed to push changes to remote repository '"$GITHUB_URL"' on branch '"$REPO_BRANCH"'.\033[0m"
        exit 1
    }
    cd "$START_DIR"

    echo -e "\033[32mRemote update successful!\033[0m"

    echo -e "\033[32mCleaning up temporary repository directory...\033[0m"
    rm -rf "$TMP_REPO_DIR" || {
        echo -e "\033[31mFailed to remove temporary repository directory '$TMP_REPO_DIR'.\033[0m"
        exit 1
    }
    echo -e "\033[32;1mSuccessfully completed remote update with 0 errors!\033[0m"
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
  "remote-update")
    remoteUpdate "$2" "$3" "$4" "$5"
    ;;
  *)
    echo "Usage: $0 build <TEMPLATE_PATH> <OUTPUT_PATH> [<TARGET_IDENTIFIER>]"
    echo "       $0 remote-update <BUILT_FILE_PATH> [--message|-m <COMMIT_MESSAGE>] [<TARGET_IDENTIFIER>]"
    exit 1
  ;;
esac
