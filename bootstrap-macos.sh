#!/usr/bin/env bash
# bootstrap-macos.sh — HOP one-liner installer for fresh Macs.
# Ensures git (via Xcode CLT / Homebrew bootstrap in setup), clones the repo,
# installs the push guard, hands off to env/claude-env/setup-macos.sh.
# Contains NOTHING sensitive — safe to publish.
#
# Source of truth: HOP repo env/claude-env/bootstrap-macos.sh.
# Published copy:  github.com/offersandsystems/get — the client runs:
#
#   curl -fsSL https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap-macos.sh | bash
#
# NO sudo — Homebrew (installed by setup) refuses root.
# Overrides (env vars): HOP_BOOTSTRAP_ORG / _REPO / _DEST / _MODE / _LAUNCH
set -euo pipefail

if [ "$(uname)" != "Darwin" ]; then
    echo "This installer is for macOS. Linux: bootstrap-linux.sh · Windows: bootstrap.ps1" >&2
    exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "Do not run with sudo — Homebrew must run as a normal user." >&2
    exit 1
fi

ORG="${HOP_BOOTSTRAP_ORG:-offersandsystems}"
REPO="${HOP_BOOTSTRAP_REPO:-agents-HOP}"
# Destination = THIS AGENT'S folder: repo contents land directly inside it.
DEST="${HOP_BOOTSTRAP_DEST:-$HOME/PD/$REPO}"

# Full install transcript -> install-log.txt in the PARENT of the agent folder
# (the folder itself must stay empty/absent for git clone; the parent collects
# one consolidated log across multiple agent installs).
DEST_PARENT="$(dirname "$DEST")"
mkdir -p "$DEST_PARENT"
INSTALL_LOG="$DEST_PARENT/install-log.txt"
exec > >(tee -a "$INSTALL_LOG") 2>&1

echo ""
echo "== HOP bootstrap (macOS) — $(date) =="
echo "   repo: $ORG/$REPO"
echo "   dest: $DEST"
echo "   log:  $INSTALL_LOG"
echo ""

# ---- 1. git (macOS: first git use triggers the Xcode CLT install dialog) ---------
if ! command -v git >/dev/null 2>&1; then
    echo "-- git not found: triggering Xcode Command Line Tools install (a dialog will open)..."
    xcode-select --install 2>/dev/null || true
    echo "   Complete the dialog, then RE-RUN this one-liner."
    exit 0
else
    echo "-- git present"
fi

# ---- 2. clone ----------------------------------------------------------------------
# Repo contents go DIRECTLY into $DEST.
REPO_PATH="$DEST"
if [ -d "$REPO_PATH/.git" ]; then
    echo "-- repo already cloned at $REPO_PATH"
elif [ -d "$REPO_PATH" ] && [ -n "$(ls -A "$REPO_PATH" 2>/dev/null)" ]; then
    echo "Install folder exists and is not empty (and not a clone): $REPO_PATH - choose an empty or new folder." >&2
    exit 1
else
    echo "-- cloning $ORG/$REPO (sign in with your GitHub username + PAT when prompted)..."
    git clone "https://github.com/$ORG/$REPO.git" "$REPO_PATH" || {
        echo "git clone failed - see git's message above. Common causes: destination not empty, no repo access, cancelled sign-in." >&2
        exit 1
    }
fi

# ---- 3. per-clone git wiring ----------------------------------------------------------
if [ -f "$REPO_PATH/scripts/hooks/pre-push" ] && [ ! -f "$REPO_PATH/.git/hooks/pre-push" ]; then
    cp "$REPO_PATH/scripts/hooks/pre-push" "$REPO_PATH/.git/hooks/pre-push"
    chmod +x "$REPO_PATH/.git/hooks/pre-push"
    echo "-- installed pre-push guard"
fi

# ---- 4. hand off to provisioning ---------------------------------------------------------
SETUP="$REPO_PATH/env/claude-env/setup-macos.sh"
[ -f "$SETUP" ] || { echo "setup script not found: $SETUP" >&2; exit 1; }
SETUP_FLAGS=""
if [ "${HOP_BOOTSTRAP_MODE:-}" = "personal" ] || { [ -z "${HOP_BOOTSTRAP_MODE:-}" ] && [ -f "$HOME/.claude/settings.json" ]; }; then
    echo "-- existing Claude config detected/requested: personal mode (config kept)"
    SETUP_FLAGS="--personal"
fi
echo "-- handing off to setup-macos.sh..."
bash "$SETUP" "$REPO_PATH" $SETUP_FLAGS

# ---- 5. end in OPERATING state --------------------------------------------------------------
echo ""
echo "== bootstrap complete == (log: $INSTALL_LOG)"
# Detach logging before the interactive agent session begins.
exec > /dev/tty 2>&1 || true
if [ "${HOP_BOOTSTRAP_LAUNCH:-}" = "no" ]; then
    echo "Launch skipped (HOP_BOOTSTRAP_LAUNCH=no). Headless auth: set ANTHROPIC_API_KEY."
elif [ -t 0 ] && command -v hop-claude >/dev/null 2>&1; then
    echo "Next: onboarding (first Claude launch asks you to sign in + trust the workspace)."
    cd "$REPO_PATH" && exec hop-claude
else
    echo "Next: cd '$REPO_PATH' && hop-claude   # boot screen + onboarding"
    echo "Auth: run 'claude' and log in, or export ANTHROPIC_API_KEY (headless)."
fi
