#!/bin/bash
# omarchy-ubuntu installer
# Installs packages, the JetBrainsMono Nerd Font and a GDM session entry,
# then symlinks configs and scripts from this repo. Safe to run again.
#
#   ./install.sh               full install
#   ./install.sh --links-only  only refresh symlinks (used by "Update > This setup")

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
THEME="purple-catppuccin"
STATE_DIR="$HOME/.config/omarchy-ubuntu"
LINKS_ONLY=false
[[ ${1:-} == "--links-only" ]] && LINKS_ONLY=true

bold() { printf '\033[1;35m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

if ! $LINKS_ONLY && [[ $EUID -eq 0 ]]; then
  die "Run as your normal user (the script uses sudo when it needs to)."
fi

# Packages that must exist for the setup to work
REQUIRED=(
  hyprland hyprlock hypridle
  waybar fuzzel mako-notifier swaybg
  grim slurp wl-clipboard cliphist
  brightnessctl playerctl pamixer pavucontrol wireplumber
  jq gawk libxkbcommon-tools libnotify-bin upower xdg-utils xdg-user-dirs
  alacritty btop blueman network-manager network-manager-gnome power-profiles-daemon
  yaru-theme-gtk yaru-theme-icon
  xdg-desktop-portal-gtk
  curl xz-utils fontconfig
)

# Nice to have: installed when Ubuntu has them, skipped otherwise
OPTIONAL=(
  xdg-desktop-portal-hyprland
  swayosd
  hyprpicker
  hyprsunset
  satty
  fonts-noto-color-emoji
)

# Only one graphical polkit agent is needed; take the first one available
POLKIT_AGENTS=(polkit-gnome policykit-1-gnome mate-polkit lxpolkit)

# Hyprland's helper dialogs (hyprland-dialog, update/ANR popups). Ubuntu 26.04 still
# ships them under the older name hyprland-qtutils; take whichever exists
GUIUTILS=(hyprland-guiutils hyprland-qtutils)

available() { [[ -n $(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" {print $2}') ]]; }

install_packages() {
  bold "==> Enabling the universe repository"
  sudo add-apt-repository -y universe >/dev/null
  sudo apt-get update -qq

  local missing=() to_install=() pkg
  for pkg in "${REQUIRED[@]}"; do
    if available "$pkg"; then
      to_install+=("$pkg")
    else
      missing+=("$pkg")
    fi
  done
  for pkg in hyprland waybar fuzzel; do
    available "$pkg" || die "$pkg isn't available in apt. This setup needs Ubuntu 26.04 with universe enabled."
  done
  ((${#missing[@]})) && warn "Not in apt, so some features won't work until installed another way: ${missing[*]}"

  for pkg in "${OPTIONAL[@]}"; do
    if available "$pkg"; then
      to_install+=("$pkg")
    else
      warn "Skipping optional package (not in apt): $pkg"
    fi
  done

  for pkg in "${POLKIT_AGENTS[@]}"; do
    if available "$pkg"; then
      to_install+=("$pkg")
      break
    fi
  done

  local found=false
  for pkg in "${GUIUTILS[@]}"; do
    if available "$pkg"; then
      to_install+=("$pkg")
      found=true
      break
    fi
  done
  $found || warn "Not in apt: ${GUIUTILS[*]} (Hyprland's popup dialogs won't show)"

  # Remember which packages this run adds, so their login-autostart entries
  # can be kept out of GNOME and uninstall.sh can list them
  NEW_PACKAGES=()
  for pkg in "${to_install[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || NEW_PACKAGES+=("$pkg")
  done

  bold "==> Installing ${#to_install[@]} packages"
  sudo apt-get install -y "${to_install[@]}"

  mkdir -p "$STATE_DIR"
  printf '%s\n' "${NEW_PACKAGES[@]}" >>"$STATE_DIR/installed-packages"
  sort -u -o "$STATE_DIR/installed-packages" "$STATE_DIR/installed-packages"
}

# Some new packages (blueman, polkit agents, ...) drop a file in /etc/xdg/autostart,
# which GNOME would start at login. Hyprland ignores those files (it uses autostart.conf),
# so hide each one with a per-user override. GNOME then behaves exactly as before.
keep_autostart_out_of_gnome() {
  [[ -f $STATE_DIR/installed-packages ]] || return 0
  local pkg file name override
  while read -r pkg; do
    [[ -z $pkg ]] && continue
    dpkg -L "$pkg" 2>/dev/null | grep -E '^/etc/xdg/autostart/.+\.desktop$' || true
  done <"$STATE_DIR/installed-packages" | sort -u | while read -r file; do
    [[ -f $file ]] || continue
    # Already excluded from GNOME by the package itself?
    if grep -qE '^NotShowIn=.*GNOME' "$file" ||
      { grep -q '^OnlyShowIn=' "$file" && ! grep -qE '^OnlyShowIn=.*GNOME' "$file"; }; then
      continue
    fi
    name=$(basename "$file")
    override="$HOME/.config/autostart/$name"
    [[ -e $override ]] && continue
    mkdir -p "$HOME/.config/autostart"
    printf '[Desktop Entry]\nType=Application\nName=%s (hidden by omarchy-ubuntu)\nHidden=true\n' "$name" >"$override"
    echo "$override" >>"$STATE_DIR/autostart-overrides"
    warn "Kept $name from starting in GNOME"
  done
}

# waybar, mako and hypridle ship systemd user services that their packages enable for
# graphical-session.target. GNOME reaches that target, so they'd start inside GNOME.
# Hyprland starts them itself from autostart.conf, so mask the services for this user.
USER_UNITS=(waybar.service mako.service hypridle.service)
keep_user_units_out_of_gnome() {
  local unit
  for unit in "${USER_UNITS[@]}"; do
    if [[ $(readlink "$HOME/.config/systemd/user/$unit" 2>/dev/null) != /dev/null ]]; then
      systemctl --user mask "$unit" >/dev/null 2>&1 && warn "Kept $unit from starting in GNOME"
    fi
  done
}

install_font() {
  if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    bold "==> JetBrainsMono Nerd Font already installed"
    return
  fi
  bold "==> Installing JetBrainsMono Nerd Font"
  local dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
  mkdir -p "$dir"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" |
    tar -xJ -C "$dir"
  fc-cache -f >/dev/null
}

install_session() {
  bold "==> Adding \"Hyprland (Omarchy Ubuntu)\" to the login screen"
  sudo install -m 755 "$REPO/session/omu-session" /usr/local/bin/omu-session
  sudo install -m 644 "$REPO/session/omarchy-ubuntu.desktop" /usr/share/wayland-sessions/omarchy-ubuntu.desktop
}

# Symlink $1 -> $2, moving anything already at $2 to a timestamped backup
link() {
  local src="$1" dst="$2"
  if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then
    return
  fi
  if [[ -e $dst || -L $dst ]]; then
    mv "$dst" "$dst.bak-$STAMP"
    warn "Backed up $dst -> $dst.bak-$STAMP"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
}

link_files() {
  bold "==> Linking configs into ~/.config"
  local dir
  for dir in "$REPO"/config/*/; do
    dir="${dir%/}"
    link "$dir" "$HOME/.config/$(basename "$dir")"
  done
  touch "$REPO/config/hypr/local.conf"

  # Virtual machines: hardware cursors usually show up invisible or offset
  if systemd-detect-virt --vm --quiet 2>/dev/null && ! grep -q no_hardware_cursors "$REPO/config/hypr/local.conf"; then
    bold "==> Virtual machine detected: turning off hardware cursors"
    printf '\n# Added by install.sh: running in a VM\ncursor {\n    no_hardware_cursors = true\n}\n' >>"$REPO/config/hypr/local.conf"
  fi

  bold "==> Linking scripts into ~/.local/bin"
  local script
  for script in "$REPO"/bin/*; do
    link "$script" "$HOME/.local/bin/$(basename "$script")"
  done

  bold "==> Activating the $THEME theme"
  local state="$HOME/.config/omarchy-ubuntu/current"
  mkdir -p "$state"
  ln -sfn "$REPO/themes/$THEME" "$state/theme"
  if [[ ! -e $state/background ]]; then
    ln -sfn "$REPO/themes/$THEME/backgrounds/1-ascii-hands.png" "$state/background"
    echo fit >"$state/background-mode"
  fi
}

verify_config() {
  if command -v Hyprland >/dev/null && Hyprland --help 2>&1 | grep -q -- --verify-config; then
    bold "==> Checking the Hyprland config"
    PATH="$HOME/.local/bin:$PATH" Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.conf" ||
      warn "Hyprland reported config problems (see above). Run 'hyprctl configerrors' after logging in."
  fi
}

if ! $LINKS_ONLY; then
  install_packages
  keep_autostart_out_of_gnome
  keep_user_units_out_of_gnome
  install_font
  install_session
fi
link_files
$LINKS_ONLY || verify_config

bold "==> Done"
if ! $LINKS_ONLY; then
  cat <<'EOF'

Next:
  1. Log out.
  2. On the login screen, click your name, then the gear icon (bottom right),
     and pick "Hyprland (Omarchy Ubuntu)".
  3. Log in. Super + K lists every shortcut; Super + Space opens the menu.

GNOME is untouched: pick "Ubuntu" on the login screen to go back.
To remove this setup later: ./uninstall.sh
EOF
fi
