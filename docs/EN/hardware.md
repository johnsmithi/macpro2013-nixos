# Hardware: Mac Pro 6,1 on Linux

This configuration targets the Late 2013 Mac Pro ("trash can"): Xeon E5 v2,
2x AMD FirePro D300, 16–64 GB RAM. Verified against NixOS **26.05**
(kernel 6.18 LTS). A RAM upgrade (e.g. 16 → 32 GB) requires no configuration
changes.

## What works

| Hardware | Status |
|---|---|
| GPU 2x FirePro D300 | ✅ `amdgpu` + Mesa (radeonsi) |
| Ethernet (2 ports, BCM57762) | ✅ out of the box (`tg3`) |
| Wi-Fi (BCM4360) | ✅ via the proprietary `wl`; **WPA3 does not work — WPA2 only** |
| Bluetooth (BCM20702) | ✅ (occasionally fussy when pairing) |
| Audio (analog + HDMI/DP) | ✅ PipeWire; HDMI audio requires `amdgpu.dc=1` (enabled) |
| Fan/sensors | ✅ the SMC manages itself; `sensors` sees everything |
| Suspend (S3) | ⚠️ untested by the community — disabled in this config |

## GPU: why these kernel parameters

The FirePro D300 is a Pitcairn chip of the GCN 1.0 generation ("Southern
Islands"). On kernels < 6.19 such GPUs are claimed by the legacy `radeon`
driver, which has no atomic KMS — Smithay-based compositors (niri) work
poorly with it. Hence in `configuration.nix`:

```nix
boot.kernelParams = [
  "radeon.si_support=0"
  "amdgpu.si_support=1"
  "amdgpu.dc=1"
];
```

- `si_support` — explicitly hands the card to the `amdgpu` driver (safe on
  any kernel, including ≥ 6.19 where this is already the default);
- `amdgpu.dc=1` — Display Core: atomic KMS and HDMI/DP audio; without it
  this machine is known to produce black screens.

**Dual-GPU quirk:** all display outputs (6x Thunderbolt/miniDP + HDMI) are
physically wired to **one** of the two D300s; the second one is compute-only
and cannot drive a monitor. The OS sees both cards — that is normal.
Output names (`DP-11` etc.) have sparse numbering — unused DP encoders of
the Thunderbolt mux are enumerated too.

## Wi-Fi: Broadcom BCM4360

The `14e4:43a0` card works **only** with the proprietary `wl` driver
(`broadcom_sta`). The open `brcmfmac`/`b43` drivers do not support it.
`nixos-generate-config` does **not** detect this driver — it is declared
manually in `configuration.nix`:

```nix
boot.kernelModules = [ "wl" ... ];
boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
boot.blacklistedKernelModules = [ "b43" "bcma" "brcmsmac" "ssb" ];
nixpkgs.config.allowUnfree = true;
nixpkgs.config.allowInsecurePredicate = pkg: (pkg.pname or "") == "broadcom-sta";
```

`allowInsecurePredicate` is mandatory: the package is marked insecure in
nixpkgs (old CVEs, unmaintained by Broadcom), and without it evaluation
fails. The driver is not built by NixOS CI (unfree) and compiles locally
during installation. Limitations: **no WPA3 support**, and the driver
periodically breaks on fresh kernel series until patches land — which is
why the configuration stays on the LTS kernel (`pkgs.linuxPackages`).

## Firmware

The config uses `hardware.enableRedistributableFirmware` plus
`broadcom-bt-firmware` (Bluetooth firmware) separately. Do **not** use
`hardware.enableAllFirmware`: it pulls in packages with dead/unreachable
sources (facetimehd — an OS X image from Apple's CDN, b43 firmware) that
this machine does not need: there is no camera, and Wi-Fi runs on `wl`.

## Boot (UEFI)

systemd-boot works normally. Apple firmware **ignores** BootOrder entries
in NVRAM, hence `canTouchEfiVariables = false`; the Mac boots via the
fallback copy `\EFI\BOOT\BOOTX64.EFI` that systemd-boot always installs on
the ESP (shown as "EFI Boot" in the Option-key menu). The stock SSD is
PCIe AHCI (appears as `/dev/sda`), supported out of the box; an NVMe blade
via an adapter also works (the `nvme` module is included in the initrd).

## Miscellaneous

- **Suspend (S3)** is disabled (`systemd.targets.suspend.enable = false`
  etc.): it is effectively untested by the community on the MacPro6,1, and
  a hang on resume is worse than no suspend on a desktop. GNOME's automatic
  suspend is additionally disabled via GSettings.
- **Fan** — the SMC manages it automatically and the machine stays quiet;
  for manual control enable `services.mbpfan.enable = true`.
- **Microcode** for the Xeon E5 v2 is updated
  (`hardware.cpu.intel.updateMicrocode`).
- Linux cannot update Apple firmware (BootROM) — if that matters, keep a
  macOS partition.
