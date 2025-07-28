#!/usr/bin/env bash

SCRIPT_FILE_AMOUNT=10

set -e

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


if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[1;31m[ERROR]: This script must be run as root. Please run with sudo or as root user.\033[0m"
  exit 1
fi

INSTALL_PATH="${1:-$(resolve_dir)}"
INSTALL_PATH="$(cd "$INSTALL_PATH" >/dev/null 2>&1 && pwd)"

if [ -z "$INSTALL_PATH" ] || [ "$INSTALL_PATH" = "/" ]; then
  echo -e "\033[1;31m[ERROR]: INSTALL_PATH resolved to an unsafe location ('$INSTALL_PATH'). Aborting.\033[0m"
  exit 1
fi

echo -e "This will uninstall git-readme-updater (gru) from: \033[1m$INSTALL_PATH\033[0m"
echo "All corresponding symlinks will be deleted and the whole installation directory is going to be removed."
read -r -p "Are you sure you want to continue? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Uninstallation canceled by user."
  exit 1
fi

IFS='/' read -ra path_parts <<< "$INSTALL_PATH"
depth="${#path_parts[@]}"

if [ "$depth" -lt 4 ]; then  # <4 because leading / gives empty first element
  echo -e "\033[1;33m[WARNING]: The path '$INSTALL_PATH' is only $((depth - 1)) levels deep.\033[0m"
  echo "Please verify it's correctness to avoid the accidental deletion of system files."
  read -r -p "Continue deleting \033[1m'$INSTALL_PATH'\033[0m? [y/N]: " shallow_confirm
  if [[ ! "$shallow_confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstallation aborted by user due to shallow path."
    exit 1
  fi
fi

if [ -d "$INSTALL_PATH" ]; then
  total_files=$(find "$INSTALL_PATH" -type f 2>/dev/null | wc -l)
else
  total_files=0
fi

# Add fallback value "5"
SCRIPT_FILE_AMOUNT=${SCRIPT_FILE_AMOUNT:-5}

if [ "$total_files" -gt $((SCRIPT_FILE_AMOUNT + 5)) ]; then
  echo -e "\033[1;33m[WARNING]: The installation directory contains $total_files files, which is significantly more than the expected amount of $SCRIPT_FILE_AMOUNT files.\033[0m"
  echo "This might indicate an incorrectly defined path that may also be deleted."
  read -r -p "Are you sure you want to continue with uninstall? [y/N]: " file_amount_confirm
  if [[ ! "$file_amount_confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstallation aborted by user due to unexpected file count."
    exit 1
  fi
fi


if [ ! -w /usr/local/bin ]; then
  echo -e "\033[1;33m[WARNING]: You do not have write permissions to /usr/local/bin. Please run this script with sudo or as root.\033[0m"
  exit 1
fi

# Remove symlinks if they point to the correct source
if [ -d "$INSTALL_PATH" ]; then
  for file in "$INSTALL_PATH"/*.sh; do
    # skip if no matching files
    [ -e "$file" ] || continue

    if [ -f "$file" ]; then
      script_name="$(basename "$file" .sh)"
      link_name="/usr/local/bin/$script_name"
      if [ -L "$link_name" ]; then
        resolved_link="$(readlink -f "$link_name" || true)"
        resolved_file="$(readlink -f "$file" || true)"
        if [ "$resolved_link" == "$resolved_file" ]; then
          echo "Removing symlink: $link_name"
          rm "$link_name"
        else
          echo -e "\033[33mWarning: Symlink $link_name does not point to $file. Skipping.\033[0m"
        fi
      fi
    fi
  done
fi


if [ -d "$INSTALL_PATH" ]; then
  echo "Removing installation directory: $INSTALL_PATH"
  rm -rf "$INSTALL_PATH"
else
  echo -e "\033[31mInstallation directory not found: $INSTALL_PATH\033[0m"
fi

echo "-------------------------------------------------------"
echo -e "\033[1;32mUninstallation complete! All valid symlinks and the installation directory have been removed.\033[0m"
