{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkBefore mkMerge;
  profileDir = config.home.profileDirectory;
  # Explicit boolean OR to avoid treating the default as a function
  isWsl = config.my.platform.isWsl or false;
in {
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
    defaultModel = "gemini-3-pro";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ff = "fzf";
      cl = "clear";
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
        if [ -x /usr/bin/wsl2-ssh-agent ]; then
          # Always try to init
          eval "$(/usr/bin/wsl2-ssh-agent)" > /dev/null

          # Restore correct sock path if eval failed or behaved weirdly
          if [[ -z "$SSH_AUTH_SOCK" ]]; then
            export SSH_AUTH_SOCK="$HOME/.ssh/wsl2-ssh-agent.sock"
          fi

          # Check for stale socket (Connection refused = 2)
          ssh-add -l >/dev/null 2>&1
          if [ $? -eq 2 ]; then
            rm -f "$SSH_AUTH_SOCK"
            eval "$(/usr/bin/wsl2-ssh-agent)" > /dev/null
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
