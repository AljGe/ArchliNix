{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    foldl'
    concatMap
    splitString
    last
    filterAttrs
    attrNames
    ;

  cfg = config.my.opencode;

  languageConfig = {
    python = {
      packages = [
        pkgs.pyright
        pkgs.ruff
      ];
      lsp.pyright.command = [
        "pyright-langserver"
        "--stdio"
      ];
      formatter.ruff.command = [
        "ruff"
        "format"
        "$FILE"
      ];
    };
    typescript = {
      packages = [
        pkgs.typescript-language-server
        pkgs.prettier
      ];
      lsp.typescript.command = [
        "typescript-language-server"
        "--stdio"
      ];
      formatter.prettier.command = [
        "prettier"
        "--write"
        "$FILE"
      ];
    };
    nix = {
      packages = [
        pkgs.nixd
        pkgs.nixfmt
      ];
      lsp.nixd.command = [ "nixd" ];
      formatter.nixfmt.command = [
        "nixfmt"
        "$FILE"
      ];
    };
    kotlin = {
      packages = [
        pkgs.kotlin-language-server
        pkgs.kotlin
        pkgs.gradle
      ];
      lsp."kotlin-ls".command = [ "kotlin-language-server" ];
      formatter.ktlint.command = [
        "ktlint"
        "$FILE"
      ];
    };
  };

  enabledLanguages = filterAttrs (name: value: cfg.languages.${name}) languageConfig;
  enabledNames = attrNames enabledLanguages;

  langPackages = concatMap (name: enabledLanguages.${name}.packages) enabledNames;

  lspConfig = foldl' (acc: name: acc // enabledLanguages.${name}.lsp) { } enabledNames;

  formatterConfig = foldl' (acc: name: acc // enabledLanguages.${name}.formatter) { } enabledNames;

  deepseekKeyFile = "${config.home.homeDirectory}/.config/opencode/deepseek-key";
  modelId = last (splitString "/" cfg.model);

  opencodeJson = builtins.toJSON (
    {
      "$schema" = "https://opencode.ai/config.json";
      inherit (cfg) model;

      # 1. Map all OpenCode agents to DeepSeek V4 Flash
      agent = {
        build = {
          model = cfg.model;
        };
        plan = {
          model = cfg.model;
        };
        general = {
          model = cfg.model;
          mode = "subagent";
        };
        explore = {
          model = cfg.model;
          mode = "subagent";
        };
        scout = {
          model = cfg.model;
          mode = "subagent";
        };
      };

      lsp = lspConfig;
      formatter = formatterConfig;

      # 2. Fix DeepSeek V4 Flash API options and reasoning stream handling
      provider.deepseek = {
        options = {
          apiKey = "{file:${deepseekKeyFile}}";
          baseURL = "https://api.deepseek.com/v1";
          timeout = 90000; # Prevent timeouts when running 3+ subagents simultaneously
        };
        models.${modelId} = {
          options = {
            temperature = cfg.temperature;
          };
          interleaved = {
            field = "reasoning_content";
          };
        };
      };
    }
    // cfg.extraConfig
  );
in
{
  options.my.opencode = {
    enable = mkEnableOption "OpenCode AI coding assistant";

    model = mkOption {
      type = types.str;
      default = "deepseek/deepseek-v4-flash";
      description = "Default model used by all OpenCode primary and subagent workflows.";
    };

    temperature = mkOption {
      type = types.number;
      default = 0.2;
      description = "Sampling temperature for the DeepSeek model.";
    };

    languages = mkOption {
      type = types.attrsOf types.bool;
      default = {
        python = true;
        typescript = true;
        nix = true;
        kotlin = true;
      };
      description = "Enable OpenCode LSP/formatter toolchains per language.";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra attrs merged into the generated opencode.json.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.opencode ] ++ langPackages;

    sops.secrets."deepseek_api_key" = {
      path = deepseekKeyFile;
    };

    xdg.configFile."opencode/opencode.json" = {
      text = opencodeJson;
    };
  };
}
