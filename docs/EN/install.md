# Installation

After booting from the USB stick, all commands run in the installer console
on the Mac Pro.

## Before installing

1. **Plug in an Ethernet cable.** The installer ISO does not ship the Wi-Fi
   driver for the BCM4360 (it is proprietary).
2. Download the minimal ISO:
   <https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso>
3. Write it to a USB stick (`diskN` / `sdX` is your stick — check with
   `diskutil list` / `lsblk`; everything on it will be erased!). On macOS
   unmount it first (otherwise dd fails with "Resource busy"):

   ```bash
   diskutil unmountDisk /dev/diskN
   sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/rdiskN bs=4M status=progress
   diskutil eject /dev/diskN
   ```

   On Linux:

   ```bash
   sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

   The "The disk you attached was not readable" dialog after writing is
   normal — click "Ignore". (balenaEtcher works too, instead of dd.)
4. Plan how to get this folder onto the Mac Pro: a second USB stick
   (FAT32/ExFAT) or a git repository (`git` is on the ISO).
5. If you want to keep the ability to update the Mac's firmware (BootROM),
   keep a macOS partition: Linux cannot apply Apple firmware updates.
   The instructions below wipe the whole disk.

## Booting the installer

Insert the stick, power on the Mac **holding the Option (Alt) key**, pick the
orange "EFI Boot" entry. If it hangs — press `e` in the ISO boot menu and
append `nomodeset` to the kernel parameters (installer only).

In the console:

```bash
sudo -i
ping -c3 nixos.org
```

If ping fails — check the cable; if ping works but downloads later fail —
see [troubleshooting](troubleshooting.md), the sections on the clock and
mirrors.

## Partitioning

The internal SSD is usually `/dev/sda` — verify by size with
`lsblk -o NAME,SIZE,MODEL`. **Everything on it will be erased.**

```bash
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 1GiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart root ext4 1GiB 100%
mkfs.fat -F 32 -n NIXOS-BOOT /dev/sda1
mkfs.ext4 -L nixos /dev/sda2
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=0077 /dev/disk/by-label/NIXOS-BOOT /mnt/boot
```

The `NIXOS-BOOT` and `nixos` labels matter — `hardware-configuration.nix`
references them.

## Configuration

Copy this folder to `/mnt/etc/nixos` — from the second USB stick:

```bash
mkdir -p /mnt/etc/nixos /tmp/usb
mount /dev/sdc1 /tmp/usb
cp -r /tmp/usb/macpro-nixos/* /mnt/etc/nixos/
umount /tmp/usb
```

or from git:

```bash
git clone https://github.com/YOUR_LOGIN/macpro-nixos /mnt/etc/nixos
```

Then generate the hardware description (this overwrites only
`hardware-configuration.nix` — that is intended; `configuration.nix` and
`flake.nix` are left alone):

```bash
nixos-generate-config --root /mnt
```

Adjust `/mnt/etc/nixos/configuration.nix` to taste: the user name
(`users.users.…`), the time zone (`time.timeZone`), the hostname.

## Install

```bash
nixos-install --flake /mnt/etc/nixos#macpro
```

Almost everything comes prebuilt from the binary cache; only the `wl` Wi-Fi
driver compiles locally (a few minutes). At the end, set the **root**
password.

If downloads hang or fail with `unable to download`, your ISP may be unable
to reach `cache.nixos.org`; use the mirrors:

```bash
nixos-install --flake /mnt/etc/nixos#macpro \
  --option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store" \
  --option connect-timeout 10 --option http-connections 4 --option download-attempts 10
```

`nixos-install` is safe to re-run any number of times — it resumes where it
left off. More on network problems in
[troubleshooting](troubleshooting.md).

## First boot

```bash
reboot
```

Remove the USB sticks. At power-on hold **Option**, highlight "EFI Boot",
**hold Control** (the arrow becomes circular) and press Enter — the choice
is remembered and the Mac boots NixOS on its own from then on. If you kept
a macOS partition and the Mac keeps booting macOS — pick the startup volume
in macOS: System Settings → Startup Disk.

Next: [usage](usage.md).
