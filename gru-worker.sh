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
    REPO_BRANCH="$(jq -r ".targets[\"$TARGET_IDENTIFIER\"].branch" "$CONFIG_FILE")"
    REPO_FILE=$(jq -r ".targets[\"$TARGET_IDENTIFIER\"].file" "$CONFIG_FILE")

    START_DIR="$(pwd)"

    echo -e "\033[32mVerifying repository '"$REPO"'...\033[0m"
    if ! git ls-remote "$REPO" &>/dev/null; then
        echo -e "\033[31mRepository '"$REPO"' could not be verified. Make sure you entered a valid git@, ssh://git@, or https:// URL.\033[0m"
        exit 1
    fi
    echo -e "\033[32mVerifying branch '"$REPO_BRANCH"'...\033[0m"
    if ! git ls-remote --heads "$REPO" "$REPO_BRANCH" | grep -q "refs/heads/$REPO_BRANCH"; then
        echo -e "\033[31mBranch '$REPO_BRANCH' could not be verified in '$REPO'. Make sure you enter an existing branch's name.\033[0m"
        exit 1
    fi

    cd "$TMP_REPO_DIR"
    
    echo -e "\033[32mCloning repository '"$REPO"' from branch '"$REPO_BRANCH"'! Out: '"$TMP_REPO_DIR"'...\033[0m"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO" || {
        echo -e "\033[31mFailed to clone brach '"$REPO_BRANCH"' in repository '"$REPO"' with a depth of 1.\033[0m"
        exit 1
    }

    FOLDER="$(find . -maxdepth 1 -type d ! -name '.' | sort | head -n 1)"
    cd "$FOLDER" || {
        echo -e "\033[31mFailed to change directory to newly created folder '"$FOLDER"'.\033[0m"
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
        echo -e "\033[31mFailed to push changes to remote repository '"$REPO"' on branch '"$REPO_BRANCH"'.\033[0m"
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

"$SCRIPT_DIR"/gru-precondition.sh
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
