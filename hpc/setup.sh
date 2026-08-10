#!/usr/bin/env bash
# pi-hpc setup - run ON the HPC login node, from the bundle directory
# (the bundle is built with `nix build .#pi-hpc-bundle` and shipped by
# hpc/sync-to-hpc.sh).
#
# Usage:
#   bash setup.sh                          # node must already be installed
#   NODE_TARBALL=/path/node-v22.x-linux-x64.tar.xz bash setup.sh
#   PI_STAGE_TARBALL=/path/pi-stage.tgz bash setup.sh   # WSL-staged npm prefix
#   PI_VERSION=0.83.0 bash setup.sh        # pin pi (npm install path only)
#
# Idempotent: re-running updates config/rc, keeps keys.age and sessions.
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="$HOME/.pi"
PI_AGENT_DIR="$PI_DIR/agent"
NODE_PREFIX="$HOME/opt/node"
LOCAL_PREFIX="$HOME/.local"

# shellcheck source=bundle-info.sh
. "$BUNDLE_DIR/bundle-info.sh"

info() { printf '\033[1;36m[pi-hpc]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[pi-hpc]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[pi-hpc]\033[0m %s\n' "$*" >&2; exit 1; }

NODE_TARBALL="${NODE_TARBALL:-}"
PI_VERSION="${PI_VERSION:-latest}"

# --- 0. sanity --------------------------------------------------------------
info "host: $(uname -n) / $(uname -srm)"
GLIBC_VERSION="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo unknown)"
info "glibc: ${GLIBC_VERSION}"
if [ "$GLIBC_VERSION" != "unknown" ] && awk -v v="$GLIBC_VERSION" 'BEGIN { exit !(v < 2.28) }'; then
  warn "glibc < 2.28: official Node >= 22 tarballs need glibc 2.28;"
  warn "use a glibc-217 build from https://unofficial-builds.nodejs.org instead"
fi

# --- 1. node ----------------------------------------------------------------
if [ -n "$NODE_TARBALL" ]; then
  [ -f "$NODE_TARBALL" ] || die "node tarball not found: $NODE_TARBALL"
  mkdir -p "$NODE_PREFIX"
  case "$NODE_TARBALL" in
    *.tar.xz) tar -xJf "$NODE_TARBALL" -C "$NODE_PREFIX" --strip-components=1 ;;
    *.tar.gz | *.tgz) tar -xzf "$NODE_TARBALL" -C "$NODE_PREFIX" --strip-components=1 ;;
    *) die "unsupported node tarball format: $NODE_TARBALL (want node-v22.x-linux-x64.tar.xz)" ;;
  esac
  info "node installed: $("$NODE_PREFIX/bin/node" --version 2>/dev/null || echo FAILED)"
fi

NODE_BIN="$NODE_PREFIX/bin/node"
if [ -x "$NODE_BIN" ]; then
  NODE_VERSION="$("$NODE_BIN" --version 2>/dev/null || echo unknown)"
  if [ "$NODE_VERSION" != "unknown" ] && awk -v v="${NODE_VERSION#v}" 'BEGIN { exit !(v < 22.19) }'; then
    warn "node ${NODE_VERSION} < 22.19.0 - pi requires >= 22.19.0"
  fi
else
  warn "node not installed; download node-v22.x-linux-x64.tar.xz and rerun with NODE_TARBALL=..."
fi

# --- 2. pi binary ------------------------------------------------------------
if [ -n "${PI_STAGE_TARBALL:-}" ]; then
  [ -f "$PI_STAGE_TARBALL" ] || die "PI_STAGE_TARBALL not found: $PI_STAGE_TARBALL"
  mkdir -p "$LOCAL_PREFIX"
  tar -xzf "$PI_STAGE_TARBALL" -C "$LOCAL_PREFIX" --strip-components=1
  info "pi extracted from stage tarball into ~/.local (bin/ + lib/node_modules/)"
