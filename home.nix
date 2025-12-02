{
  config,
  pkgs,
  libs,
  ...
}: let
  fastfetchSettings = {
    logo = {
      source = "arch_small";
      padding = { right = 1; };
    };
    display = {
      size = { binaryPrefix = "si"; };
      color = "blue";
      separator = "  ";
    };
    modules = [
      "title"
      "separator"
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      { type = "display"; compactType = "original"; key = "Resolution"; }
      "de"
      "wm"
      "wmtheme"
      "theme"
      "icons"
      "terminal"
      { type = "terminalfont"; format = "{/2}{-}{/}{2}{?3} {3}{?}"; }
      "cpu"
      {
        type = "gpu";
        key = "GPU";
        detectionMethod = "vulkan";
        driverSpecific = true;
        format = "{2}";
      }
      "memory"
      "swap"
      "disk"
      "localip"
      "battery"
      "poweradapter"
      "break"
      "colors"
    ];
  };
  git-user-conf = "${config.home.homeDirectory}/.config/git/user.conf";
  jj-user-conf = "${config.home.homeDirectory}/.config/jj/config.toml";
  devenv-with-uv = pkgs.writeShellApplication {
    name = "devenv";
    runtimeInputs = [pkgs.devenv];
    text = ''
      export UV_PYTHON_DOWNLOADS=manual
      exec ${pkgs.devenv}/bin/devenv "$@"
    '';
  };
in {
  imports = [
    ./modules/colemak-dh.nix
    ./modules/librewolf.nix
  ];
  xdg.configFile."fastfetch/config.jsonc".source = (pkgs.formats.json {}).generate "config.jsonc" fastfetchSettings;
  home.username = "archliNix";
  home.homeDirectory = "/home/archliNix";
  home.stateVersion = "25.05";
  nixpkgs.config.allowUnfree = true;
  home.packages =
    (with pkgs; [
      # nix tools
      alejandra
      nh
      nix-search-tv
      nixfmt

      # secrets
      age
      sops
      magic-wormhole-rs

      # package managers and runtimes
      nodejs_24
      pnpm
      uv

      # cudaPackages.cuda_nvcc
      cudaPackages.cudatoolkit

      # Filesystem & search
      dust
      eza
      fd
      ncdu
      duf
      ripgrep

      # File content & data manipulation
      micro
      helix
      bat
      jq
      sd
      yq-go

      # System monitoring & info
      btop-cuda
      procs
      nvtopPackages.nvidia

      # Development & version control
      jujutsu
      gh
      glab

      # Network
      openssh
      rsync
      wget
      uutils-coreutils-noprefix
      dnsutils
      tcping-rs

      # Documentation
      tealdeer

      # gui apps
      tor-browser

      # other
      typst
      marp-cli

      # fonts
      atkinson-hyperlegible
      dejavu_fonts
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
    ])
    ++ [devenv-with-uv];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets."example_secret" = {};
    secrets."github_private_mail" = {};
    secrets."github_private_name" = {};
    templates."example.env" = {
      content = ''
        EXAMPLE_SECRET=${config.sops.placeholder."example_secret"}
      '';
      path = "${config.home.homeDirectory}/.config/example/.env";
    };
    templates."git-user.conf" = {
      content = ''
        [user]
          name = ${config.sops.placeholder."github_private_name"}
          email = ${config.sops.placeholder."github_private_mail"}
      '';
      path = git-user-conf;
    };
    templates."jj-user.conf" = {
      content = ''
        [user]
          name = "${config.sops.placeholder."github_private_name"}"
          email = "${config.sops.placeholder."github_private_mail"}"

        [ui]
          default-command = "log"
          editor = "nano"
    '';
      path = jj-user-conf;
    };
  };

  home.sessionVariables = {
    EDITOR = "nano";
    VISUAL = "nano";
    LANG = "C.UTF-8";
    LC_CTYPE = "C.UTF-8";
    PERL_BADLANG = "0";
    UV_PYTHON_DOWNLOADS = "manual";
    # EDITOR = "emacs";
    TYPST_FONT_PATHS = "${config.home.homeDirectory}/.nix-profile/share/fonts:${config.home.homeDirectory}/.nix-profile/lib/X11/fonts";
    VK_DRIVER_FILES = "${config.home.homeDirectory}/.config/vulkan/icd.d/nvidia_wsl.json";
  };

  # Ensure Nix profile binaries are on PATH for all shells (direnv, subshells, etc.)
  home.sessionPath = [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  xdg.enable = true;

  xdg.configFile = {
    "uv/uv.toml".text = ''
      python-downloads = "manual"
    '';

    # --- ADD THIS BLOCK ---
    "vulkan/icd.d/nvidia_wsl.json".text = ''
      {
        "file_format_version" : "1.0.0",
        "ICD": {
          "library_path": "/usr/lib/wsl/lib/libnvwgf2umx.so",
          "api_version" : "1.3.0"
        }
      }
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
      {path = git-user-conf;}
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.gemini-cli = {
    enable = true;
    defaultModel = "gemini-2.5-pro";
  };
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ff = "fzf";
      cl = "clear";
      #cat = "bat";
      #grep = "rg";
      # make 'grep -R' work with ripgrep...
      ll = "eza -lh --git --group-directories-first --icons";
      la = "eza -lha --git --group-directories-first --icons";
      lt = "eza -lha --git --group-directories-first --tree --icons";
      switch-hm = "home-manager switch --flake ~/dotfiles/.#archliNix";
      switch-nh = "nh home switch ~/dotfiles/";
      switch-nhd = "nh home switch ~/dotfiles/ --dry";
      clean-nh = "nh clean user --keep-since 4d --keep 3";
      clean-nhd = "nh clean user --dry --keep-since 4d --keep 3";
      ns = "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
      nhs = "nh search";
      wormhole = "wormhole-rs";
      magic-wormhole = "wormhole-rs";
    };

    history = {
      size = 20000;
      save = 20000;
      share = true;
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "per-directory-history"
        "history-substring-search"
        "extract"
        "colored-man-pages"
        "archlinux"
        "docker-compose"
        "aliases"
      ];
      theme = "";
    };

    initContent = ''
      export LESS='-RFX --mouse'
      export HISTORY_BASE="$HOME/.local/state/zsh/history"
      # Persistently configure LD_LIBRARY_PATH for WSL2 GPU passthrough
      export LD_LIBRARY_PATH="/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:}''$LD_LIBRARY_PATH"
      # Initialize SSH agent forwarding from Windows to WSL
      eval "$(/usr/bin/wsl2-ssh-agent)"
      # Enable 'did you mean' command correction
      export ENABLE_CORRECTION="true"
      # Configure Typst font paths for NixOS/Home Manager
      export TYPST_FONT_PATHS="$HOME/.nix-profile/share/fonts:$HOME/.nix-profile/lib/X11/fonts"
    '';

    envExtra = ''
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
  };
  # programs.command-not-found disabled in favor of nix-index integration
  # Use nix-index for command-not-found suggestions with prebuilt databasef
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = false;
  };
  programs.carapace = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  # programs.atuin = {
  #   enable = true;
  #   enableZshIntegration = true;
  # 	settings = { auto_sync = false; }; # set true if you want sync
  # };
}
