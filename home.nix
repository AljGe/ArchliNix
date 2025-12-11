{
  config,
  lib,
  pkgs,
  ...
}:
let
  xdgConfigHome = config.xdg.configHome;
  profileDir = config.home.profileDirectory;

  gitUserConf = "${xdgConfigHome}/git/user.conf";
  jjUserConf = "${xdgConfigHome}/jj/config.toml";

  devenvWithUv = pkgs.writeShellApplication {
    name = "devenv";
    runtimeInputs = [ pkgs.devenv ];
    text = ''
      export UV_PYTHON_DOWNLOADS=manual
      exec ${pkgs.devenv}/bin/devenv "$@"
    '';
  };

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
in
{
  imports = [
    ./modules/colemak-dh.nix
    ./modules/librewolf.nix
    ./modules/secrets.nix
    ./modules/shell.nix
    ./modules/wsl.nix
  ];

  home.username = "archliNix";
  home.homeDirectory = "/home/archliNix";
  home.stateVersion = "25.05";
  nixpkgs.config.allowUnfree = true;

  home.packages = lib.concatLists (lib.attrValues packageGroups) ++ [ devenvWithUv ];

  home.sessionVariables = {
    EDITOR = "nano";
    LANG = "C.UTF-8";
    LC_CTYPE = "C.UTF-8";
    PERL_BADLANG = "0";
    TYPST_FONT_PATHS = "${profileDir}/share/fonts:${profileDir}/lib/X11/fonts";
    UV_PYTHON_DOWNLOADS = "manual";
    VISUAL = "nano";
  };

  # Ensure Nix profile binaries are on PATH for all shells (direnv, subshells, etc.)
  home.sessionPath = [
    "${profileDir}/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  xdg.enable = true;

  xdg.configFile = {
    "uv/uv.toml".text = ''
      python-downloads = "manual"
    '';
  };

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  my.colemakDH.enable = true;

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";

    settings = {
      manager = {
        show_hidden = true;
        sort_by = "natural";
        sort_sensitive = false;
        sort_reverse = false;
        sort_dir_first = true;
      };
    };

    theme = {
      flavor = {
        use = "catppuccin-mocha";
      };
    };
  };

  programs.git = {
    enable = true;
    settings.alias = {
      st = "status";
      co = "checkout";
      br = "branch";
    };
    includes = [
      { path = gitUserConf; }
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
