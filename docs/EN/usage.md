# Usage

## First login

- On the GDM screen pick your user, password `changeme` — **GNOME** loads by
  default. To try **niri**, click the gear in the bottom-right corner before
  entering the password and pick the session — the choice is remembered
  per user.
- Change the password right away: terminal → `passwd`.
- Wi-Fi: in GNOME — via Settings; in niri — `nmtui` in a terminal.
  The network must be **WPA2** (the `wl` driver cannot do WPA3).

## Essential niri keys

| Keys | Action |
|---|---|
| **Super+Shift+/** | cheat sheet with all hotkeys |
| Super+Enter / Super+T | terminal (alacritty) |
| Super+D | launcher (fuzzel) |
| Super+Q | close window |
| Super+arrows / H J K L | focus columns/windows |
| Super+1…9 | workspaces |
| Super+O | overview |
| Super+F | maximize column |
| Super+Space | switch en/ru keyboard layout |
| Print | screenshot |
| Super+Shift+V | clipboard history (cliphist) |
| Super+Alt+L | lock the screen |
| Super+Shift+E | quit niri (back to GDM) |

Running automatically in the background: **swaybg** (wallpaper — drop
images into `~/Pictures/Wallpapers`, a random one is picked at every
login; swaybg scales to the screen by itself, keep the images at least
as large as the monitor's resolution; a starter set lives in `assets/`,
install it with `./scripts/install-wallpapers.sh` from the repo
directory), **swayidle** (lock after
10 minutes idle, monitors off after 15), **cliphist** (clipboard
history) and **wlsunset** (warm screen tint in the evening; your city's
coordinates are set in `config.kdl`). The GNOME session's wallpaper is
configured separately, in its own settings.

## Power off and reboot

- From a terminal (no sudo needed): `systemctl poweroff` /
  `systemctl reboot`.
- A short press of the physical power button performs a clean shutdown.
- Or quit niri (Super+Shift+E) and use GDM's power menu.

Holding the power button long is a hard power cut — only for a frozen
system.

## Customizing niri (including display scale)

The system config lives at `/etc/niri/config.kdl` (read-only) and is
updated by `nixos-rebuild`. The user file `~/.config/niri/config.kdl`
takes priority, but do **not** copy the system config wholesale — pull it
in with the `include` directive and append only your own bits:

One command creates it (substitute your monitor name from
`niri msg outputs`):

```bash
mkdir -p ~/.config/niri
cat > ~/.config/niri/config.kdl <<'EOF'
include "/etc/niri/config.kdl"

// below — personal additions only; they override what was included,
// while the system part keeps updating with every rebuild
output "DP-11" {
    scale 2
}
EOF
```

The example doubles as the display-scale (HiDPI) setup — it is set per
monitor. Do not describe the same monitor in both the system file and
yours: `output` blocks are inserted without merging. Conflicting keys in
`binds {}` after the include simply override the system ones — handy for
targeted tweaks.

niri watches the files and applies changes **immediately on save**.
Syntax check: `niri validate`. Monitor names: `niri msg outputs`.

Fractional values work too (`scale 1.5`). X11 apps (via xwayland-satellite)
may look slightly blurry when scaled — a general Wayland trait. In GNOME
the scale is configured separately: Settings → Displays.

Same pattern for waybar: system files in `/etc/xdg/waybar/`, user files in
`~/.config/waybar/`.

## Updating the system

```bash
sudo nixos-rebuild switch --flake /etc/nixos#macpro
```

To update nixpkgs itself, run `nix flake update` in `/etc/nixos` first.
Binary-cache mirrors and network timeouts are already baked into the config
(`nix.settings.*` in `configuration.nix`).

If Wi-Fi breaks after an update — see
[troubleshooting](troubleshooting.md) (the `wl` driver vs. new kernels).
