# Этот файл рассчитан на разметку из README (метки разделов NIXOS-BOOT и nixos) —
# с ней он рабочий как есть. Во время установки шаг `nixos-generate-config --root /mnt`
# перезапишет его под фактическое железо/разметку — это нормально и даже желательно.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Штатный SSD Mac Pro 2013 — PCIe AHCI (виден как /dev/sda, драйвер ahci).
  # "nvme" оставлен на случай апгрейда на NVMe-блейд через переходник.
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXOS-BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
