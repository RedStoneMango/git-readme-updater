#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/git-readme-updater_config.json"

./gru-precondition.sh
if [ $? -ne 0 ]; then
  echo -e "\033[31mProcodition check failed! Unable to run script.\033[0m"
  exit 1
fi

if ! jq -e '.currentTarget // empty' "$CONFIG_FILE" >/dev/null; then
  echo -e "\033[31mNo target.\033[0m"
  exit 1
fi

case "$1" in
  "add" | "write")
    echo "Usage: $0 <Target Repository>"
    exit 1
    ;;
  *)
    echo "Usage: $0 add|write <NAME> <LITERAL>"
    echo "       $0 list|read"
    echo "       $0 remove|erase <NAME>"
    echo "       $0 update|rewrite <NAME> <LITERAL>"
    exit 1
    ;;
esac
