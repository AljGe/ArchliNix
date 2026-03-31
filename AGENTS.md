# AGENTS.md

## Environment
- OS: WSL2 Linux
- Package managers are intentionally hardened with minimum package age limits.
- Do not remove or relax these defaults unless the user explicitly asks.

## Package Age Guardrails
- `npm`: `~/.npmrc` uses:
  - `min-release-age=7`
  - `ignore-scripts=true`
- `pnpm`: `~/.config/pnpm/rc` uses:
  - `minimum-release-age=10080` (7 days, minutes)
- `uv`: `~/.config/uv/uv.toml` uses:
  - `exclude-newer = "7 days"`
- `bun`: `~/.config/bunfig.toml` uses:
  - `minimumReleaseAge = 604800` (7 days, seconds)

## Agent Behavior Requirements
- If install/resolve fails, first suspect minimum-age policy before trying random retries.
- Identify which package is blocked and report it clearly.
- Offer safe options in this order:
  1. Use an older allowed version.
  2. Wait until package age policy allows it.
  3. Ask user whether to temporarily relax policy for this task.
- Never silently disable security settings.
- Avoid repeated install loops that ignore the same policy error.

## Troubleshooting Checklist
1. Read the exact resolver/install error.
2. Confirm whether the failing version is too new for current policy.
3. Pin to the newest version that satisfies age constraints.
4. Re-run install once with the adjusted version.
5. If still blocked, escalate with a concise explanation and options.
