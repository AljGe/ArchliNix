# ~/dotfiles/home.nix

{ config, pkgs, ... }: {
  home.username = "archliNix";
  home.homeDirectory = "/home/archliNix";
  home.stateVersion = "25.05";
  home.packages = with pkgs; [
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
  ];

  home.file = {
  };


  sops = {
    age.keyFile = "/home/archliNix/.config/sops/age/keys.txt";
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets."example_secret" = { };
  };


  home.sessionVariables = {
    # EDITOR = "emacs";
  };  
 
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    userName = "example name";
    userEmail = "your.email@example.com";
    aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
    };
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
      #cat = "bat";
      #grep = "rg";
      # make 'grep -R' work with ripgrep...
      update-hm = "home-manager switch --flake ~/dotfiles/.#archliNix";
      update-nh = "nh home switch ~/dotfiles/";
      clean-nh = "nh clean user --keep-since 4d --keep 3";
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
