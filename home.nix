{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkBefore mkMerge optionalAttrs optionalString;

  homeDir = config.home.homeDirectory;
  xdgConfigHome = config.xdg.configHome;
  profileDir = config.home.profileDirectory;
  isWsl = builtins.pathExists "/proc/sys/fs/binfmt_misc/WSLInterop";

  gitUserConf = "${xdgConfigHome}/git/user.conf";
  jjUserConf = "${xdgConfigHome}/jj/config.toml";
  wslVkIcd = "${xdgConfigHome}/vulkan/icd.d/nvidia_wsl.json";
  shellLdAppend = "$" + "{LD_LIBRARY_PATH:+:" + "$" + "{LD_LIBRARY_PATH}}";

  devenvWithUv = pkgs.writeShellApplication {
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

  home.username = "archliNix";
  home.homeDirectory = "/home/archliNix";
  home.stateVersion = "25.05";
  nixpkgs.config.allowUnfree = true;
  home.packages =
    (with pkgs; [
      # nix tools
      alejandra
      nh
      nixfmt
      nix-search-tv

      # secrets
      age
      magic-wormhole-rs
      sops

      # package managers and runtimes
      nodejs_24
      pnpm
      uv

      # cudaPackages.cuda_nvcc
      cudaPackages.cudatoolkit

      # Filesystem & search
      duf
      dust
      eza
      fd
      ncdu
      ripgrep

      # File content & data manipulation
      bat
      helix
      jq
      micro
      sd
      yq-go

      # System monitoring & info
      btop-cuda
      nvtopPackages.nvidia
      procs
      stress

      # Development & version control
      gh
      glab
      jujutsu

      # Network
      dnsutils
      openssh
      rsync
      tcping-rs
      uutils-coreutils-noprefix
      wget

      # Documentation
      tealdeer

      # gui apps
      tor-browser

      # other
      fastfetch
      marp-cli
      typst

      # fonts
      atkinson-hyperlegible
      dejavu_fonts
      nerd-fonts.jetbrains-mono
      noto-fonts-color-emoji
    ])
    ++ [devenvWithUv];

  sops = {
    age.keyFile = "${homeDir}/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets."example_secret" = {};
    secrets."github_private_mail" = {};
    secrets."github_private_name" = {};
    templates."example.env" = {
      content = ''
        EXAMPLE_SECRET=${config.sops.placeholder."example_secret"}
      '';
      path = "${homeDir}/.config/example/.env";
    };
    templates."git-user.conf" = {
      content = ''
        [user]
          name = ${config.sops.placeholder."github_private_name"}
          email = ${config.sops.placeholder."github_private_mail"}
      '';
      path = gitUserConf;
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
      path = jjUserConf;
    };
  };

  home.sessionVariables =
    {
      EDITOR = "nano";
      LANG = "C.UTF-8";
      LC_CTYPE = "C.UTF-8";
      PERL_BADLANG = "0";
      TYPST_FONT_PATHS = "${profileDir}/share/fonts:${profileDir}/lib/X11/fonts";
      UV_PYTHON_DOWNLOADS = "manual";
      VISUAL = "nano";
      # EDITOR = "emacs";
    }
    // optionalAttrs isWsl {
      VK_DRIVER_FILES = wslVkIcd;
    };

  home.sessionVariablesExtra = optionalString isWsl ''
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib${shellLdAppend}"
  '';

  # Ensure Nix profile binaries are on PATH for all shells (direnv, subshells, etc.)
  home.sessionPath = [
    "${profileDir}/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  xdg.enable = true;

  xdg.configFile =
    {
      "uv/uv.toml".text = ''
        python-downloads = "manual"
      '';
    }
    // optionalAttrs isWsl {
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
      {path = gitUserConf;}
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global = {
      warn_timeout = "0s"; # Don't warn about slow loading
      hide_env_diff = true; # Hides "export +VIRTUAL_ENV..."
    };
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

    initContent = mkMerge [
      (mkBefore ''
        # Detect Cursor or VS Code Agent execution
        if [[ -n "$ANTIGRAVITY_AGENT" ]] || [[ -n "$CURSOR_TRACE_ID" ]] || [[ "$TERM_PROGRAM" == "vscode" && -z "$TERM_PROGRAM_VERSION" ]]; then
          # Set a very simple prompt that robots love
          export PS1='%# '
          export PROMPT='%# '

          # Disable fancy features that confuse agents
          unset RPROMPT
          export TERM=xterm-256color
          export DIRENV_LOG_FORMAT=""

          # Explicitly unset handlers that might hang the agent
          unset -f command_not_found_handler 2>/dev/null || true

          # Stop processing the rest of the file (skips P10k, OhMyZsh, integrations)
          return
        fi
      '')

      ''
        export LESS='-RFX --mouse'
        export HISTORY_BASE="$HOME/.local/state/zsh/history"
        # Initialize SSH agent forwarding from Windows to WSL
        if ${if isWsl then "true" else "false"}; then
          if [ -x /usr/bin/wsl2-ssh-agent ]; then
            eval "$(/usr/bin/wsl2-ssh-agent)"
          fi
        fi
        # Enable 'did you mean' command correction
        export ENABLE_CORRECTION="true"

        # :: HUMAN MODE ::
        if [[ -z "$ANTIGRAVITY_AGENT" && -z "$CURSOR_TRACE_ID" ]]; then
          eval "$(starship init zsh)"
        else
          export PS1='%# '
          unset RPROMPT
        fi
      ''
    ];

    envExtra = ''
      if [ -f "${profileDir}/etc/profile.d/hm-session-vars.sh" ]; then
        . "${profileDir}/etc/profile.d/hm-session-vars.sh"
      fi
    '';
  };

  # programs.command-not-found disabled in favor of nix-index integration
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
    enableZshIntegration = false;
    settings.cmd_duration.disabled = true;
    settings.scan_timeout = 10;
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
}
