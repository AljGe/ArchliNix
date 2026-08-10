# pi on the HPC login node

Reuse the pi coding agent setup from `modules/pi.nix` on an HPC login node that
has **no Nix, no root, and ssh-key auth is not allowed** (password/OTP only).
The node is reached from VSCode/Cursor Remote-SSH on Windows through a barrier
node.

## How it works

`nix build .#pi-hpc-bundle` renders a self-contained bundle straight from the
**evaluated** home-manager config — `modules/pi.nix` stays the single source
of truth, and the bundle always matches the live model tiers, thinking levels,
skills and aliases:

```
result/
├── pi-agent/.pi/agent/   settings.json, models.json, skills/, prompts/
├── bin/                   static helper binaries: age, fd, rg
│                         (keys.age + pi-unlock; pi's find/grep tools)
├── pi-hpc-rc.sh          PATH, hardened env, pi-unlock, model aliases
├── bundle-info.sh        DEFAULT_MODEL + expected key vars (for setup.sh)
├── setup.sh              one-shot installer (run on the HPC)
└── README.md             this file
```

Included skills: youtube-transcript, brave-search, vscode (works: the
Remote-SSH server puts `code` on PATH in its terminal), vision (delegates to
Gemini). **browser-tools is excluded** — it needs a display (patched chromium
via CDP) and carries the largest vendored dependency (puppeteer). Remove the
exclusion in `modules/pi-hpc-bundle.nix` if you ever want it.

Secrets are excluded by construction: `auth.json` and the `*-key` files are
sops-nix templates, not `home.file` entries, so they never enter the bundle.
On the HPC, the API keys live **passphrase-encrypted** (`~/.pi/keys.age`) and
are loaded into the shell environment on demand via `pi-unlock` — pi reads
`DEEPSEEK_API_KEY` / `GEMINI_API_KEY` / `OPENCODE_API_KEY` /
`BRAVE_API_KEY` from env vars, so no plaintext auth.json is ever written
there (pi leaves `auth.json` as `{}` when keys come from the environment).
`pi-lock` unsets them again. The bundle ships a static `age` binary
(`bin/age`, installed to `~/.local/bin` by setup.sh) so key encryption and
`pi-unlock` never depend on `age` being present on the node — `gpg -c` is
only a last resort, as it needs a pinentry that headless login nodes lack.

**Important:** pi skips providers *without credentials* — including their
model catalogs. Run `pi-unlock` **before** starting pi, or the opencode-go
tier models will not resolve ("No models match pattern").

## One-time setup

1. **Windows `~/.ssh/config`** — copy `hpc/ssh-config.example` to
   `C:\Users\<you>\.ssh\config`, fill in the hostnames. The ControlMaster
   block makes the OTP prompt happen once per 8h; `scp`/`rsync`/`ssh` then
   multiplex over that connection. If the bastion refuses multiplexing,
   comment the `Control*` lines (everything still works, just re-prompts).

2. **Recon on the HPC** (in a Remote-SSH terminal):
   ```bash
   ldd --version          # glibc >= 2.28 ?  (decides the node tarball)
   uname -m               # x86_64 assumed
   curl -sI https://registry.npmjs.org   # npm reachable?
   curl -sI https://api.deepseek.com     # LLM API egress?
   env | grep -i proxy    # cluster proxy? (pi honors HTTPS_PROXY)
   ```
   Also check the cluster's acceptable-use policy: sending unpublished code
   to external LLM APIs may be restricted; if egress is blocked entirely,
   on-node pi won't work (fallback: run pi in WSL against remote files).

3. **Download a Node tarball** (on Windows/WSL):
   - glibc >= 2.28: `node-v22.x-linux-x64.tar.xz` from nodejs.org
   - older: `node-v22.x-linux-x64-glibc-217.tar.xz` from
     `https://unofficial-builds.nodejs.org/download/release/`

4. **Build + ship + install** (WSL side):
   ```bash
   ./hpc/sync-to-hpc.sh hpc                          # node already on HPC
   NODE_TARBALL=~/Downloads/node-v22.x-linux-x64.tar.xz ./hpc/sync-to-hpc.sh hpc
   ```
   This builds the bundle, syncs `~/.claude/skills`, scp's the bundle (and
   node tarball), and runs `setup.sh` on the HPC with `ssh -t`. During setup
   you paste the four key lines; it encrypts them into
   `~/.pi/keys.age` with a passphrase you choose. Any of these forms work
   (names are case-insensitive):

   ```
   export DEEPSEEK_API_KEY=sk-...
   gemini_api_key=AQ...
   brave_api_key: BSA-...
   ```

   `opencode_go_api_key` is automatically mapped to the `OPENCODE_API_KEY`
   env var pi actually reads.

