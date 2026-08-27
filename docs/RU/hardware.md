# Железо: Mac Pro 6,1 под Linux

Конфигурация рассчитана на Mac Pro Late 2013 («мусорка»): Xeon E5 v2,
2x AMD FirePro D300, 16–64 ГБ RAM. Проверена против NixOS **26.05**
(ядро 6.18 LTS). Расширение RAM (например, 16 → 32 ГБ) изменений
в конфигурации не требует.

## Что работает

| Железо | Статус |
|---|---|
| GPU 2x FirePro D300 | ✅ `amdgpu` + Mesa (radeonsi) |
| Ethernet (2 порта, BCM57762) | ✅ из коробки (`tg3`) |
| Wi-Fi (BCM4360) | ✅ через проприетарный `wl`; **WPA3 не работает — только WPA2** |
| Bluetooth (BCM20702) | ✅ (изредка капризничает при сопряжении) |
| Звук (аналог + HDMI/DP) | ✅ PipeWire; HDMI-звук требует `amdgpu.dc=1` (включено) |
| Вентилятор/датчики | ✅ SMC управляет сам; `sensors` показывает всё |
| Сон (S3) | ⚠️ не проверен сообществом — в конфиге отключён |

## GPU: почему такие параметры ядра

FirePro D300 — это чип Pitcairn поколения GCN 1.0 («Southern Islands»).
На ядрах < 6.19 такие GPU по умолчанию обслуживает старый драйвер `radeon`,
у которого нет атомарного KMS — композиторы на Smithay (niri) с ним работают
плохо. Поэтому в `configuration.nix`:

```nix
boot.kernelParams = [
  "radeon.si_support=0"
  "amdgpu.si_support=1"
  "amdgpu.dc=1"
];
```

- `si_support` — явная передача карты драйверу `amdgpu` (безопасно на любом
  ядре, включая ≥ 6.19, где это уже поведение по умолчанию);
- `amdgpu.dc=1` — Display Core: атомарный KMS и звук по HDMI/DP; без него
  на этой машине встречаются чёрные экраны.

**Двухкарточная особенность:** все дисплейные выходы (6x Thunderbolt/miniDP +
HDMI) физически подключены только к **одной** из двух D300; вторая — чисто
вычислительная и монитор вывести не может. ОС видит обе карты — это норма.
Имена выходов (`DP-11` и т.п.) имеют «дырявую» нумерацию — неиспользуемые
DP-энкодеры Thunderbolt-мультиплексора тоже нумеруются.

## Wi-Fi: Broadcom BCM4360

Карта `14e4:43a0` работает **только** с проприетарным драйвером `wl`
(`broadcom_sta`). Открытые `brcmfmac`/`b43` её не поддерживают.
`nixos-generate-config` этот драйвер **не** определяет — он прописан
в `configuration.nix` вручную:

```nix
boot.kernelModules = [ "wl" ... ];
boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
boot.blacklistedKernelModules = [ "b43" "bcma" "brcmsmac" "ssb" ];
nixpkgs.config.allowUnfree = true;
nixpkgs.config.allowInsecurePredicate = pkg: (pkg.pname or "") == "broadcom-sta";
```

`allowInsecurePredicate` обязателен: пакет помечен в nixpkgs как insecure
(старые CVE, Broadcom драйвер не сопровождает), и без этого сборка падает
на этапе eval. Драйвер не собирается CI NixOS (unfree) и компилируется
локально при установке. Ограничения: **WPA3 не поддерживается**, на свежих
сериях ядер драйвер периодически ломается до выхода патчей — поэтому
конфигурация сидит на LTS-ядре (`pkgs.linuxPackages`).

## Прошивки

Используется `hardware.enableRedistributableFirmware` + отдельно
`broadcom-bt-firmware` (прошивка Bluetooth). **Не** используйте
`hardware.enableAllFirmware`: оно тянет пакеты с мёртвыми/недоступными
источниками (facetimehd — образ OS X с CDN Apple, b43-прошивки), которые
этой машине не нужны: камеры нет, Wi-Fi работает через `wl`.

## Загрузка (UEFI)

systemd-boot работает штатно. Прошивка Apple **игнорирует** записи BootOrder
в NVRAM, поэтому `canTouchEfiVariables = false`; Mac грузится через
fallback-копию `\EFI\BOOT\BOOTX64.EFI`, которую systemd-boot всегда кладёт
на ESP (в меню по клавише Option — «EFI Boot»). Штатный SSD — PCIe AHCI
(виден как `/dev/sda`), поддерживается из коробки; NVMe-блейд через
переходник тоже работает (модуль `nvme` включён в initrd).

## Прочее

- **Сон (S3)** отключён (`systemd.targets.suspend.enable = false` и т.д.):
  на MacPro6,1 он фактически не тестирован сообществом, а зависание при
  выходе из сна на настольной машине хуже, чем его отсутствие. Автосон GNOME
  дополнительно отключён через GSettings.
- **Вентилятор** — SMC управляет автоматически, машина тихая; для ручного
  контроля можно включить `services.mbpfan.enable = true`.
- **Микрокод** Xeon E5 v2 обновляется (`hardware.cpu.intel.updateMicrocode`).
- Linux не умеет обновлять прошивку Apple (BootROM) — если это важно,
  оставьте раздел с macOS.
