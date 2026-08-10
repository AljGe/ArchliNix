{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  pi-skills,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    recursiveUpdate
    splitString
    head
    last
    optional
    concatStringsSep
    listToAttrs
    mkDefault
    mkMerge
    map
    unique
    ;

  cfg = config.my.pi;

  homeDir = config.home.homeDirectory;
  piAgentDir = "${homeDir}/.pi/agent";

  provider = head (splitString "/" cfg.model);
  modelId = last (splitString "/" cfg.model);

  # Tier entry type: an opencode-go model id plus the pi thinking level pinned
  # for it (Ctrl+P scoped entries and the per-tier zsh aliases).
  goTierModel = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "opencode-go model id as served by the Zen gateway.";
      };
      level = mkOption {
        type = types.enum [
          "off"
          "minimal"
          "low"
          "medium"
          "high"
          "xhigh"
          "max"
        ];
        description = "Thinking level pinned for this model (Ctrl+P and aliases).";
      };
    };
  };

  # Level lookup tables so aliases always track the configured tiers.
  goTierLevels = tier: listToAttrs (map (m: {
    name = m.id;
    value = m.level;
  }) tier.models);
  planningLevels = goTierLevels cfg.go.planning;
  buildLevels = goTierLevels cfg.go.build;

  # Models served by the Zen gateway (https://opencode.ai/zen/go/v1/models)
  # that pi 0.83.0's built-in opencode-go catalog does not ship. Custom models
  # are upserted into the built-in provider by id (models.md merge semantics),
  # so no provider block beyond `models` is needed.
  goCatalogAdditions = {
    providers."opencode-go".models = [
      {
        id = "qwen3.8-max";
        name = "Qwen3.8 Max";
        api = "anthropic-messages";
        baseUrl = "https://opencode.ai/zen/go";
        reasoning = true;
        input = [ "text" ];
        cost = {
          input = 2.0;
          output = 6.0;
          cacheRead = 0.25;
          cacheWrite = 2.5;
        };
        contextWindow = 1000000;
        maxTokens = 65536;
        # Adaptive thinking with effort "max" (sent via forceAdaptiveThinking).
        # Verify the Zen endpoint accepts effort "max"; if it errors, map
        # max -> "high" here (or drop the map to fall back to budget thinking).
        compat.forceAdaptiveThinking = true;
        thinkingLevelMap = {
          xhigh = null;
          max = "max";
        };
      }
      {
        id = "gpt-5.6-luna";
        name = "GPT 5.6 Luna";
        api = "openai-responses";
        baseUrl = "https://opencode.ai/zen/go/v1";
        reasoning = true;
        input = [ "text" "image" ];
        cost = {
          input = 0.2;
          output = 1.2;
          cacheRead = 0.02;
          cacheWrite = 0.25;
          tiers = [
            {
              inputTokensAbove = 272000;
              input = 0.4;
              output = 1.8;
              cacheRead = 0.04;
              cacheWrite = 0.5;
            }
          ];
        };
        # Conservative: matches the 272K pricing tier split. Raise after a
        # real request confirms the Zen-served context window.
        contextWindow = 272000;
        maxTokens = 131072;
      }
    ];
  };

  # Declarative skill derivations from the pinned pi-skills repo
  # (https://github.com/badlogic/pi-skills). Skill directories are read-only
  # store symlinks, so any npm dependency must be vendored at build time.
  #
  # youtube-transcript-plus 1.2.0 is the latest 1.x matching the skill's
  # ^1.0.4 range; it is a zero-dependency ESM package, so vendoring the
  # tarball directly avoids running npm entirely.
  youtubeTranscriptDep = pkgs.fetchurl {
    url = "https://registry.npmjs.org/youtube-transcript-plus/-/youtube-transcript-plus-1.2.0.tgz";
    sha256 = "12hn2cy8ljxi1zw9z8mcmbnvc42v35akw18j6qgx7ymlvqwkq9ix";
  };

  youtubeTranscriptSkill = pkgs.runCommand "pi-skill-youtube-transcript" { } ''
    mkdir -p $out/node_modules/youtube-transcript-plus
    cp -r ${pi-skills}/youtube-transcript/. $out/
    tar -xzf ${youtubeTranscriptDep} -C $out/node_modules/youtube-transcript-plus --strip-components=1
  '';

  braveSearchSkill = pkgs.buildNpmPackage {
    pname = "pi-skill-brave-search";
    version = "1.0.0";
    src = "${pi-skills}/brave-search";
    npmDepsHash = "sha256-E6EJKin0ATPlZp9MYxeg5S5kay0x+2J1zQnkTtBQwc0=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r $src/. $out/
      cp -r node_modules $out/
    '';
  };

  # browser-tools: the upstream launch script hardcodes macOS paths
  # (/Applications/Google Chrome.app/... and ~/Library/Application
  # Support/Google/Chrome/), so patch in the nix-provided browser binary and
  # the Linux profile directory before vendoring the npm deps.
  browserToolsCfg = cfg.extras.piSkills.browserTools;
  browserPackage =
    {
      chromium = pkgs.chromium;
      google-chrome = pkgs.google-chrome;
      brave = pkgs.brave;
    }
    .${browserToolsCfg.browser};
  browserBinary =
    {
      chromium = "${browserPackage}/bin/chromium";
      google-chrome = "${browserPackage}/bin/google-chrome-stable";
      brave = "${browserPackage}/bin/brave";
    }
    .${browserToolsCfg.browser};
  browserProfileDir =
    {
      chromium = ".config/chromium/";
      google-chrome = ".config/google-chrome/";
      brave = ".config/BraveSoftware/Brave-Browser/";
    }
    .${browserToolsCfg.browser};

  patchedBrowserStartJs =
    builtins.replaceStrings
      [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        "Library/Application Support/Google/Chrome/"
        # WSL2: no user namespaces (browser sandbox) and crashpad ptrace dies;
        # add the launch flags chromium needs here.
        ''"--no-first-run",''
      ]
      [
        browserBinary
        browserProfileDir
        ''
          "--no-sandbox",
          		"--disable-breakpad",
          		"--no-first-run",''
      ]
      (builtins.readFile "${pi-skills}/browser-tools/browser-start.js");

  browserToolsSrc = pkgs.runCommand "pi-skill-browser-tools-src" { } ''
    mkdir -p $out
    cp -r ${pi-skills}/browser-tools/. $out/
    rm -f $out/browser-start.js
    cat > $out/browser-start.js <<'EOF'
    ${patchedBrowserStartJs}
    EOF
    chmod +x $out/browser-start.js
  '';

  browserToolsSkill = pkgs.buildNpmPackage {
    pname = "pi-skill-browser-tools";
    version = "1.0.0";
    src = browserToolsSrc;
    npmDepsHash = "sha256-CRCAVRYM6v7aPnj+F5pLGw7pYNdO3YSSFhGbxVAPW8A=";
    dontNpmBuild = true;
    # The skill only connects to a CDP endpoint on :9222; puppeteer's bundled
    # Chrome download (run by `npm rebuild`) is unnecessary and flaky in
    # sandboxes.
    env = {
      PUPPETEER_SKIP_DOWNLOAD = "true";
    };
    installPhase = ''
      mkdir -p $out
      cp -r $src/. $out/
      cp -r node_modules $out/
    '';
  };

  # Base settings merged with cfg.extraSettings
  baseSettings = {
    defaultProvider = provider;
    defaultModel = modelId;
    defaultThinkingLevel = cfg.reasoning.effort;
    # Pi scopes models by (provider, id) only: a second pattern for the same
    # model with a different thinking level is silently deduped (model-resolver
    # uses modelsAreEqual = id + provider). So Ctrl+P cycles *models*; the
    # `:fast` pin sets the level you land on. Switch to deep-max with
    # Shift+Tab (cycles high/max, or off if you want thinking disabled) or the
    # `pi-deep` alias. The scope
    # itself can be edited at runtime with /scoped-models (Ctrl+S saves).
    enabledModels = unique (
      [
        "${provider}/${modelId}:${cfg.reasoning.fast}"
      ]
      # All Go tier models with their pinned thinking levels, so Ctrl+P cycles
      # the whole hierarchy: planning (kimi-k3 -> qwen3.8-max -> grok-4.5 ->
      # glm-5.2) and build (deepseek-v4-flash, kimi-k2.7-code). unique()
      # collapses the default-model entry above when it is also a tier entry
      # (opencode-go/deepseek-v4-flash:high appears in both).
      ++ (if cfg.go.enable then
        map (m: "opencode-go/${m.id}:${m.level}") (cfg.go.planning.models ++ cfg.go.build.models)
      else
        [ ])
      ++ optional cfg.vision.enable cfg.vision.model
    );
    terminal = {
      showImages = cfg.terminal.showImages;
    };
    # Reuse skills maintained for Claude Code/Cursor (Agent Skills standard);
    # descriptions are loaded on demand via progressive disclosure.
    skills = cfg.skills.paths ++ map (name: "!${name}") cfg.skills.exclude;
    quietStartup = cfg.settings.quietStartup;
    enableInstallTelemetry = !cfg.settings.disableTelemetry;
    defaultProjectTrust = cfg.settings.defaultProjectTrust;
    hideThinkingBlock = cfg.settings.hideThinkingBlock;
    # Stream-drop resilience: pi 0.83.0 classifies "Stream ended without
    # finish_reason" as a retryable provider error (the message matches the
    # "ended without" pattern in pi-ai's retry classifier), so a cut write
    # stream auto-restarts the turn with exponential backoff instead of
    # leaving the harness mid-tool-call. retry.provider.maxRetries stays at
    # its default 0: provider-level retries would mask Go usage-limit errors.
    retry = {
      enabled = cfg.settings.retry.enabled;
      maxRetries = cfg.settings.retry.maxRetries;
      baseDelayMs = cfg.settings.retry.baseDelayMs;
      provider = {
        timeoutMs = cfg.settings.providerTimeoutMs;
      };
    };
    # Compaction triggers when contextTokens > contextWindow - reserveTokens.
    # Doubling the default headroom keeps room for long write-tool payloads
    # plus deep reasoning, and compacts earlier so provider-side context
    # truncation (a common cause of streams that end without finish_reason)
    # never kicks in.
    compaction = {
      reserveTokens = cfg.settings.compactionReserveTokens;
    };
  };
  settingsJson = builtins.toJSON (recursiveUpdate baseSettings cfg.extraSettings);

  # DeepSeek V4 models only support reasoning efforts high/max. Map pi
  # thinking levels to provider values and hide unsupported levels. `off`
  # stays selectable: DeepSeek cannot actually disable thinking, but the
  # model clamps rather than errors, so it is a harmless escape hatch.
  # temperature is ignored by DeepSeek thinking mode but kept for parity with
  # the opencode module. `thinkingLevelMap` merges over the runtime model
  # catalog, so values not listed here fall back to the catalog's defaults.
  #
  # The overrides are applied to the default model on BOTH carriers: the
  # preferred opencode-go provider and the direct deepseek provider (kept as
  # the uncapped fallback), so behavior is identical whichever one serves
  # the model. Assumes cfg.model is a DeepSeek V4 model.
  baseModels = {
    providers.deepseek.modelOverrides.${modelId} = {
      input = [ "text" ];
      thinkingLevelMap = {
        minimal = null;
        low = null;
        medium = null;
        high = "high";
        xhigh = null;
        max = "max";
      };
      samplingParams = {
        temperature = cfg.temperature;
      };
    };
    providers."opencode-go".modelOverrides.${modelId} = {
      input = [ "text" ];
      thinkingLevelMap = {
        minimal = null;
        low = null;
        medium = null;
        high = "high";
        xhigh = null;
        max = "max";
      };
      samplingParams = {
        temperature = cfg.temperature;
      };
    };
  };
  modelsJson = builtins.toJSON (recursiveUpdate
    (recursiveUpdate baseModels (if cfg.go.enable then goCatalogAdditions else { }))
    cfg.extraModels);

  # Auth entries assembled from sops placeholders. The secrets themselves are
  # declared by modules/opencode.nix (this module falls back to declaring them
  # if opencode is disabled, see config below).
  authEntries = [
    ''"deepseek": { "type": "api_key", "key": "${config.sops.placeholder."deepseek_api_key"}" }''
  ]
  ++ optional cfg.vision.enable ''"google": { "type": "api_key", "key": "${
    config.sops.placeholder."gemini_api_key"
  }" }''
  ++ optional cfg.go.enable ''"opencode-go": { "type": "api_key", "key": "${
    config.sops.placeholder."opencode_go_api_key"
  }" }'';

  # Default prompt templates: declarative slash commands (`/name` in the pi
  # editor). `/plan` mirrors the opencode `plan` agent: deep reasoning,
  # no edits, output a plan and wait.
  defaultPrompts = [
    {
      name = "plan";
      description = "Analyze the task and produce a detailed implementation plan without editing files";
      text = ''
        Analyze the task thoroughly. Do not edit any files.
        Produce a concise, ordered implementation plan: files to change, key
        functions, verification steps, and risks. Then stop and wait for approval.
      '';
    }
    {
      name = "review";
      description = "Review staged git changes";
      text = ''
        Review the staged changes (`git diff --cached`). Focus on:
        - Bugs and logic errors
        - Security issues
        - Error handling gaps
      '';
    }
    {
      name = "commit";
      description = "Write a conventional commit message for staged changes";
      argumentHint = "[scope]";
      text = ''
        Write a single conventional commit message for the staged changes
        (git diff --cached --stat). Use imperative mood, no trailing period,
        keep the subject under 72 characters.
      '';
    }
  ];

  selectedPrompts = (if cfg.prompts.enableDefault then defaultPrompts else [ ]) ++ cfg.prompts.extra;

  promptFrontmatter =
    p:
    concatStringsSep "\n" (
      [
        "---"
        "description: ${p.description}"
      ]
      ++ optional ((p.argumentHint or null) != null) "argument-hint: \"${p.argumentHint}\""
      ++ [
        "---"
        ""
      ]
    );

  promptFiles = listToAttrs (
    map (p: {
      name = ".pi/agent/prompts/${p.name}.md";
      value = {
        text = ''
          ${promptFrontmatter p}${p.text}
        '';
      };
    }) selectedPrompts
  );

  # Capability-aware vision skill: pi's `read` tool gates images by the active
  # model's `input` modalities - multimodal models get the image inline,
  # text-only models get an explicit "image omitted" note instead. The skill
  # therefore probes with `read` first and only delegates to the vision
  # backend (Gemini, which does not consume Go quota) when the image did not
  # come through. No static model list to maintain.
  visionSkillText = ''
    ---
    name: vision
    description: Analyzes images and screenshots using a vision-capable model. Use when the user pastes or attaches an image, references a screenshot, or asks to visually verify, describe, or read something in an image.
    ---

    # Vision

    The active coding model may or may not be able to read images. Decide based on what the `read` tool returns - never guess from the model name.

    ## Steps

    1. Determine the image path: prefer the `@file` path the user attached, else ask the user for the path.
    2. Call the `read` tool on the image path. pi gates the result by the active model's capabilities:
       - The model supports images (e.g. kimi-k2.7-code, kimi-k3, grok-4.5, minimax-m3, qwen3.7-plus, mimo-v2.5): the tool result contains the rendered image - analyze it directly and answer the user.
       - Text-only model (e.g. deepseek-v4-flash, glm-5.2, qwen3.8-max): the result contains a note like "[Current model does not support images. The image will be omitted from this request.]" and no image data.
    3. Only if no image data came through, run the image through the vision backend model, appending the user's specific question when one exists:

    ```bash
    pi -p --no-skills -nt --no-context-files --model ${cfg.vision.model} @<image-path> "Describe this image in exhaustive detail: visible text, UI elements, layout, colors, error messages, code, and any anomalies. If the user asked a specific question about the image, answer it after describing the image."
    ```

    4. Relay the vision model's description into the conversation and answer the user's question based on it.

    ## Notes

    - Multimodal models never need this fallback; the `read` tool passes images through natively.
    - Always pass `--no-skills` so the vision call does not recurse into this skill.
    - `-nt` disables all tools so the vision call is purely a text/image exchange.
    - `--no-context-files` skips AGENTS.md/CLAUDE.md injection in the one-shot call.
  '';
