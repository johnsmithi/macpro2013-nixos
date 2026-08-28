# NixOS on the 2013 Mac Pro

A complete, battle-tested NixOS **26.05** configuration for the Apple
Mac Pro 6,1 (Late 2013, the "trash can") — GNOME as the default desktop,
the [niri](https://github.com/niri-wm/niri) scrollable-tiling compositor as
a second session, and every hardware quirk of this machine handled.

## Why this exists

The trash-can Mac Pro is a great Linux workstation — Xeon E5 v2, dual AMD
FirePro GPUs, whisper-quiet — but a generic NixOS config will not boot into
a working desktop on it. This machine needs decisions that are easy to get
wrong and hard to discover:

- The FirePro D300 is a GCN 1.0 ("Southern Islands") GPU that older kernels
  hand to the legacy `radeon` driver — which lacks atomic KMS and breaks
  modern Wayland compositors. The config forces `amdgpu` with Display Core
  (`si_support` + `amdgpu.dc=1`).
- The Broadcom BCM4360 Wi-Fi works only with the proprietary `wl` driver,
  which `nixos-generate-config` does not detect and which nixpkgs marks as
  both unfree **and** insecure — two separate gates to open.
- Apple's firmware ignores UEFI BootOrder; booting relies on the fallback
  `BOOTX64.EFI` path, and the config is written accordingly.
- Only one of the two GPUs is wired to the display outputs; suspend is
  untested on this hardware; `hardware.enableAllFirmware` pulls packages
  with dead upstream sources. All of this is accounted for.

Every option in the config was verified against the nixpkgs `nixos-26.05`
sources, and the install path was debugged on real hardware — including
networks where `cache.nixos.org` is unreachable (binary-cache mirrors are
baked in).

## What you get

- **Flake-based** single-host config (`nixosConfigurations.macpro`).
- **GNOME** (default session) + **niri 26.04** (pick at the GDM login
  screen), portals, PipeWire, polkit wired for both.
- A commented, known-good **niri config** (`/etc/niri/config.kdl`, US/RU
  layouts) and a matching **waybar** setup — both overridable per user.
- Working **Wi-Fi** (WPA2), **Bluetooth**, **HDMI/DP audio**, sensors.
- Docs that cover the full journey: flashing the USB on macOS, Apple-boot
  specifics, partitioning, offline/blocked-CDN installs, post-install use.

## Documentation

| | English | Русский |
|---|---|---|
| Hardware notes | [docs/EN/hardware.md](docs/EN/hardware.md) | [docs/RU/hardware.md](docs/RU/hardware.md) |
| Installation | [docs/EN/install.md](docs/EN/install.md) | [docs/RU/install.md](docs/RU/install.md) |
| Usage | [docs/EN/usage.md](docs/EN/usage.md) | [docs/RU/usage.md](docs/RU/usage.md) |
| Troubleshooting | [docs/EN/troubleshooting.md](docs/EN/troubleshooting.md) | [docs/RU/troubleshooting.md](docs/RU/troubleshooting.md) |

## Repository layout

| Path | Purpose |
|---|---|
| [flake.nix](flake.nix) | flake entry point, nixpkgs `nixos-26.05` |
| [configuration.nix](configuration.nix) | the whole system: boot, GPU, Wi-Fi, desktops, mirrors |
| [hardware-configuration.nix](hardware-configuration.nix) | template matching the documented partitioning; regenerated during install |
| [niri/config.kdl](niri/config.kdl) | niri config, deployed to `/etc/niri/config.kdl` |
| [waybar/](waybar/) | waybar config + style, deployed to `/etc/xdg/waybar/` |
| [assets/](assets/) | starter wallpapers (Unsplash, see [CREDITS](assets/CREDITS.md)) |
| [scripts/](scripts/) | helper scripts (`install-wallpapers.sh` → `~/Pictures/Wallpapers`) |
| [docs/](docs/) | documentation (EN/RU) |

## Quick start

1. Flash the minimal NixOS 26.05 ISO to a USB stick and boot the Mac Pro
   from it with the Option key held (Ethernet cable required — the ISO has
   no driver for this Wi-Fi card).
2. Partition the SSD with the `NIXOS-BOOT`/`nixos` labels, copy this repo
   to `/mnt/etc/nixos`, run `nixos-generate-config --root /mnt`, set your
   user name and time zone in `configuration.nix`.
3. `nixos-install --flake /mnt/etc/nixos#macpro`, reboot, and at the boot
   picker select "EFI Boot" with Control held to make it stick.

The full walkthrough, including every command and the network fallbacks,
is in [docs/EN/install.md](docs/EN/install.md).

## Status

Verified working on MacPro6,1 with dual FirePro D300 and 16 GB RAM
(August 2026): boots to GDM, both GNOME and niri sessions run, Wi-Fi
(WPA2), Bluetooth, wired networking, audio including HDMI/DP, fan control
via the SMC. Suspend (S3) is intentionally disabled — untested on this
hardware. Details in [docs/EN/hardware.md](docs/EN/hardware.md).
