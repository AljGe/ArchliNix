{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types concatLists optionals unique;

  cfg = config.my.packages;

  packageGroups = with pkgs; {
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
    compute = [
      cudaPackages.cudatoolkit
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
    monitoring = [
      btop-cuda
      nvtopPackages.nvidia
      procs
      stress
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
    gui = [
      tor-browser
    ];
    misc = [
      fastfetch
      marp-cli
      typst
    ];
    fonts = [
      atkinson-hyperlegible
      dejavu_fonts
      nerd-fonts.jetbrains-mono
      noto-fonts-color-emoji
    ];
  };

  basePackages =
    packageGroups.nixTools
    ++ packageGroups.secrets
    ++ packageGroups.packageManagers
    ++ packageGroups.filesystem
    ++ packageGroups.content
    ++ packageGroups.dev
    ++ packageGroups.network
    ++ packageGroups.docs;

  optionalPackages =
    concatLists (
      optionals cfg.enableCompute [packageGroups.compute]
      ++ optionals cfg.enableMonitoring [packageGroups.monitoring]
      ++ optionals cfg.enableGui [packageGroups.gui]
      ++ optionals cfg.enableFonts [packageGroups.fonts]
      ++ optionals cfg.enableMisc [packageGroups.misc]
    );

  selectedPackages = unique (basePackages ++ optionalPackages);
in {
  options.my.packages = {
    enableCompute = mkOption {
      type = types.bool;
      default = true;
      description = "Include compute-heavy packages (CUDA toolkits, etc.).";
    };

    enableMonitoring = mkOption {
      type = types.bool;
      default = true;
      description = "Include monitoring/metrics packages.";
    };

    enableGui = mkOption {
      type = types.bool;
      default = true;
      description = "Include GUI applications.";
    };

    enableFonts = mkOption {
      type = types.bool;
      default = true;
      description = "Include additional fonts.";
    };

    enableMisc = mkOption {
      type = types.bool;
      default = true;
      description = "Include miscellaneous CLI utilities.";
    };

    packageGroups = mkOption {
      type = types.attrsOf (types.listOf types.package);
      default = {};
      readOnly = true;
      description = "Defined package groups for the home profile.";
    };

    selected = mkOption {
      type = types.listOf types.package;
      default = [];
      readOnly = true;
      description = "Flattened list of packages built from enabled groups.";
    };
  };

  config = {
    my.packages.packageGroups = packageGroups;
    my.packages.selected = selectedPackages;
  };
}