elif [ -x "$NODE_BIN" ]; then
  info "installing pi via npm: @earendil-works/pi-coding-agent@${PI_VERSION}"
  # npm's shebang is #!/usr/bin/env node, so node must be on PATH even though
  # this script uses absolute paths everywhere else (login-node default PATHs
  # don't include ~/opt/node/bin).
  PATH="$NODE_PREFIX/bin:$PATH" npm_config_prefix="$LOCAL_PREFIX" \
    "$(dirname "$NODE_BIN")/npm" install -g --ignore-scripts \
    "@earendil-works/pi-coding-agent@${PI_VERSION}"
else
  die "no node and no PI_STAGE_TARBALL - cannot install pi"
fi

# --- 3. pi agent config -------------------------------------------------------
info "laying out config under ~/.pi/agent ..."
rm -rf "$PI_AGENT_DIR/skills" "$PI_AGENT_DIR/prompts"   # refresh managed content
mkdir -p "$PI_AGENT_DIR/sessions"
cp -rL "$BUNDLE_DIR/pi-agent/." "$HOME/"
# Helper tools pi looks for in ~/.pi/agent/bin (getBinDir): fd/rg back its
# built-in find/grep tools, and age encrypts/decrypts keys.age. All are
# static binaries shipped in the bundle, so no download or pinentry is ever
# needed on the node. Remove the managed names first so dropped tools don't
# linger across syncs.
mkdir -p "$PI_AGENT_DIR/bin"
rm -f "$PI_AGENT_DIR/bin/fd" "$PI_AGENT_DIR/bin/rg" "$PI_AGENT_DIR/bin/age"
cp -rL "$BUNDLE_DIR/bin/." "$PI_AGENT_DIR/bin/"
info "helper tools in ~/.pi/agent/bin: $(ls "$PI_AGENT_DIR/bin" | tr '\n' ' ')"
# The bundle comes from the read-only nix store (555/444); make the copy
# owner-writable so re-runs of this script can refresh it.
chmod -R u+rwX "$PI_AGENT_DIR"
chmod 700 "$PI_DIR" "$PI_AGENT_DIR/sessions"
chmod -R go-rwx "$PI_DIR"
info "config in place (sessions dir is 0700, rest of ~/.pi is go-rwx)"

# --- 4. encrypted API keys -----------------------------------------------------
KEYS_FILE="$PI_DIR/keys.age"
if [ -f "$KEYS_FILE" ]; then
  info "keys.age exists - keeping it"