in
{
  options.my.pi = {
    enable = mkEnableOption "Pi coding agent (pi.dev)";

    model = mkOption {
      type = types.str;
      default = "opencode-go/deepseek-v4-flash";
      description = ''
        Default model used by Pi. The ID has no date suffix: deepseek-v4-flash
        always serves the latest revision. Served via the OpenCode Go
        subscription (opencode-go provider) by preference; the same model on
        the direct deepseek provider stays configured as the uncapped
        fallback when Go usage caps are hit.
      '';
    };

    temperature = mkOption {
      type = types.number;
      default = 0.2;
      description = "Sampling temperature sent via samplingParams. DeepSeek thinking mode ignores temperature.";
    };

    reasoning = {
      effort = mkOption {
        type = types.enum [
          "high"
          "max"
        ];
        default = "high";
        description = ''
          Base DeepSeek reasoning effort used as the default pi thinking
          level — the `fast` preset (fast-high). DeepSeek V4 Flash only
          supports high/max.
        '';
      };

      fast = mkOption {
        type = types.enum [
          "high"
          "max"
        ];
        default = "high";
        description = ''
          Reasoning effort pinned to the DeepSeek entry in enabledModels:
          Ctrl+P always lands on this level (fast-high).
        '';
      };

      deep = mkOption {
        type = types.enum [
          "high"
          "max"
        ];
        default = "max";
        description = ''
          Reasoning effort for the `deep` preset (deep-max). Pi dedupes
          Ctrl+P scoped entries by model, so a second entry cannot be added;
          reach deep-max via Shift+Tab (cycles off/high/max) or the
          `pi-deep` alias / `pi --model opencode-go/deepseek-v4-flash:max`.
        '';
      };
    };

    terminal.showImages = mkOption {
      type = types.bool;
      default = false;
      description = "Render images inline in the terminal. WSL2/Windows Terminal lacks Kitty graphics support.";
    };

    vision = {
      enable = mkEnableOption "vision skill that delegates image analysis to a vision-capable Gemini model";

      model = mkOption {
        type = types.str;
        default = "google/gemini-3.5-flash-lite";
        description = "Vision-capable backend model used by the vision skill.";
      };
    };

    # OpenCode Go subscription (https://opencode.ai/go): one API key, flat
    # $10/mo, ~18 open coding models via the Zen gateway. Usage is capped in
    # dollars ($12/5h, $30/wk, $60/mo) with per-model allotments, so the tier
    # ranking below doubles as a cost budget: expensive models are for
    # deliberate planning sessions, the cheap ones for the daily grind.
    #
    # Capability ranking and how we arrived at it:
    #   kimi-k3:max      - strongest reasoning of the Go lineup; 1M ctx,
    #                      multimodal. pi's catalog exposes ONLY max thinking
    #                      (every other level is null), so it pins :max by
    #                      construction. Small $15/mo allotment (~490 req/mo).
    #   qwen3.8-max:max  - Qwen flagship; $2/$6 premium pricing, 1M ctx.
    #                      Pinned :max (effort "max" via adaptive thinking;
    #                      verify the Zen endpoint accepts it - fallback is
    #                      max -> "high" in models.json). $15 allotment.
    #   grok-4.5:high    - xAI flagship; 500K ctx, multimodal. pi's catalog
    #                      caps its thinking at high (max is null) - :high is
    #                      its ceiling, not a budget choice. $15 allotment.
    #   glm-5.2:high     - supports high AND max, but pinned :high on purpose:
    #                      its $60 allotment (~4,300 req/mo) is the largest of
    #                      the tier, so it is the resilient default planner;
    #                      escalate to kimi-k3/qwen3.8-max when the problem
    #                      demands more reasoning.
    #   deepseek-v4-flash:high - build tier workhorse: $0.14/$0.28, ~31k
    #                      req/mo, text-only (vision delegates, see the vision
    #                      skill). Default build model.
    #
    # Switching when a model hits its limit: Ctrl+P cycles the tier entries
    # (each pinned to its level), /model fuzzy-switches mid-session, or exit
    # and `pi --continue --model opencode-go/<sibling>:<level>` to resume the
    # same session on another model of the same tier. When the whole Go
    # subscription is capped, direct DeepSeek remains the uncapped fallback:
    # `pi --model deepseek/deepseek-v4-flash:<level>` or /model -> deepseek
    # provider (the deepseek auth entry and key are kept for this reason).
    go = {
      enable = mkEnableOption "OpenCode Go subscription (opencode-go provider)";

      key = mkOption {
        type = types.str;
        default = "opencode_go_api_key";
        description = "sops secret holding the OpenCode Go API key (from opencode.ai/auth).";
      };

      planning = {
        default = mkOption {
          type = types.str;
          default = "glm-5.2";
          description = ''
            Model used by the `pi-plan` alias; must be one of `planning.models`.
            Defaults to glm-5.2: the largest usage allotment of the planning
            tier makes it the most limit-resilient default; escalate with
            pi-plan-k3 / pi-plan-qwen / pi-plan-grok.
          '';
        };

        models = mkOption {
          type = types.listOf goTierModel;
          default = [
            {
              id = "kimi-k3";
              level = "max";
            }
            {
              id = "qwen3.8-max";
              level = "max";
            }
            {
              id = "grok-4.5";
              level = "high";
            }
            {
              id = "glm-5.2";
              level = "high";
            }
          ];
          description = ''
            High-level planning tier, ordered by capability (see the comment
            above the `go` option for the ranking rationale). Every entry is
            added to Ctrl+P cycling and gets a pi-plan-<name> alias.
          '';
        };
      };

      build = {
        default = mkOption {
          type = types.str;
          default = "deepseek-v4-flash";
          description = ''
            Model used by the `pi-build` alias; must be one of `build.models`.
          '';
        };

        models = mkOption {
          type = types.listOf goTierModel;
          default = [
            {
              id = "deepseek-v4-flash";
              level = "high";
            }
            {
              id = "kimi-k2.7-code";
              level = "high";
            }
          ];
          description = ''
            Normal tier for building and delegated sub-tasks.
            deepseek-v4-flash is the text-only default workhorse;
            kimi-k2.7-code is the multimodal build option (reads images
            natively, no vision fallback needed).
          '';
        };
      };
    };

    settings = {
      quietStartup = mkOption {
        type = types.bool;
        default = false;
        description = "Hide the pi startup header.";
      };

      disableTelemetry = mkOption {
        type = types.bool;
        default = false;
        description = "Opt out of the anonymous install/update ping (enableInstallTelemetry=false).";
      };

      disableUpdateCheck = mkOption {
        type = types.bool;
        default = false;
        description = "Set PI_SKIP_VERSION_CHECK=1. Pi is flake-pinned; the pi.dev version check only adds startup network traffic.";
      };

      defaultProjectTrust = mkOption {
        type = types.enum [
          "ask"
          "always"
          "never"
        ];
        default = "ask";
        description = "Fallback behavior for projects with project-local .pi/ resources when no trust decision is saved.";
      };

      providerTimeoutMs = mkOption {
        type = types.ints.positive;
        default = 900000;
        description = ''
          Provider request timeout (retry.provider.timeoutMs). This bounds
          time-to-first-byte only: the OpenAI/Anthropic SDKs clear it once
          headers arrive and the stream body is uncapped. 15 minutes gives
          buffering gateways (e.g. Zen) room to start streaming long
          generations that would exceed a 5-minute first-byte cap.
        '';
      };

      retry = {
        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Agent-level retry on transient provider errors (retry.enabled).";
        };

        maxRetries = mkOption {
          type = types.ints.positive;
          default = 4;
          description = ''
            Maximum agent-level retry attempts per failed turn
            (retry.maxRetries). pi treats "Stream ended without
            finish_reason" as retryable, so a dropped write stream is
            auto-restarted with exponential backoff. Default 4 (2s, 4s, 8s,
            16s) vs pi's stock 3.
          '';
        };

        baseDelayMs = mkOption {
          type = types.ints.positive;
          default = 2000;
          description = "Base delay for retry exponential backoff (retry.baseDelayMs: 2s, 4s, 8s...).";
        };
      };

      compactionReserveTokens = mkOption {
        type = types.ints.positive;
        default = 32768;
        description = ''
          Tokens reserved for the LLM response before auto-compaction
          triggers (compaction.reserveTokens). Doubled from pi's 16384
          default: long write payloads plus deep reasoning need more
          headroom, and compacting earlier keeps the provider-side context
          below truncation limits (server-side truncation surfaces as
          streams that end without finish_reason).
        '';
      };

      hideThinkingBlock = mkOption {
        type = types.bool;
        default = false;
        description = "Hide DeepSeek thinking blocks in the transcript.";
      };
    };

    skills = {
      paths = mkOption {
        type = types.listOf types.str;
        default = [ "~/.claude/skills" ];
        description = ''
          Skill directories merged into settings.json `skills`. Paths are
          resolved relative to ~/.pi/agent; absolute paths and `~` are
          supported. ~/.cursor/skills is intentionally not included by
          default: it mirrors ~/.claude/skills, and duplicate names warn.
        '';
      };

      exclude = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Skill names to hide from the directories in `paths`. Each entry is
          emitted as a `!<name>` exclusion pattern in settings.json `skills`;
          pi matches it against each skill's directory name, so entries are
          the directory names under the skills root (e.g. `cloudflare`,
          `wrangler`). Use this to drop a subset of skills from a shared
          directory (like the Cloudflare skills in ~/.claude/skills) without
          touching the directory itself.
        '';
      };
    };

    prompts = {
      enableDefault = mkOption {
        type = types.bool;
        default = true;
        description = "Install the default prompt templates: /plan, /review, /commit.";
      };

      extra = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Slash command name (filename without .md).";
              };
              description = mkOption {
                type = types.str;
                description = "Shown in the / autocomplete dropdown.";
              };
              argumentHint = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional argument hint shown before the description in autocomplete.";
              };
              text = mkOption {
                type = types.str;
                description = "Template body. Supports $1, $2, $@, ${"1:-default"} argument expansion.";
              };
            };
          }
        );
        default = [ ];
        description = "Additional prompt templates written to ~/.pi/agent/prompts.";
      };
    };

    extras = {
      # Skills from the pinned badlogic/pi-skills repo. Intentionally not
      # installed:
      #   transcribe - current upstream is macOS-arm64 only (parakeet binary)
      #   gccli/gdcli/gmcli - not in nixpkgs and need per-API Google Cloud
      #     Console setup + interactive OAuth; install manually if desired.
      piSkills = {
        youtubeTranscript = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Install the youtube-transcript skill (fetch YouTube video
              transcripts). Zero external dependencies; the single npm
              dependency is vendored at build time.
            '';
          };
        };

        braveSearch = {
          enable = mkEnableOption ''
            brave-search skill (web search via the Brave Search API). Adds a
            sops-managed BRAVE_API_KEY. Requires a free Brave Search API
            subscription and network access at build time (npm deps are
            vendored via buildNpmPackage).
          '';
        };

        vscode = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Install the vscode skill (open diffs/file comparisons in VS
              Code via `code -d`). Zero dependencies, but requires the
              `code` CLI in PATH (e.g. VS Code for Windows on WSL).
            '';
          };
        };

        browserTools = {
          enable = mkEnableOption ''
            browser-tools skill (interactive browser automation via Chrome
            DevTools Protocol). The launch script is patched from macOS to
            the browser selected in `browser`; npm deps (puppeteer etc.) are
            vendored at build time and the browser is added to
            home.packages. Needs a display (WSLg provides one) and rsync.
          '';

          browser = mkOption {
            type = types.enum [
              "chromium"
              "google-chrome"
              "brave"
            ];
            default = "chromium";
            description = ''
              Browser backend used by browser-tools. `chromium` is free and
              sufficient for CDP automation; `google-chrome` and `brave`
              match a regular browsing profile (profile is copied with
              browser-start.js --profile).
            '';
          };
        };
      };
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra attrs merged into ~/.pi/agent/settings.json.";
    };

    extraModels = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra attrs merged into ~/.pi/agent/models.json.";
    };
  };

  config = mkIf cfg.enable {
    # The option default prefers the opencode-go carrier; without the Go
    # subscription the direct DeepSeek provider takes over as default.
    my.pi.model = mkIf (!cfg.go.enable) (mkDefault "deepseek/deepseek-v4-flash");

    home.packages = [
      pkgs-unstable.pi-coding-agent
    ]
    ++ optional cfg.extras.piSkills.browserTools.enable browserPackage
    # Chromium fatals on text render without any fonts; the WSL font group is
    # trimmed, so install a minimal font set for the browser.
    ++ optional cfg.extras.piSkills.browserTools.enable pkgs.dejavu_fonts
    ++ optional cfg.extras.piSkills.browserTools.enable pkgs.noto-fonts-color-emoji;

    # Named reasoning presets as interactive zsh aliases, served via the
    # preferred opencode-go provider:
    #   pi-fast -> pi --model opencode-go/deepseek-v4-flash:high  (fast-high)
    #   pi-deep -> pi --model opencode-go/deepseek-v4-flash:max   (deep-max)
    # If the Go subscription is capped, the same models on the direct deepseek
    # provider remain available: pi --model deepseek/deepseek-v4-flash:<level>.
    programs.zsh.shellAliases = {
      "pi-fast" = "pi --model ${cfg.model}:${cfg.reasoning.fast}";
      "pi-deep" = "pi --model ${cfg.model}:${cfg.reasoning.deep}";
    }
    // (if cfg.go.enable then {
      # Normal tier. pi-build is the everyday workhorse (uncapped direct
      # DeepSeek, same model/price as Go but without Go's usage caps).
      "pi-build" = "pi --model opencode-go/${cfg.go.build.default}:${buildLevels.${cfg.go.build.default}}";
      "pi-build-kimi" = "pi --model opencode-go/kimi-k2.7-code:${buildLevels."kimi-k2.7-code"}";
      # Planning tier. pi-plan defaults to glm-5.2 (largest allotment = most
      # limit-resilient); escalate when a model hits its cap or the problem
      # demands more reasoning.
      "pi-plan" = "pi --model opencode-go/${cfg.go.planning.default}:${planningLevels.${cfg.go.planning.default}}";
      "pi-plan-k3" = "pi --model opencode-go/kimi-k3:${planningLevels."kimi-k3"}";
      "pi-plan-qwen" = "pi --model opencode-go/qwen3.8-max:${planningLevels."qwen3.8-max"}";
      "pi-plan-grok" = "pi --model opencode-go/grok-4.5:${planningLevels."grok-4.5"}";
      "pi-plan-glm" = "pi --model opencode-go/glm-5.2:${planningLevels."glm-5.2"}";
    } else { });

    home.sessionVariables = mkIf cfg.settings.disableUpdateCheck {
      PI_SKIP_VERSION_CHECK = "1";
    };

    # Own the sops secret declarations only when modules/opencode.nix does not,
    # so the two modules never conflict over `sops.secrets.<name>.path`.
    sops.secrets."deepseek_api_key" = mkIf (!config.my.opencode.enable) {
      path = "${piAgentDir}/deepseek-key";
    };
    sops.secrets."gemini_api_key" =
      mkIf (cfg.vision.enable && !(config.my.opencode.enable && config.my.opencode.vision.enable))
        {
          path = "${piAgentDir}/gemini-key";
        };
    sops.secrets."brave_api_key" = mkIf cfg.extras.piSkills.braveSearch.enable {
      path = "${piAgentDir}/brave-key";
    };
    # OpenCode Go key. Owned here (pi uses it via auth.json); if opencode.nix
    # ever adds Go parity it must take ownership, same pattern as deepseek.
    sops.secrets."opencode_go_api_key" = mkIf cfg.go.enable {
      path = "${piAgentDir}/opencode-go-key";
    };

    sops.templates."pi-agent-auth" = {
      content = ''
        {
          ${concatStringsSep ",\n  " authEntries}
        }
      '';
      path = "${piAgentDir}/auth.json";
      mode = "0600";
    };

    # sops placeholders are only substituted inside templates, so the
    # brave-search env var is sourced from the decrypted key file at shell
    # startup instead of being injected at build time.
    home.sessionVariablesExtra = mkIf cfg.extras.piSkills.braveSearch.enable ''
      export BRAVE_API_KEY="$(cat ${piAgentDir}/brave-key)"
    '';

    home.file = mkMerge [
      {
        ".pi/agent/settings.json".text = settingsJson;

        ".pi/agent/models.json".text = modelsJson;
      }
      (mkIf cfg.vision.enable {
        # Declarative vision skill: probes the active model via the `read`
        # tool (pi natively gates images by model.input) and only delegates
        # to Gemini via a one-shot `pi -p` subprocess when the model is
        # text-only (pi has no built-in subagents).
        ".pi/agent/skills/vision/SKILL.md".text = visionSkillText;
      })
      (mkIf cfg.extras.piSkills.youtubeTranscript.enable {
        ".pi/agent/skills/pi-skills/youtube-transcript" = {
          source = youtubeTranscriptSkill;
        };
      })
      (mkIf cfg.extras.piSkills.braveSearch.enable {
        ".pi/agent/skills/pi-skills/brave-search" = {
          source = braveSearchSkill;
        };
      })
      (mkIf cfg.extras.piSkills.vscode.enable {
        ".pi/agent/skills/pi-skills/vscode" = {
          source = "${pi-skills}/vscode";
        };
      })
      (mkIf cfg.extras.piSkills.browserTools.enable {
        ".pi/agent/skills/pi-skills/browser-tools" = {
          source = browserToolsSkill;
        };
      })
      (mkIf (selectedPrompts != [ ]) promptFiles)
    ];
  };
}
