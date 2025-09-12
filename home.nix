# ~/dotfiles/home.nix
{
  config,
  pkgs,
  ...
}:
let
  git-user-conf = "${config.home.homeDirectory}/.config/git/user.conf";
in
{
  home.username = "archliNix";
  home.homeDirectory = "/home/archliNix";
  home.stateVersion = "25.05";
  home.packages = with pkgs; [
    alejandra
    age
    sops
    bat
    tealdeer
    btop
    fastfetch
    ripgrep
    eza
    fzf
    devenv
    wget
    rsync
    pnpm
    nodejs_24
    openssh
    glab
    gh
    nh
    ncdu
    uv
    # gui apps~
    tor-browser
    librewolf
  ];

  home.file = {
  };

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
  };

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
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
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "eza --icons";
      ll = "eza -l --icons";
      la = "eza -la --icons";
      ".." = "cd ..";
      "..." = "cd ../..";
      ff = "fzf";
      cl = "clear";
      #cat = "bat";
      #grep = "rg";
      # make 'grep -R' work with ripgrep...
      switch-hm = "home-manager switch --flake ~/dotfiles/.#archliNix";
      switch-nh = "nh home switch ~/dotfiles/";
      switch-nhd = "nh home switch ~/dotfiles/ --dry";
      clean-nh = "nh clean user --keep-since 4d --keep 3";
      clean-nhd = "nh clean user --dry --keep-since 4d --keep 3";
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
      ];
      theme = "robbyrussell";
    };

    profileExtra = ''
      # Load the Nix environment
      if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
    '';

    initContent = ''
      export HISTORY_BASE="$HOME/.local/state/zsh/history"

      # Persistently configure LD_LIBRARY_PATH for WSL2 GPU passthrough
      export LD_LIBRARY_PATH="/usr/lib/wsl/lib''${LD_LIBRARY_PATH:+:}''$LD_LIBRARY_PATH"

      # Initialize SSH agent forwarding from Windows to WSL
      eval "$(/usr/bin/wsl2-ssh-agent)"
    '';
  };
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };
}