5. **Smoke test** (new HPC shell, e.g. in VSCode Remote):
   ```bash
   pi-unlock                          # enter passphrase
   pi --version
   pi -p --no-skills 'reply with: OK'
   pi                                 # interactive; Ctrl+P cycles models
   ```
   Presets: `pi-fast`, `pi-deep`, `pi-plan`, `pi-build` (+ tier variants) —
   identical commands to the WSL aliases from `modules/pi.nix`.

## Daily sync

After any `home-manager switch` that touches pi config:

```bash
./hpc/sync-to-hpc.sh hpc
```

Idempotent: re-running refreshes config/rc, keeps `keys.age` and `sessions/`.

## If the HPC cannot reach registry.npmjs.org

Stage the pi install on WSL (your `~/.npmrc` guardrails apply — pin a pi
version older than 7 days) and ship it as a tarball:

```bash
V="$(pi --version)"                                   # pin the local version
npm install --global --prefix ~/.cache/hpc-pi-stage --ignore-scripts \
  "@earendil-works/pi-coding-agent@${V}"
tar -C ~/.cache/hpc-pi-stage -czf ~/pi-stage.tgz .
scp ~/pi-stage.tgz hpc:
# on the HPC:
#   PI_STAGE_TARBALL=~/pi-stage.tgz bash ~/pi-hpc-bundle/setup.sh
```

`setup.sh` extracts it into `~/.local` (bin/ + lib/node_modules/).

## Security notes

- **At rest:** the only key material on the HPC is `~/.pi/keys.age`
  (0600, passphrase-encrypted). `~/.pi` is chmod 700 / o-rwx, `sessions/`
  (full transcripts incl. code) is 0700.
- **While running:** root on the HPC can read `/proc/<pid>/environ` during a
  session — unavoidable on a shared system; `pi-lock` drops the vars when
  done. The realistic threats (other users, NFS backups/snapshots, accidental
  `git add`) are covered by the encrypted-at-rest design.
- **Startup traffic:** `PI_OFFLINE=1` + `PI_SKIP_VERSION_CHECK=1` disable
  update checks and telemetry on the HPC; provider API calls are unaffected.
- **Login-node etiquette:** pi itself is light, but keep heavy builds on
  compute nodes/batch queues.

## Troubleshooting

- `pi` warns "No models match pattern ..." → run `pi-unlock` first
  (unconfigured providers are skipped, catalog included). If keys are loaded
  and it still fails, egress to `opencode.ai` (catalog fetch) is blocked —
  the synced `models-store.json` cache covers that case.
- `pi` fails to start, clipboard errors → the optional `@mariozechner/clipboard`
  native module; harmless on headless nodes, pi degrades gracefully.
- `pi --version` works but the smoke test hangs/fails → egress to
  `api.deepseek.com` / `opencode.ai` / `generativelanguage.googleapis.com`
  is blocked; check cluster proxy docs (`HTTPS_PROXY` is honored by pi).
- `keys.age` creation fails with "gpg: problem with the agent: No pinentry"
  → the node has gpg but no pinentry (headless); the bundle's static `age`
  avoids this — if you ran setup.sh without a fresh bundle, rerun via
  `./hpc/sync-to-hpc.sh` or copy `result/bin/age` to `~/.local/bin/age`.
- `pi-unlock` errors like `deepseek_api_key:: command not found` → the
  stored keys use the old `name: value` format; re-sync — the bundled
  `pi-unlock` normalizes any stored format on the fly.
- Rotating an API key → on the HPC: `rm ~/.pi/keys.age`, then re-run
  `./hpc/sync-to-hpc.sh <host>` and paste the new keys (setup.sh keeps an
  existing keys.age, so it must be removed first).
- Node older than 22.19 → pi refuses; use a newer tarball.
- glibc < 2.28 → use the unofficial glibc-217 node build (see above).
- rsync/scp re-prompt for OTP every time → ControlMaster is not multiplexing
  (bastion limitation); everything still works, just slower.
