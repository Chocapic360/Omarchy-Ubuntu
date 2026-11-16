# CLAUDE.md

Omarchy 3.8's Hyprland setup ported to Ubuntu 26.04 as a second GDM session next to GNOME.
README.md is the user-facing doc; this file is for working on the repo.

## How it's wired

- `install.sh` symlinks `config/*` into `~/.config` and `bin/*` into `~/.local/bin`, so edits in
  the repo are live immediately. Hyprland reloads by itself; Waybar needs `omu-restart-waybar`.
- `session/omu-session` and `session/omarchy-ubuntu.desktop` are **copied** (not linked) into
  `/usr/local/bin` and `/usr/share/wayland-sessions` with sudo. After changing them, reinstall:
  `sudo install -m755 session/omu-session /usr/local/bin/omu-session` (or rerun `install.sh`).
- Theme colours come from `~/.config/omarchy-ubuntu/current/theme` -> `themes/<name>/`.
- `config/hypr/hyprland.conf` sources the split files (`envs`, `monitors`, `input`, `looknfeel`,
  `windows`, `autostart`, `bindings/*`). `local.conf` is the user's untracked override file.
- Keybindings use `bindd` with a description: the keybindings viewer (Super + K) reads it.
- Hyprland is Ubuntu's 0.53: use its `windowrule = <effect>, match:<prop> <regex>` syntax and
  don't use anything that needs a newer Hyprland (Omarchy 4's Lua config / Quickshell).

## Rules

- **Leave GNOME alone.** Nothing may change how the GNOME session looks or behaves. Don't write
  gsettings/dconf, don't add autostart entries or user units that GNOME would also run (see
  `keep_autostart_out_of_gnome` / `keep_user_units_out_of_gnome` in `install.sh`).
- **Everything `install.sh` does, `uninstall.sh` undoes.** Record what was changed in a state
  file under `~/.config/omarchy-ubuntu/` (e.g. `masked-units`, `font-installed`) so the
  uninstaller only reverts what the installer did, not what the user already had.
- Scripts are bash, named `omu-*`, with a one-line comment at the top saying what they do.
  Check them with `bash -n`; check Hyprland config with `hyprctl configerrors` or
  `Hyprland --verify-config -c ~/.config/hypr/hyprland.conf`.

## Gotchas (learned the hard way)

- **Never set `GTK_THEME`**, not even to an empty value. libadwaita apps (Nautilus) then lose
  their styling: transparent window, flat header bar. GTK apps follow the GNOME
  theme/accent settings instead.
- The user has **lingering on**, so the systemd user manager, D-Bus session bus and their
  environment survive logouts. GDM copies the systemd user environment into the next login, so
  anything left there leaks into later sessions (GNOME too). `omu-session` cleans up on exit;
  `dbus-update-activation-environment` can't unset a variable, only blank it.
- Desktop portals started in one Hyprland session go stale after logout and make the next
  session's apps hang (Waybar never draws its bar). `omu-session` stops them on exit.
- Backlight writes (brightness keys, SwayOSD) need the user in the `video` group (Ubuntu's udev rules).
- `policykit-1-gnome`'s agent segfaults when it shows its dialog under Hyprland. Prefer
  `hyprpolkitagent` (`/usr/libexec/hyprpolkitagent`).
- `!`-prefixed commands in Claude Code can't prompt for a sudo password. Ask the user to run
  sudo commands in a real terminal.

## Git

- Commit and push straight to `main`, even if a feature branch is checked out. Commit only
  the files you changed: the user often has unrelated uncommitted edits.
- Commit messages: a short imperative subject, then a body explaining why.
