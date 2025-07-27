#!/usr/bin/env bash
set -e

INSTALL_PATH="${1:-$HOME/git-readme-updater}"

echo "Installing to: $INSTALL_PATH"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

ZIP_URL="https://github.com/RedStoneMango/git-readme-updater/archive/refs/heads/main.zip"
echo "Downloading $ZIP_URL"
curl -sL "$ZIP_URL" -o "$TMP_DIR/repo.zip"

unzip -q "$TMP_DIR/repo.zip" -d "$TMP_DIR"
SRC_DIR="$TMP_DIR/${GITHUB_REPO}-${GITHUB_BRANCH}"

mkdir -p "$INSTALL_PATH"
cp -R "$SRC_DIR/"* "$INSTALL_PATH"
cp -R "$SRC_DIR/".[^.]* "$INSTALL_PATH" 2>/dev/null || true  # hidden files

echo "Downloaded to: $INSTALL_PATH"


echo "Setting up symlinks..."
if [ -d "$INSTALL_PATH" ]; then
  for file in "$INSTALL_PATH"/*.sh; do
    if [ -f "$file" ]; then
      link_name="/usr/local/bin/$(basename "$file")"
      if [ ! -L "$link_name" ]; then
        echo "Creating symlink: $link_name"
        sudo ln -s "$file" "$link_name"
      else
        echo "Symlink already exists: $link_name"
      fi
      echo "Setting executable permission for $file"
      sudo chmod +x "$file"
    fi
  done
fi
echo "Symlinks set up."


echo "Running precondition script..."
"$INSTALL_PATH/gru-precondition.sh"
echo "Precondition check complete."

echo "Installation complete! You can now use the 'gru' commands."
echo "For help, run: gru-help.sh"
echo "To update, run: gru-update.sh"
