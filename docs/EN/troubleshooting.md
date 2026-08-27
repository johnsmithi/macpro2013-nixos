# Troubleshooting

## Network and package downloads

- **`unable to download` / downloads hang while ping works** — in order:
  1. Check the clock: `date`. Old Macs lose the date after an NVRAM reset,
     and all HTTPS downloads then fail certificate checks. Fix with
     `date -u -s "…"` or `systemctl restart systemd-timesyncd`. A few
     minutes of skew, or a "timezone-looking" 3-hour offset (the installer
     shows UTC), is not a problem.
  2. Find out who exactly is unreachable:
     `curl -I https://cache.nixos.org/nix-cache-info` and
     `curl -sIL https://github.com/NixOS/nixpkgs | head -n1`.
  3. `cache.nixos.org` hangs (typical for some ISPs — it is a Fastly CDN):
     use the mirrors — the command is in the
     [installation guide](install.md#install). The mirrors are full copies
     of the official cache with the same signatures. If GitHub is also
     unreachable, replace `nixpkgs.url` in `flake.nix` with
     `"tarball+https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz"`.
  4. Connections drop intermittently — add
     `--option http-connections 4 --option download-attempts 10`
     (the installed system already has these baked into the config).
- **`cannot build … 1 dependency failed` on many packages at once** — find
  the root cause: `grep "builder for" /tmp/install.log` (run the install
  with `2>&1 | tee /tmp/install.log`). All source downloads in nix go
  through a `curl` that nix itself builds, so one failed build in that
  chain cascades into everything else. Tail of a specific build's log:
  `nix log /nix/store/….drv | tail -30`.
- **`broadcom-sta` build failed** (a real compile error, not "dependency
  failed") — the new kernel is not patched yet. Temporarily set
  `boot.kernelPackages = pkgs.linuxPackages_6_12;` and revert to
  `pkgs.linuxPackages` once patches land.

## Boot and graphics

- **The installer hangs / black screen when booting the ISO** — press `e`
  in the boot menu and append `nomodeset` (installer only; the installed
  system uses the proper amdgpu parameters).
- **`DMAR: DRHD: handling fault status` spam in dmesg, stalls** —
  uncomment `intel_iommu=off` in `boot.kernelParams`
  (a known MacPro6,1 quirk).
- **GPU instability** — fallback option: `amdgpu.dpm=0` in `kernelParams`.
- **The compositor feels sluggish** — niri may have picked the "blind"
  second D300 (the one with no display outputs) as the primary GPU. Check
  `journalctl --user -u niri | grep -i drm` and uncomment the `debug` block
  at the end of `config.kdl`, pointing it at the card with connected
  outputs (`ls -l /dev/dri/by-path`).
- **A monitor on a Thunderbolt chain is not detected** — connect it
  directly (the miniDP ports work as plain DisplayPort); TB chaining under
  Linux is finicky.

## Wi-Fi

- **Network not visible / cannot connect** — make sure the network is not
  WPA3-only: the `wl` driver supports WPA2 only.
- **Wi-Fi broke after a system update** — a fresh kernel series without
  `wl` patches. Return to `boot.kernelPackages = pkgs.linuxPackages;`
  (LTS) or temporarily `pkgs.linuxPackages_6_12`.

## Miscellaneous

- **Bluetooth fussy when pairing** — a known trait; re-pairing helps, the
  `.hcd` firmware is already installed (`broadcom-bt-firmware`).
- **Suspend does not work** — it is intentionally disabled: S3 on the
  MacPro6,1 is untested by the community. To experiment, remove the
  `systemd.targets.*` block from `configuration.nix`.
