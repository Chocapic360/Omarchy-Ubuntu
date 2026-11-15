#!/bin/bash
# omarchy-ubuntu uninstaller: undoes everything install.sh changed in your home folder
# and removes the login-screen entry. Your GNOME setup is left as it was.
#
#   ./uninstall.sh             remove links, restore backups, remove the session entry
#   ./uninstall.sh --packages  also print the apt command to remove the packages it added

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.config/omarchy-ubuntu"

bold() { printf '\033[1;35m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }

# Remove a symlink that points into this repo, then put back the newest backup (if any)
unlink_and_restore() {
  local dst="$1" target backup
  [[ -L $dst ]] || return 0
  target=$(readlink "$dst")
  [[ $target == "$REPO"/* ]] || return 0
  rm "$dst"
  note "removed $dst"
  backup=$(ls -1d "$dst".bak-* 2>/dev/null | sort | tail -1 || true)
  if [[ -n $backup ]]; then
    mv "$backup" "$dst"
    note "restored $dst from $(basename "$backup")"
  fi
}

bold "==> Removing config links from ~/.config"
for dir in "$REPO"/config/*/; do
  unlink_and_restore "$HOME/.config/$(basename "${dir%/}")"
done

bold "==> Removing scripts from ~/.local/bin"
for script in "$REPO"/bin/*; do
  unlink_and_restore "$HOME/.local/bin/$(basename "$script")"
done

bold "==> Removing autostart overrides added by install.sh"
if [[ -f $STATE_DIR/autostart-overrides ]]; then
  while read -r file; do
    [[ -n $file && -f $file ]] && grep -q 'hidden by omarchy-ubuntu' "$file" && rm "$file" && note "removed $file"
  done <"$STATE_DIR/autostart-overrides"
fi

bold "==> Removing the login-screen session (needs sudo)"
sudo rm -f /usr/share/wayland-sessions/omarchy-ubuntu.desktop /usr/local/bin/omu-session

if [[ ${1:-} == "--packages" && -s $STATE_DIR/installed-packages ]]; then
  bold "==> Packages install.sh added (not removed automatically)"
  echo "  sudo apt remove $(grep -v '^$' "$STATE_DIR/installed-packages" | tr '\n' ' ')"
fi

rm -rf "$STATE_DIR/current"
bold "==> Done. Log out and pick \"Ubuntu\" on the login screen."
note "Kept: $STATE_DIR (your default-app choices and the package list) and the Nerd Font."
