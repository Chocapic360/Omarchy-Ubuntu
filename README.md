# omarchy-ubuntu

Omarchy's look and feel on **Ubuntu 26.04**, installed next to GNOME rather than replacing it. You get a Hyprland session with Omarchy 3.8's tiling, keybindings, top bar, control menu and keybindings viewer, themed in a purple take on Catppuccin Mocha.

Built for a Dell 16 laptop (1920×1200 @ 60 Hz), but works on any Ubuntu 26.04 machine.

## Install

```bash
git clone https://github.com/Chocapic360/omarchy-ubuntu ~/omarchy-ubuntu
cd ~/omarchy-ubuntu
./install.sh
```

Then log out. On the login screen, click your name and use the gear icon to pick **Hyprland (Omarchy Ubuntu)**. To get back to GNOME, pick **Ubuntu** there.

The installer:

- installs the packages from Ubuntu's `universe` repo (Hyprland 0.53, Waybar, fuzzel, mako, hyprlock, hypridle, …)
- installs the JetBrainsMono Nerd Font into `~/.local/share/fonts`
- adds the login-screen session (`/usr/share/wayland-sessions/omarchy-ubuntu.desktop`)
- symlinks `config/*` into `~/.config` and `bin/*` into `~/.local/bin`, backing up anything already there as `*.bak-<date>`

Run it again any time. `./install.sh --links-only` just refreshes the symlinks.

## Living next to GNOME

This adds a second session; it doesn't change your GNOME one.

- **Login screen:** GDM gets a new **Hyprland (Omarchy Ubuntu)** entry next to **Ubuntu**. GDM remembers the last session you picked, so to go back, click your name, then the gear icon, and choose **Ubuntu**.
- **Apps and settings:** only Hyprland-session tools are configured (Hyprland, Waybar, fuzzel, mako, SwayOSD, Alacritty). GNOME doesn't read any of those. If `~/.config/alacritty` already existed, it's backed up first and restored by `uninstall.sh`.
- **Theme:** the purple GTK theme is set as an environment variable inside Hyprland only. It's removed from your user session when Hyprland exits, so GNOME keeps its own look.
- **Autostart:** some packages (blueman, polkit agents) install login autostart entries. GNOME would run them, so `install.sh` hides any that a package adds and that would run in GNOME, using a per-user override in `~/.config/autostart`. Hyprland starts its own copies from `autostart.conf`.
- **Background services:** the `waybar`, `mako` and `hypridle` packages enable systemd user services that GNOME's session would start. `install.sh` masks them for your user. Hyprland starts these programs itself.
- **Not touched:** GNOME settings (`gsettings`/dconf), GNOME extensions and GDM's configuration.
- **Shared on purpose:** *Setup > Defaults* sets your default browser, text editor and file manager system-wide, so GNOME uses those choices too. `install.sh` saves your `~/.config/mimeapps.list` first and `uninstall.sh` puts it back.

To undo it:

- `./uninstall.sh` removes every link and the login entry, restores the backups and your default apps. The packages stay installed, so their autostart overrides and masked services stay too, and GNOME keeps behaving as before.
- `./uninstall.sh --packages` also purges every package `install.sh` added, dependencies included and nothing else (apt shows the list and asks first). Then it removes the overrides, the masks, the Nerd Font if `install.sh` installed it, and `~/.config/omarchy-ubuntu`.

Not undone: changes you make through the menus (Wi-Fi networks, Bluetooth pairings), screenshots, clipboard history and Hyprland's logs in `~/.cache/hyprland`.

## Shortcuts

Press **Super + K** to search every shortcut. The essentials:

| Keys | Action |
|---|---|
| Super + Space | Omarchy menu (Apps, Learn, Capture, Toggle, Style, Setup, Update, System) |
| Super + Alt + Space | App launcher |
| Super + Escape | System menu (lock, suspend, logout, restart, shutdown) |
| Super + K | Keybindings viewer |
| Super + Return | Terminal |
| Super + Shift + B | Browser |
| Super + Shift + F | Files |
| Super + Shift + N | Editor |
| Super + W | Close window |
| Super + 1…0 | Switch workspace |
| Super + Shift + 1…0 | Move window to workspace |
| Super + Arrows | Move focus |
| Super + T / F | Toggle floating / full screen |
| Super + C / V | Universal copy / paste |
| Super + Ctrl + V | Clipboard history |
| Print | Screenshot a region (copied and saved to ~/Pictures/Screenshots) |
| Super + Ctrl + L | Lock |

## Default apps

Open the menu (Super + Space) and choose **Setup > Defaults** to pick your:

