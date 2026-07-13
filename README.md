# get

Public installer for the OAS / HOP agent stack. One line on a fresh Windows machine:

```powershell
iwr -useb https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap.ps1 | iex
```

What it does: verifies winget, installs git **only if missing**, clones the
(private) agent repo — GitHub sign-in opens in your browser; access is granted
by onboarding — installs the repo push guard, then hands off to the repo's own
provisioning script (Node, Claude Code, Python pipeline, document tooling).

On a fresh machine it configures everything silently. If an existing Claude
setup is detected, it asks whether to keep it (recommended — the agent stays
project-scoped) or replace it. It finishes by launching Claude to sign in.

Contains no secrets. Access to the agent repo itself is gated by GitHub
permissions — this installer cannot grant them.

Source of truth: `env/claude-env/bootstrap.ps1` in the agent repo; this copy is
published from there. macOS/Linux routes coming with the CLI onboarding.
