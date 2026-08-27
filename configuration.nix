# NixOS 26.05 + niri на Mac Pro 6,1 (Late 2013), 2x AMD FirePro D300.
# Все железо-специфичные решения прокомментированы — не удаляйте их «для чистоты».
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  ####################################################################
  # Загрузка (UEFI / systemd-boot)
  ####################################################################
  boot.loader.systemd-boot.enable = true;
  # ESP у Mac'ов небольшой — не копим старые поколения в /boot.
  boot.loader.systemd-boot.configurationLimit = 5;
  # Прошивка Apple игнорирует записи BootOrder в NVRAM, поэтому писать efivars
  # бессмысленно — Mac и так грузится через fallback-копию \EFI\BOOT\BOOTX64.EFI,
  # которую systemd-boot всегда кладёт на ESP (в меню по Option это "EFI Boot").
  boot.loader.efi.canTouchEfiVariables = false;

  # Ядро по умолчанию в 26.05 — 6.18 LTS. Не гонитесь за linuxPackages_latest:
  # проприетарный Wi-Fi-драйвер wl исторически ломается на каждой новой серии
  # ядер, а LTS всегда пропатчен.
  boot.kernelPackages = pkgs.linuxPackages;

  ####################################################################
  # GPU: 2x FirePro D300 (Pitcairn, GCN 1.0 / Southern Islands)
  ####################################################################
  # На ядрах < 6.19 такие GPU по умолчанию берёт старый драйвер radeon,
  # у которого нет атомарного KMS — niri (Smithay) с ним работает плохо.
  # Явно отдаём карту amdgpu и включаем Display Core:
  boot.kernelParams = [
    "radeon.si_support=0"
    "amdgpu.si_support=1"
    "amdgpu.dc=1" # атомарный KMS + звук по HDMI/DP; без него бывает чёрный экран
    # При спаме "DMAR: DRHD: handling fault status" или зависаниях раскомментируйте:
    # "intel_iommu=off"
  ];
  # Ранний KMS (картинка с самого начала загрузки). Уберите, если загрузка виснет.
  boot.initrd.kernelModules = [ "amdgpu" ];
  hardware.graphics.enable = true;
  # Заметка: дисплейные выходы (6x Thunderbolt/miniDP + HDMI) физически подключены
  # только к ОДНОЙ из двух D300; вторая — чисто вычислительная. Это нормально,
  # что мониторы работают лишь на части портов ОС видит две карты.

  ####################################################################
  # Wi-Fi: Broadcom BCM4360 (14e4:43a0) — работает ТОЛЬКО с проприетарным wl.
  # nixos-generate-config его НЕ определяет — эти строки обязательны.
  ####################################################################
  boot.kernelModules = [ "wl" "applesmc" "coretemp" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.blacklistedKernelModules = [ "b43" "bcma" "brcmsmac" "ssb" ];
  # Важно: wl ненадёжен с WPA3 — держите домашнюю сеть на WPA2.

  nixpkgs.config.allowUnfree = true; # broadcom_sta, прошивки, микрокод
  # broadcom-sta дополнительно помечен в nixpkgs как insecure (старые CVE
  # 2019 года, драйвер Broadcom не сопровождает) — без этой строки сборка
  # падает с "marked as insecure, refusing to evaluate". Предикат по pname
  # переживает обновления ядра, в отличие от permittedInsecurePackages.
  nixpkgs.config.allowInsecurePredicate = pkg: (pkg.pname or "") == "broadcom-sta";

  # Все redistributable-прошивки (linux-firmware: amdgpu, tg3 и т.д.).
  # Именно НЕ enableAllFirmware: то тянет пакеты с мёртвыми/недоступными
  # источниками (facetimehd — образ OS X с CDN Apple, b43-прошивки), которые
  # этой машине не нужны: камеры нет, BCM4360 работает через wl, а не b43.
  hardware.enableRedistributableFirmware = true;
  # Bluetooth BCM20702: прошивку .hcd подключаем отдельно.
  hardware.firmware = [ pkgs.broadcom-bt-firmware ];
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # апплет живёт в трее waybar

  # Xeon E5 v2 (Ivy Bridge-EP)
  hardware.cpu.intel.updateMicrocode = true;

  ####################################################################
  # Сеть. Оба Ethernet-порта (BCM57762, драйвер tg3) работают из коробки.
  ####################################################################
  networking.hostName = "macpro";
  networking.networkmanager.enable = true;

  ####################################################################
  # Локаль и время
  ####################################################################
  time.timeZone = "Europe/Moscow"; # поменяйте при необходимости
  # ru_RU и en_US локали генерируются автоматически из defaultLocale + дефолтов.
  i18n.defaultLocale = "ru_RU.UTF-8";

  ####################################################################
  # GNOME (основной рабочий стол) + niri (запасной), вход через GDM
  ####################################################################
  # Модуль niri сам настраивает: сессию для DM, порталы (gnome + gtk, скринкаст
  # через gnome-портал), gnome-keyring, демон polkit, PAM-запись для swaylock.
  programs.niri.enable = true;

  # GDM показывает меню сессий (шестерёнка в правом нижнем углу): GNOME или
  # niri. Выбор запоминается отдельно для каждого пользователя; до первого
  # выбора предлагается сессия по умолчанию — GNOME.
  services.displayManager.gdm.enable = true;
  services.displayManager.defaultSession = "gnome";
  services.desktopManager.gnome.enable = true;
  # GNOME по умолчанию усыпляет машину после простоя. Сон и так замаскирован
  # ниже (S3 на MacPro6,1 не проверен), но отключим и сами попытки,
  # чтобы не сыпались ошибки в журнал.
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.settings-daemon.plugins.power]
    sleep-inactive-ac-type='nothing'
  '';

  # Модуль niri включает демон polkit, но не агента — без агента графические
  # программы не смогут запрашивать права администратора. В GNOME агент
  # встроен в gnome-shell, поэтому наш запускаем только внутри niri-сессии
  # (привязка к niri.service, а не к graphical-session.target).
  systemd.user.services.polkit-agent = {
    description = "polkit authentication agent (niri)";
    wantedBy = [ "niri.service" ];
    partOf = [ "niri.service" ]; # останавливаться вместе с niri
    after = [ "niri.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  # Звук (PipeWire). Аудио по HDMI/DP работает благодаря amdgpu.dc=1.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Конфиги рабочего стола системно, без home-manager:
  # ~/.config/niri/config.kdl (если создадите) имеет приоритет над /etc/niri/config.kdl;
  # ~/.config/waybar/ — над /etc/xdg/waybar/.
  environment.etc."niri/config.kdl".source = ./niri/config.kdl;
  environment.etc."xdg/waybar/config".source = ./waybar/config;
  environment.etc."xdg/waybar/style.css".source = ./waybar/style.css;

  environment.systemPackages = with pkgs; [
    alacritty        # терминал (Mod+Return)
    fuzzel           # лаунчер (Mod+D)
    waybar           # панель
    mako             # уведомления
    swaylock swayidle
    wl-clipboard     # wl-copy / wl-paste
    xwayland-satellite # X11-приложения; niri >= 25.08 запускает его сам при необходимости
    pavucontrol
    git vim wget htop
    lm_sensors       # sensors: температуры/вентилятор через applesmc
  ];

  programs.firefox.enable = true;

  # Electron/Chromium-приложения — нативный Wayland вместо XWayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono # иконки в waybar
  ];

  ####################################################################
  # Пользователь — поменяйте имя на своё
  ####################################################################
  users.users.wryngel = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme"; # сразу после первого входа: passwd
  };

  # Сон (S3) на MacPro6,1 сообществом фактически не проверен (типичные
  # маковские проблемы с пробуждением + amdgpu на GCN 1.0). Для настольной
  # машины проще запретить, чтобы не уйти в сон без возврата.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Вентилятором управляет сам SMC — машина тихая и без сервисов.
  # Для ручного контроля можно включить: services.mbpfan.enable = true;

  zramSwap.enable = true; # сжатый swap в RAM, дисковый раздел не нужен

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # cache.nixos.org (CDN Fastly) недоступен у части провайдеров — используем
  # полные зеркала официального кэша (подписи пакетов те же).
  nix.settings.substituters = [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
  ];
  # Щадящий режим для нестабильной сети: таймауты, меньше параллельных
  # соединений, больше повторов.
  nix.settings.connect-timeout = 10;
  nix.settings.http-connections = 4;
  nix.settings.download-attempts = 10;

  # services.openssh.enable = true; # включите, если нужен доступ по SSH

  # Версия первой установки. НЕ меняйте при обновлениях системы.
  system.stateVersion = "26.05";
}
