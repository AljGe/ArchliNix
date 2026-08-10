{
  config,
  lib,
  pkgs,
  pkgs-unstable,
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
  geminiKeyFile = "${config.home.homeDirectory}/.config/opencode/gemini-key";
  modelId = last (splitString "/" cfg.model);

  # Build base json structure cleanly
  baseConfig = {
    "$schema" = "https://opencode.ai/config.json";
    inherit (cfg) model;

    plugin = if cfg.vision.enable then [ "opencode-vision" ] else [ ];

    agent = {
      build = {
        model = cfg.model;
      };
      plan = {
        model = cfg.model;
        variant = "deep";
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

    provider = {
      deepseek = {
        options = {
          apiKey = "{file:${deepseekKeyFile}}";
          baseURL = "https://api.deepseek.com/v1";
          timeout = 300000;
        };
        models.${modelId} = {
          options = {
            temperature = cfg.temperature;
            reasoningEffort = cfg.reasoning.effort;
          };
          interleaved = {
            field = "reasoning_content";
          };
          # Named reasoning variants selectable via /models or variant_cycle.
          # DeepSeek V4 Flash only supports "high" and "max".
          variants = {
            fast = {
              reasoningEffort = "high";
            };
            deep = {
              reasoningEffort = "max";
            };
          };
          # DeepSeek's API is text-only. Never advertise image input here:
          # opencode and the opencode-vision plugin use modalities to decide
          # which models can read images, and routing image input to DeepSeek
          # fails. Image reading is delegated to the image-reader agent
          # (cfg.vision.model / Gemini), not to the main model.
          modalities = {
            input = [ "text" ];
            output = [ "text" ];
          };
        };
      };
    }
    // (
      if cfg.vision.enable then
        {
          google = {
            options = {
              apiKey = "{file:${geminiKeyFile}}";
            };
          };
        }
      else
        { }
    );
  };
  opencodeJson = builtins.toJSON (lib.recursiveUpdate baseConfig cfg.extraConfig);
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

    reasoning = {
      effort = mkOption {
        type = types.enum [
          "high"
          "max"
        ];
        default = "max";
        description = ''
          Base DeepSeek reasoning effort applied as the model option. DeepSeek
          V4 Flash only supports "high" and "max". Named variants `fast`
          (high) and `deep` (max) are selectable via /models. The `plan` agent
          pins the `deep` variant by default; `build` uses this base effort and
          can be varied per-session.
        '';
      };
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

    vision = {
      enable = mkEnableOption "opencode-vision plugin and modality overrides";

      model = mkOption {
        type = types.str;
        default = "google/gemini-3.5-flash-lite";
        description = "Vision-capable backend model used by opencode-vision to parse images.";
      };
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra attrs merged into the generated opencode.json.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs-unstable.opencode ] ++ langPackages;

    sops.secrets."deepseek_api_key" = {
      path = deepseekKeyFile;
    };

    sops.secrets."gemini_api_key" = mkIf cfg.vision.enable {
      path = geminiKeyFile;
    };

    xdg.configFile."opencode/opencode.json" = {
      text = opencodeJson;
    };

    # Declarative subagent definition so DeepSeek can delegate image reading to Gemini
    xdg.configFile."opencode/agent/image-reader.md" = mkIf cfg.vision.enable {
      text = ''
        ---
        description: Analyzes images and screenshots using a multimodal vision model.
        mode: subagent
        model: ${cfg.vision.model}
        permission:
          read: allow
          glob: allow
          list: allow
          bash: deny
          edit: deny
        ---
        You are a vision analyst subagent. Read the image at the provided path using the `read` tool and describe its contents in detail.
      '';
    };
  };
}