else
  # Prefer the bundle's static age binary: login nodes may lack `age`, and
  # gpg -c needs a pinentry which headless nodes don't have. Install it to
  # ~/.local/bin so pi-unlock keeps working in later shells too (rc.sh puts
  # ~/.local/bin on PATH).
  AGE_CMD=""
  if [ -x "$BUNDLE_DIR/bin/age" ]; then
    mkdir -p "$LOCAL_PREFIX/bin"
    cp "$BUNDLE_DIR/bin/age" "$LOCAL_PREFIX/bin/age"
    chmod 755 "$LOCAL_PREFIX/bin/age"
    AGE_CMD="$LOCAL_PREFIX/bin/age"
  elif command -v age >/dev/null 2>&1; then
    AGE_CMD="age"
  fi
  if [ -z "$AGE_CMD" ] && ! command -v gpg >/dev/null 2>&1; then
    warn "no 'age' (bundled or system) and no 'gpg' found - skipping keys.age;"
    warn "pi-unlock will be unavailable until you create it (see hpc/README.md)"
  else
    echo
    info "Creating $KEYS_FILE (passphrase-encrypted, never plaintext at rest)."
    info "Expected variables: $KEY_VARS"
    echo "Paste one 'export VAR=value' per line, then press Ctrl-D:"
    echo "(VAR=value and 'var: value' also work - names are case-insensitive)"
    echo "----------------------------------------------------------------"
    tmp="$(mktemp)" || die "mktemp failed"
    trap 'rm -f "$tmp" "$tmp.norm"' EXIT
    cat > "$tmp"
    [ -s "$tmp" ] || die "no input received - keys.age not created"
    # Normalize the paste to canonical `export VAR="value"` lines:
    #   export VAR=value   (documented form)
    #   VAR=value
    #   var: value         (sops-style lowercase names, as echoed by prompts)
    # opencode_go_api_key is aliased to OPENCODE_API_KEY - the env var pi
    # actually reads (see modules/pi.nix go.key).
    sed -E \
      -e 's/\r$//' \
      -e 's/^[[:space:]]*export[[:space:]]+//' \
      -e 's/^opencode_go_api_key[[:space:]]*:[[:space:]]*/opencode_api_key=/' \
      -e 's/^opencode_go_api_key=/opencode_api_key=/' \
      -e 's/^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*/\1=/' \
      -e 's/[[:space:]]+$//' \
      -e 's/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/export \U\1\E="\2"/' \
      "$tmp" > "$tmp.norm"
    # Keep only valid key lines; surface anything else so pastes errors are
    # visible before the file is encrypted.
    bad="$(grep -vE '^export [A-Za-z_][A-Za-z0-9_]*=.*$' "$tmp.norm" | grep -v '^[[:space:]]*$' || true)"
    if [ -n "$bad" ]; then
      warn "ignoring these lines (not key assignments):"
      printf '%s\n' "$bad" | sed 's/^/  /' >&2
    fi
    grep -E '^export [A-Za-z_][A-Za-z0-9_]*=.*$' "$tmp.norm" > "$tmp" \
      || die "no valid key lines in the input - keys.age not created"
    for var in $KEY_VARS; do
      grep -q "^export $var=" "$tmp" || warn "missing expected variable: $var"
    done
    if [ -n "$AGE_CMD" ]; then
      "$AGE_CMD" -p -o "$KEYS_FILE" < "$tmp" || die "age encryption failed"
    else
      # Last resort: gpg symmetric; requires a working pinentry on the node.
      gpg -c -o "$KEYS_FILE" < "$tmp" || die "gpg encryption failed (no pinentry? run setup again with the bundled age)"
    fi
    rm -f "$tmp" "$tmp.norm"
    trap - EXIT
    chmod 600 "$KEYS_FILE"
    info "keys.age created (0600). Run 'pi-unlock' in a shell to load the keys."
  fi
fi

# --- 5. shell rc hook ----------------------------------------------------------
cp "$BUNDLE_DIR/pi-hpc-rc.sh" "$PI_DIR/rc.sh"
chmod 600 "$PI_DIR/rc.sh"
HOOK='[ -f "$HOME/.pi/rc.sh" ] && . "$HOME/.pi/rc.sh"'
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if ! grep -qF 'pi/rc.sh' "$rc"; then
    printf '\n# pi-hpc: coding agent shell setup\n%s\n' "$HOOK" >> "$rc"
    info "rc hook appended to $rc"
  fi
done
info "rc installed at ~/.pi/rc.sh (sourced from .bashrc/.zshrc)"

# --- 6. wrap-up -----------------------------------------------------------------
PATH="$LOCAL_PREFIX/bin:$NODE_PREFIX/bin:$PATH" "$LOCAL_PREFIX/bin/pi" --version >/dev/null 2>&1 \
  && PI_VER="$("$LOCAL_PREFIX/bin/pi" --version 2>/dev/null)" \
  || PI_VER="(version check failed - is node on PATH in a new shell?)"
info "pi: $PI_VER"
echo
info "Next steps (in a NEW shell, or after 'source ~/.bashrc'):"
echo "  1. pi-unlock                        # enter the passphrase"
echo "  2. pi --version                     # sanity"
echo "  3. pi -p --no-skills 'reply with: OK'   # provider smoke test"
echo "  4. pi                               # interactive (Ctrl+P cycles models)"
echo "  Model presets: pi-fast, pi-deep, pi-plan, pi-build (see ~/.pi/rc.sh)"
echo "  Default model from the bundle: ${DEFAULT_MODEL}"
