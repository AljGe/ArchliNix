{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.my.colemakDH;
in
{
  options.my.colemakDH.enable = mkEnableOption "Colemak-DH remaps for CLI tools";

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      settings = {
        theme = "auto";
        keys = {
          normal = {
            n = "move_char_left";
            e = "move_visual_line_down";
            i = "move_visual_line_up";
            o = "move_char_right";
            N = "extend_char_left";
            E = "extend_visual_line_down";
            I = "extend_visual_line_up";
            O = "extend_char_right";
            l = "move_prev_word_start";
            y = "move_next_word_end";
            L = "extend_prev_word_start";
            Y = "extend_next_word_end";
            a = "goto_line_start";
            A = "extend_to_line_start";
            h = "goto_line_end";
            H = "extend_to_line_end";
            "A-o" = "page_down";
            "A-n" = "page_up";
            j = "insert_mode";
            k = "select_mode";
            u = "undo";
            U = "redo";
          };
          select = {
            n = "extend_char_left";
            e = "extend_visual_line_down";
            i = "extend_visual_line_up";
            o = "extend_char_right";
            l = "extend_prev_word_start";
            y = "extend_next_word_end";
            a = "extend_to_line_start";
            h = "extend_to_line_end";
            "A-o" = "page_down";
            "A-n" = "page_up";
          };
        };
      };
    };

    # Colemak-DH friendly bindings for fzf (only modifier keys to preserve typing)
    programs.fzf = {
      defaultOptions = [
        "--bind=alt-n:backward-char,alt-e:down,alt-i:up,alt-o:forward-char,alt-a:beginning-of-line,alt-h:end-of-line"
      ];
    };

    # Colemak-DH movements for zsh vi-mode (applies when vi-mode is enabled)
    programs.zsh.initContent = ''
      bindkey -M vicmd 'n' backward-char
      bindkey -M vicmd 'e' down-line-or-history
      bindkey -M vicmd 'i' up-line-or-history
      bindkey -M vicmd 'o' forward-char
      bindkey -M vicmd 'a' beginning-of-line
      bindkey -M vicmd 'h' end-of-line
    '';
  };
}
