#!/usr/bin/env bash
# bootstrap-linux.sh — HOP one-liner installer for fresh Debian/Ubuntu machines.
# Ensures git, clones the repo, installs the push guard, hands off to
# env/claude-env/setup-linux.sh. Contains NOTHING sensitive — safe to publish.
#
# Source of truth: HOP repo env/claude-env/bootstrap-linux.sh.
# Published copy:  github.com/offersandsystems/get — the client runs:
#
#   curl -fsSL https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap-linux.sh | sudo bash
#
# Overrides (env vars): HOP_BOOTSTRAP_ORG / _REPO / _DEST / _MODE / _LAUNCH
set -euo pipefail

ORG="${HOP_BOOTSTRAP_ORG:-offersandsystems}"
REPO="${HOP_BOOTSTRAP_REPO:-agents-HOP}"
# Running under sudo: install for the invoking user, not root.
RUN_USER="${SUDO_USER:-$(id -un)}"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
# Destination = THIS AGENT'S folder: repo contents land directly inside it.
DEST="${HOP_BOOTSTRAP_DEST:-$RUN_HOME/PD/$REPO}"

# Full install transcript -> install-log.txt in the PARENT of the agent folder
# (the folder itself must stay empty/absent for git clone; the parent collects
# one consolidated log across multiple agent installs).
DEST_PARENT="$(dirname "$DEST")"
mkdir -p "$DEST_PARENT" && chown "$RUN_USER" "$DEST_PARENT" 2>/dev/null || true
INSTALL_LOG="$DEST_PARENT/install-log.txt"
exec > >(tee -a "$INSTALL_LOG") 2>&1

echo ""
echo "== HOP bootstrap (linux) — $(date) =="
echo "   repo: $ORG/$REPO"
echo "   dest: $DEST"
echo "   log:  $INSTALL_LOG"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo (package installs need root):" >&2
    echo "  curl -fsSL <url> | sudo bash" >&2
    exit 1
fi

# ---- 1. git (only if missing) --------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
    echo "-- installing git..."
    apt-get update -qq && apt-get install -y -qq git
else
    echo "-- git present"
fi

# ---- 2. clone (as the real user; GCM is not present — HTTPS prompts or PAT) ------
# Repo contents go DIRECTLY into $DEST.
REPO_PATH="$DEST"
if [ -d "$REPO_PATH/.git" ]; then
    echo "-- repo already cloned at $REPO_PATH"
elif [ -d "$REPO_PATH" ] && [ -n "$(ls -A "$REPO_PATH" 2>/dev/null)" ]; then
    echo "Install folder exists and is not empty (and not a clone): $REPO_PATH - choose an empty or new folder." >&2
    exit 1
else
    echo "-- cloning $ORG/$REPO (sign in with your GitHub username + PAT when prompted)..."
    sudo -u "$RUN_USER" git clone "https://github.com/$ORG/$REPO.git" "$REPO_PATH"
fi

# ---- 3. per-clone git wiring -----------------------------------------------------
if [ -f "$REPO_PATH/scripts/hooks/pre-push" ] && [ ! -f "$REPO_PATH/.git/hooks/pre-push" ]; then
    sudo -u "$RUN_USER" cp "$REPO_PATH/scripts/hooks/pre-push" "$REPO_PATH/.git/hooks/pre-push"
    chmod +x "$REPO_PATH/.git/hooks/pre-push"
    echo "-- installed pre-push guard"
fi

# ---- 4. hand off to provisioning ---------------------------------------------------
SETUP="$REPO_PATH/env/claude-env/setup-linux.sh"
[ -f "$SETUP" ] || { echo "setup script not found: $SETUP" >&2; exit 1; }
SETUP_FLAGS=""
# Existing Claude config for the user -> keep it (personal mode) unless overridden.
if [ "${HOP_BOOTSTRAP_MODE:-}" = "personal" ] || { [ -z "${HOP_BOOTSTRAP_MODE:-}" ] && [ -f "$RUN_HOME/.claude/settings.json" ]; }; then
    echo "-- existing Claude config detected/requested: personal mode (config kept)"
    SETUP_FLAGS="--personal"
fi
echo "-- handing off to setup-linux.sh..."
bash "$SETUP" "$REPO_PATH" $SETUP_FLAGS

# ---- 5. end in OPERATING state ---------------------------------------------------------
echo ""
echo "== bootstrap complete == (log: $INSTALL_LOG)"
chown "$RUN_USER" "$INSTALL_LOG" 2>/dev/null || true
# Detach logging before the interactive agent session begins.
exec > /dev/tty 2>&1 || true
if [ "${HOP_BOOTSTRAP_LAUNCH:-}" = "no" ]; then
    echo "Launch skipped (HOP_BOOTSTRAP_LAUNCH=no). Headless auth: set ANTHROPIC_API_KEY."
elif [ -t 0 ] && sudo -u "$RUN_USER" bash -lc 'command -v hop-claude' >/dev/null 2>&1; then
    echo "Next: onboarding (first Claude launch asks you to sign in + trust the workspace)."
    cd "$REPO_PATH"
    exec sudo -u "$RUN_USER" bash -lc "cd '$REPO_PATH' && hop-claude"
else
    echo "Next: cd '$REPO_PATH' && hop-claude   # boot screen + onboarding"
    echo "Auth: run 'claude' and log in, or export ANTHROPIC_API_KEY (headless)."
fi
