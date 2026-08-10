#!/usr/bin/env bash
# Builds the pi-hpc bundle from the flake and ships it to the HPC login node.
# Run on the WSL side, after `home-manager switch` (or whenever pi.nix changed).
#
#   ./hpc/sync-to-hpc.sh [user@]host        # or set HPC=user@host
#   NODE_TARBALL=/path/node-v22.x-linux-x64.tar.xz ./hpc/sync-to-hpc.sh host
#
# Assumes Windows-side ~/.ssh/config multiplexing (see hpc/ssh-config.example):
# password/OTP is entered once, then scp/rsync/ssh reuse the connection.
set -euo pipefail

HPC_TARGET="${1:-${HPC:-}}"
[ -n "$HPC_TARGET" ] || {
  echo "usage: $0 [user@]host   (or export HPC=user@host)" >&2
  exit 1
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

info() { printf '\033[1;36m[sync-pi-hpc]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[sync-pi-hpc]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[sync-pi-hpc]\033[0m %s\n' "$*" >&2; exit 1; }

# --- build ------------------------------------------------------------------
info "building .#pi-hpc-bundle (--offline: inputs are already in the store;"
info "drop --offline if the flake inputs changed)"
nix build '.#pi-hpc-bundle' --offline

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
tar -C result -czf "$TMP_DIR/pi-hpc-bundle.tgz" .

# --- optional: ship a node tarball ------------------------------------------
REMOTE_NODE_TARBALL=""
if [ -n "${NODE_TARBALL:-}" ]; then
  [ -f "$NODE_TARBALL" ] || die "NODE_TARBALL not found: $NODE_TARBALL"
  NODE_TARBALL_NAME="$(basename "$NODE_TARBALL")"
  info "shipping node tarball -> ${HPC_TARGET}:~/${NODE_TARBALL_NAME}"
  scp -q "$NODE_TARBALL" "${HPC_TARGET}:${NODE_TARBALL_NAME}"
  # remote shell expands ~ in the ssh command below
  REMOTE_NODE_TARBALL="~/${NODE_TARBALL_NAME}"
fi

# --- sync ~/.claude/skills (referenced by settings.json skills path) --------
# Additive only: the HPC may hold extra skills (e.g. if claude code is
# installed there); stale entries are passive and harmless.
info "syncing ~/.claude/skills -> ${HPC_TARGET}:~/.claude/skills"
ssh -q "$HPC_TARGET" 'mkdir -p ~/.claude'
rsync -aL "$HOME/.claude/skills/" "${HPC_TARGET}:~/.claude/skills/"

# --- ship bundle + run setup --------------------------------------------------
info "shipping bundle -> ${HPC_TARGET}:~/pi-hpc-bundle.tgz"
scp -q "$TMP_DIR/pi-hpc-bundle.tgz" "${HPC_TARGET}:pi-hpc-bundle.tgz"

PI_VERSION="$(pi --version 2>/dev/null | head -1 || true)"
[ -n "$PI_VERSION" ] && info "pinning pi to the local version: ${PI_VERSION}"

ENV_ARGS="PI_VERSION='${PI_VERSION}'"
[ -n "$REMOTE_NODE_TARBALL" ] && ENV_ARGS="NODE_TARBALL=${REMOTE_NODE_TARBALL} ${ENV_ARGS}"

info "running setup on the HPC (interactive passphrase prompts may appear)..."
# shellcheck disable=SC2029
# The bundle tgz preserves the nix store's read-only perms (files 444, dirs
# 555), so a previously extracted tree must be made writable before rm -rf
# can remove it.
ssh -t "$HPC_TARGET" \
  "chmod -R u+w ~/pi-hpc-bundle 2>/dev/null || true; rm -rf ~/pi-hpc-bundle && mkdir -p ~/pi-hpc-bundle && tar -xzf ~/pi-hpc-bundle.tgz -C ~/pi-hpc-bundle && ${ENV_ARGS} bash ~/pi-hpc-bundle/setup.sh"

# Ship the runtime model catalog cache (opencode-go/deepseek/google model
# metadata fetched on the WSL side; not flake-managed, so it travels with the
# sync). If the HPC cannot reach the catalog endpoint, pi falls back to this
# cache; with full egress pi revalidates it via etag anyway. Must run after
# setup (which creates ~/.pi/agent).
info "shipping models-store.json cache -> ${HPC_TARGET}:~/.pi/agent/models-store.json"
scp -q "$HOME/.pi/agent/models-store.json" "${HPC_TARGET}:~/.pi/agent/models-store.json" \
  || warn "could not ship models-store.json (does ~/.pi/agent exist on the HPC?)"

info "done. Next: ssh $HPC_TARGET, then 'pi-unlock' and 'pi'."
