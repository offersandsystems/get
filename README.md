# get

Public installers for the OAS / HOP agent stack. One line on a fresh machine:

**Windows** (PowerShell — type `powershell` first if you're in Command Prompt):

```powershell
irm https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap.ps1 | iex
```

**macOS** (no sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap-macos.sh | bash
```

**Linux** (Debian/Ubuntu):

```bash
curl -fsSL https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap-linux.sh | sudo bash
```

What they do: verify the package manager, install git **only if missing**, clone
the (private) agent repo — GitHub sign-in required; access is granted by
onboarding — install the repo push guard, then hand off to the repo's own
provisioning script (Node, Claude Code, HOP CLI, Python pipeline, document
tooling).

On a fresh machine everything configures silently. If an existing Claude setup
is detected, you're asked whether to keep it (recommended — the agent stays
project-scoped) or replace it. Each installer finishes by launching HOP
onboarding: boot screen → "What do you want to do?" → asset creation.

Contains no secrets. Access to the agent repo itself is gated by GitHub
permissions — these installers cannot grant them.

Source of truth: `env/claude-env/bootstrap*` in the agent repo; these copies are
published from there (BOM-less for the pipe-to-shell path).
