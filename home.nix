{
  config,
  pkgs,
  ...
}: let
  git-user-conf = "${config.home.homeDirectory}/.config/git/user.conf";
  jj-user-conf = "${config.home.homeDirectory}/.config/jj/config.toml";
in {
  imports = [
    ./modules/colemak-dh.nix
    ./modules/librewolf.nix
  ];
  home.username = "archliNix";
  home.homeDirectory = "/home/archliNix";
  home.stateVersion = "25.05";
  home.packages = with pkgs; [
    # nix tools
    alejandra
    devenv
    nh
    nix-search-tv

    # secrets
    age
    sops

    # package managers and runtimes
    nodejs_24
    pnpm
    uv

    # Filesystem & search
    dust
    eza
    fd
    fzf
    ncdu
    duf
    ripgrep
    zoxide

    # File content & data manipulation
    micro
    helix
    bat
    jq
    sd
    yq-go

    # System monitoring & info
    btop-cuda
    fastfetch
    procs

    # Development & version control
    jujutsu
    gh
    glab

    # Network
    openssh
    rsync
    wget
    pings

    # Documentation
    tealdeer

    # gui apps
    tor-browser
  ];

  home.file = {};

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
    # EDITOR = "emacs";
  };

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  my.colemakDH.enable = true;

  programs.git = {
    enable = true;
    delta.enable = true;
    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
    };
    includes = [
      {path = git-user-conf;}
    ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
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
      ns="nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
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
        "command-not-found"
        "colored-man-pages"
        "archlinux"
        "direnv"
        "docker-compose"
        "aliases"
      ];
      theme = "robbyrussell";
    };

    profileExtra = ''
      # Load the Nix environment
      if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
      # Ensure UTF-8 locale for login shells (overrides system defaults)
      export LANG="C.UTF-8"
      export LC_CTYPE="C.UTF-8"
    '';

    initContent = ''
      export LESS='-RFX --mouse'
      export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git"
      # optional, beautiful man pages via bat (comment out if you prefer OMZ coloring)
      # export MANPAGER="sh -c 'col -bx | bat -l man -p'"
      bindkey "^R" fzf-history-widget

      export HISTORY_BASE="$HOME/.local/state/zsh/history"

      # Persistently configure LD_LIBRARY_PATH for WSL2 GPU passthrough
      export LD_LIBRARY_PATH="/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:}''$LD_LIBRARY_PATH"

      # Initialize SSH agent forwarding from Windows to WSL
      eval "$(/usr/bin/wsl2-ssh-agent)"
    '';


d    envExtra = ''
      # Silence Perl locale warnings
      export PERL_BADLANG=0
      if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
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
