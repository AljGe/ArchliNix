{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib)
    mkOption
    types
    concatLists
    optionals
    unique
    attrValues
    mapAttrsToList;

  cfg = config.my.packages;

  baseGroups = with pkgs; {
    nixTools = [
      alejandra
      nh
      nixfmt
      nix-search-tv
    ];
    secrets = [
      age
      magic-wormhole-rs
      sops
    ];
    packageManagers = [
      nodejs_24
      pnpm
      uv
    ];
    filesystem = [
      duf
      dust
      eza
      fd
      ncdu
      ripgrep
    ];
    content = [
      bat
      helix
      jq
      micro
      sd
      yq-go
    ];
    dev = [
      gh
      glab
      jujutsu
    ];
    network = [
      dnsutils
      openssh
      rsync
      tcping-rs
      uutils-coreutils-noprefix
      wget
    ];
    docs = [
      tealdeer
    ];
  };

  optionalGroups = with pkgs; {
    compute = {
      enable = cfg.enableCompute;
      packages = [cudaPackages.cudatoolkit];
    };
    monitoring = {
      enable = cfg.enableMonitoring;
      packages = [
        btop-cuda
        nvtopPackages.nvidia
        procs
        stress
      ];
    };
    gui = {
      enable = cfg.enableGui;
      packages = [tor-browser];
    };
    fonts = {
      enable = cfg.enableFonts;
      packages = [
        atkinson-hyperlegible
        dejavu_fonts
        nerd-fonts.jetbrains-mono
        noto-fonts-color-emoji
      ];
    };
    misc = {
      enable = cfg.enableMisc;
      packages = [
        fastfetch
        marp-cli
        typst
      ];
    };
  };

  basePackages = concatLists (attrValues baseGroups);

  optionalPackages =
    concatLists (
      mapAttrsToList (_: group: optionals group.enable group.packages) optionalGroups
    );

  packageGroups =
    baseGroups
    // (lib.mapAttrs (_: group: group.packages) optionalGroups);

  selectedPackages = unique (basePackages ++ optionalPackages);
in {
  options.my.packages = {
    enableCompute = mkOption {
      type = types.bool;
      default = !(config.wsl.trimDesktopPackages or false);
      description = "Include compute-heavy packages (CUDA toolkits, etc.).";
    };

    enableMonitoring = mkOption {
      type = types.bool;
      default = !(config.wsl.trimDesktopPackages or false);
      description = "Include monitoring/metrics packages.";
    };

    enableGui = mkOption {
      type = types.bool;
      default = !(config.wsl.trimDesktopPackages or false);
      description = "Include GUI applications.";
    };

    enableFonts = mkOption {
      type = types.bool;
      default = !(config.wsl.trimDesktopPackages or false);
      description = "Include additional fonts.";
    };

    enableMisc = mkOption {
      type = types.bool;
      default = true;
      description = "Include miscellaneous CLI utilities.";
    };

    packageGroups = mkOption {
      type = types.attrsOf (types.listOf types.package);
      readOnly = true;
      description = "Defined package groups for the home profile.";
    };

    selected = mkOption {
      type = types.listOf types.package;
      readOnly = true;
      description = "Flattened list of packages built from enabled groups.";
    };
  };

  config = {
    my.packages.packageGroups = packageGroups;
    my.packages.selected = selectedPackages;
  };
}

