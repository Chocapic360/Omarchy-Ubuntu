#!/bin/bash
# omarchy-ubuntu uninstaller: undoes what install.sh changed and removes the login-screen
# entry. Your GNOME setup is left as it was.
#
#   ./uninstall.sh             remove links and the session entry, restore backups and your
#                              default apps. Packages stay installed, so the measures that
#                              keep them out of GNOME stay too.
#   ./uninstall.sh --packages  also purge every package install.sh added (dependencies
#                              included, nothing else), then remove those measures and the
#                              rest of the saved state: back to how it was before install.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.config/omarchy-ubuntu"
STAMP="$(date +%Y%m%d-%H%M%S)"
PURGE=false
[[ ${1:-} == "--packages" ]] && PURGE=true

bold() { printf '\033[1;35m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

if [[ $EUID -eq 0 ]]; then
  die "Run as your normal user (the script uses sudo when it needs to)."
fi

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

# 1. Packages first: if apt is cancelled, nothing else has changed yet
if $PURGE && [[ -s $STATE_DIR/installed-packages ]]; then
  bold "==> Purging the packages install.sh added (needs sudo)"
  mapfile -t still < <(
    comm -12 <(grep -v '^$' "$STATE_DIR/installed-packages" | sort -u) \
      <(dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' | awk '$1 == "ii" {print $2}' | sort)
  )
  if ((${#still[@]})); then
    note "apt lists everything it will remove and asks before doing it."
    note "If it wants to remove more than these ${#still[@]} packages, something you installed"
    note "later depends on them: answer n and remove that from the list by hand."
    sudo apt-get purge "${still[@]}" || die "apt didn't purge anything, so nothing else was changed."
  fi
  rm -f "$STATE_DIR/installed-packages"
fi

bold "==> Removing config links from ~/.config"
for dir in "$REPO"/config/*/; do
  unlink_and_restore "$HOME/.config/$(basename "${dir%/}")"
done

bold "==> Removing scripts from ~/.local/bin"
for script in "$REPO"/bin/*; do
  unlink_and_restore "$HOME/.local/bin/$(basename "$script")"
done

# 2. Autostart overrides: only drop an override once the package's autostart file is gone.
#    (apt remove keeps it as a config file; apt purge deletes it.)
bold "==> Autostart overrides added by install.sh"
if [[ -f $STATE_DIR/autostart-overrides ]]; then
  kept=()
  while read -r file; do
    [[ -n $file && -f $file ]] && grep -q 'hidden by omarchy-ubuntu' "$file" || continue
    if [[ -e /etc/xdg/autostart/$(basename "$file") ]]; then
      kept+=("$file")
      note "kept $file (its package is still installed)"
    else
      rm "$file" && note "removed $file"
    fi
  done <"$STATE_DIR/autostart-overrides"
  if ((${#kept[@]})); then
    printf '%s\n' "${kept[@]}" >"$STATE_DIR/autostart-overrides"
  else
    rm -f "$STATE_DIR/autostart-overrides"
  fi
fi

# 3. Masked user services: same rule, unmask only once the package is gone
bold "==> User services masked by install.sh"
if [[ -f $STATE_DIR/masked-units ]]; then
  kept=()
  while read -r unit; do
    [[ -n $unit && $(readlink "$HOME/.config/systemd/user/$unit" 2>/dev/null) == /dev/null ]] || continue
    if [[ -e /usr/lib/systemd/user/$unit ]]; then
      kept+=("$unit")
      note "kept $unit masked (its package is still installed)"
    else
      systemctl --user unmask "$unit" >/dev/null 2>&1 && note "unmasked $unit"
    fi
  done <"$STATE_DIR/masked-units"
  if ((${#kept[@]})); then
    printf '%s\n' "${kept[@]}" >"$STATE_DIR/masked-units"
  else
    rm -f "$STATE_DIR/masked-units"
  fi
fi

# 4. Default apps: put back the mimeapps.list from before install.sh
bold "==> Default apps"
list="$HOME/.config/mimeapps.list"
if [[ -f $STATE_DIR/mimeapps.list.orig ]]; then
  if ! cmp -s "$STATE_DIR/mimeapps.list.orig" "$list"; then
    [[ -e $list ]] && mv "$list" "$list.bak-uninstall-$STAMP" && note "saved the current one as $(basename "$list").bak-uninstall-$STAMP"
    cp -p "$STATE_DIR/mimeapps.list.orig" "$list"
    note "restored $list"
  else
    note "unchanged"
  fi
  rm "$STATE_DIR/mimeapps.list.orig"
elif [[ -f $STATE_DIR/mimeapps.list.none ]]; then
  if [[ -e $list ]]; then
    mv "$list" "$list.bak-uninstall-$STAMP"
    note "there was no $list before install.sh: moved it to $(basename "$list").bak-uninstall-$STAMP"
  fi
  rm "$STATE_DIR/mimeapps.list.none"
fi

bold "==> Removing the login-screen session (needs sudo)"
sudo rm -f /usr/share/wayland-sessions/omarchy-ubuntu.desktop /usr/local/bin/omu-session

rm -rf "$STATE_DIR/current"

if $PURGE; then
  if [[ -f $STATE_DIR/font-installed ]]; then
    font_dir=$(cat "$STATE_DIR/font-installed")
    if [[ $font_dir == "$HOME"/.local/share/fonts/* && -d $font_dir ]]; then
      rm -rf "$font_dir" && fc-cache -f >/dev/null && note "removed the Nerd Font install.sh added"
    fi
    rm -f "$STATE_DIR/font-installed"
  fi
  # Nothing left that's still needed: drop the state folder (defaults, lists)
  if [[ ! -s $STATE_DIR/autostart-overrides && ! -s $STATE_DIR/masked-units ]]; then
    rm -rf "$STATE_DIR"
  fi
  bold "==> Done. Log out and pick \"Ubuntu\" on the login screen."
else
  bold "==> Done. Log out and pick \"Ubuntu\" on the login screen."
  note "Packages are still installed, so they're still kept out of GNOME."
  note "To remove them too and finish the cleanup: ./uninstall.sh --packages"
fi
