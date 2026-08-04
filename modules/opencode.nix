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

  # Per-language toolchain: runtime/LSP/formatter packages plus the
  # opencode LSP and formatter entries that point at the nix-installed binaries.
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

  # DeepSeek API key lives in a sops-managed file; opencode's {file:...}
  # substitution reads it at runtime, so no key material ever lands in config.
  deepseekKeyFile = "${config.home.homeDirectory}/.config/opencode/deepseek-key";
  modelId = last (splitString "/" cfg.model);

  opencodeJson = builtins.toJSON (
    {
      "$schema" = "https://opencode.ai/config.json";
      inherit (cfg) model;
      lsp = lspConfig;
      formatter = formatterConfig;
      provider.deepseek = {
        options.apiKey = "{file:${deepseekKeyFile}}";
        models.${modelId}.options.temperature = cfg.temperature;
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
      description = "Default model used by OpenCode.";
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
