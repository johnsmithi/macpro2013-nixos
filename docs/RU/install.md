# Установка

Все команды после загрузки с флешки выполняются в консоли установщика
на Mac Pro.

## Перед установкой

1. **Подключите Ethernet-кабель.** Установочный ISO не содержит Wi-Fi-драйвера
   для BCM4360 (он проприетарный).
2. Скачайте минимальный ISO:
   <https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso>
3. Запишите на флешку (`diskN` / `sdX` — ваша флешка, проверьте через
   `diskutil list` / `lsblk`; всё на ней будет стёрто!). На macOS сначала
   размонтируйте её (иначе dd упадёт с «Resource busy»):

   ```bash
   diskutil unmountDisk /dev/diskN
   sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/rdiskN bs=4M status=progress
   diskutil eject /dev/diskN
   ```

   На Linux:

   ```bash
   sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

   Окно «Вставленный диск не может быть прочитан» после записи — это нормально,
   нажмите «Игнорировать». (Вместо dd можно использовать balenaEtcher.)
4. Подготовьте доставку этой папки на Mac Pro: вторая флешка (FAT32/ExFAT)
   или git-репозиторий (на ISO есть `git`).
5. Если хотите сохранить возможность обновлять прошивку Mac (BootROM) —
   оставьте раздел с macOS: Linux прошивку Apple обновлять не умеет.
   Инструкция ниже стирает диск целиком.

## Загрузка установщика

Вставьте флешку, включите Mac **с зажатой клавишей Option (Alt)**, выберите
оранжевый пункт «EFI Boot». Если загрузка зависла — в меню загрузчика ISO
нажмите `e` и допишите `nomodeset` к параметрам ядра (только для установщика).

В консоли:

```bash
sudo -i
ping -c3 nixos.org
```

Если пинг не идёт — проверьте кабель; если идёт, но дальше загрузки будут
падать — см. [решение проблем](troubleshooting.md), разделы про часы и зеркала.

## Разметка диска

Внутренний SSD обычно `/dev/sda` — проверьте по размеру через
`lsblk -o NAME,SIZE,MODEL`. **Всё на нём будет стёрто.**

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

Метки `NIXOS-BOOT` и `nixos` важны — на них ссылается
`hardware-configuration.nix`.

## Конфигурация

Скопируйте эту папку в `/mnt/etc/nixos` — со второй флешки:

```bash
mkdir -p /mnt/etc/nixos /tmp/usb
mount /dev/sdc1 /tmp/usb
cp -r /tmp/usb/macpro-nixos/* /mnt/etc/nixos/
umount /tmp/usb
```

или из git:

```bash
git clone https://github.com/ВАШ_ЛОГИН/macpro-nixos /mnt/etc/nixos
```

Затем сгенерируйте описание железа (перезапишет только
`hardware-configuration.nix` — так задумано; `configuration.nix` и `flake.nix`
не тронет):

```bash
nixos-generate-config --root /mnt
```

И поправьте под себя в `/mnt/etc/nixos/configuration.nix`: имя пользователя
(`users.users.…`), часовой пояс (`time.timeZone`), hostname.

## Запуск установки

```bash
nixos-install --flake /mnt/etc/nixos#macpro
```

Почти всё приходит из бинарного кэша; локально собирается только
Wi-Fi-драйвер `wl` (несколько минут). В конце задайте пароль **root**.

Если загрузки висят или падают с `unable to download` — у вашего провайдера
может быть недоступен `cache.nixos.org`; используйте зеркала:

```bash
nixos-install --flake /mnt/etc/nixos#macpro \
  --option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://mirrors.ustc.edu.cn/nix-channels/store" \
  --option connect-timeout 10 --option http-connections 4 --option download-attempts 10
```

`nixos-install` можно перезапускать сколько угодно — он продолжает с места
обрыва. Подробнее о сетевых проблемах — в
[решении проблем](troubleshooting.md).

## Первая загрузка

```bash
reboot
```

Вытащите флешки. При включении зажмите **Option**, наведитесь на «EFI Boot»,
**зажмите Control** (стрелка станет круговой) и нажмите Enter — выбор
запомнится, дальше Mac грузит NixOS сам. Если оставили раздел с macOS и Mac
грузит её — выберите загрузочный том в macOS: Системные настройки →
Загрузочный диск.

Дальше — [использование](usage.md).