- **Browser:** any installed browser, including snaps and flatpaks. It's set with `xdg-settings`, so links from other apps open there too.
- **Terminal:** Alacritty, Ghostty, Kitty, Foot, WezTerm, Ptyxis or GNOME Terminal, whichever are installed.
- **Editor:** Zed, VS Code, Cursor, Sublime Text, Text Editor, Neovim, Vim, Helix, Micro or Nano. GUI editors also become the default for text files.
- **File manager:** Files (Nautilus), Nemo, Thunar, Dolphin, Yazi or Ranger.

Only installed apps are listed. The current choice is marked. Your picks are saved in `~/.config/omarchy-ubuntu/defaults`, and the Super + Return, Super + Shift + B, Super + Shift + N and Super + Shift + F shortcuts follow them.

## Layout

```
config/            -> symlinked into ~/.config
  hypr/              hyprland.conf sources the files below
    envs, monitors, input, looknfeel, windows, autostart .conf
    bindings/          apps, tiling, utilities, media, clipboard
    hyprlock.conf, hypridle.conf
    local.conf         your untracked overrides (created by install.sh)
  waybar/  fuzzel/  mako/  alacritty/  swayosd/
bin/               -> symlinked into ~/.local/bin (all scripts are omu-*)
themes/purple-catppuccin/
  hyprland.conf, waybar.css, fuzzel.ini, mako.ini, alacritty.toml, hyprlock.conf, swayosd.css
  backgrounds/       wallpapers offered in Style > Background
session/           login-screen entry + launcher
```

Each app config includes its colours from `~/.config/omarchy-ubuntu/current/theme`, which points at `themes/purple-catppuccin`. That's the same idea as Omarchy's themes, so adding a second theme later is just another folder.

## Theme

Catppuccin Mocha text and status colours, Mauve `#cba6f7` as the main accent, and backgrounds taken from the wallpaper:

| Role | Hex |
|---|---|
| Background (wallpaper black) | `#0a0612` |
| Panels | `#120b1f` |
| Selection / inactive border | `#1e1530` |
| Wallpaper purple (secondary accent) | `#864cc0` |
| Mauve (main accent) | `#cba6f7` |
| Text | `#cdd6f4` |

The wallpaper is 16:9 and the laptop screen is 16:10, so it's shown in `fit` mode. The thin bands above and below use the wallpaper's own black and blend in. `omu-bg-set <image> fill` switches a wallpaper to fill mode.

## How this differs from Omarchy

- **Hyprland 0.53 from Ubuntu**, not Arch's latest. Omarchy 4 moved to a Lua config and Quickshell. That needs Hyprland 0.56, so this repo follows Omarchy 3.8.
- **fuzzel replaces Walker** for the launcher and menus. Walker isn't packaged for Ubuntu. fuzzel is styled to match: a centred box with square corners and a 2 px border.
- **Wi-Fi and network** use a themed menu built on NetworkManager (`nmcli`) instead of Omarchy's `impala`. Open it with the bar's network icon or Super + Ctrl + W. It lists networks with signal strength, asks for passwords in the same menu box, and can disconnect, forget, switch saved connections (wired, VPN) and open the full settings.
- **Ubuntu tools** in place of Omarchy's other TUIs: `pavucontrol`, `blueman`, `apt`. GTK apps use Ubuntu's `Yaru-purple-dark` theme inside this session only.
- Left out for now: Omarchy's theme switcher, web apps, screen recording, dictation, the screensaver and the install/remove menus.

## Troubleshooting

- After editing a Hyprland file, run `hyprctl configerrors` (Hyprland reloads by itself).
- Waybar doesn't reload by itself: use *Update > Restart Waybar* in the menu, or `omu-restart-waybar`.
- If the screen name isn't `eDP-1`, check `hyprctl monitors` and fix `config/hypr/monitors.conf`.
- Personal tweaks go in `~/.config/hypr/local.conf` (not tracked by git).
- **Virtual machines:** turn on 3D acceleration in the VM settings, because Hyprland needs a GPU with OpenGL (VirtualBox: VMSVGA + "Enable 3D Acceleration"; virt-manager: Virtio video with 3D/OpenGL). `install.sh` detects a VM and turns off hardware cursors, which otherwise often show up invisible. The virtual screen isn't `eDP-1`, so it uses the fallback line in `monitors.conf`.
- If the launcher won't open, run `fuzzel` in a terminal. An older fuzzel may reject a newer option in `config/fuzzel/fuzzel.ini`. Delete the line it names.

## Credits

Configs, keybindings, the bar layout, the menu and the keybindings viewer are adapted from [Omarchy](https://github.com/basecamp/omarchy) 3.8 by David Heinemeier Hansson (MIT). Colours from [Catppuccin](https://catppuccin.com). See [LICENSE](LICENSE).
