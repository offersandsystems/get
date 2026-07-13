# get

Public installer for the OAS / HOP agent stack. One line on a fresh Windows machine:

```powershell
iwr -useb https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap.ps1 | iex
```

What it does: verifies winget, installs git **only if missing**, clones the
(private) agent repo — GitHub sign-in opens in your browser; access is granted
by onboarding — installs the repo push guard, then hands off to the repo's own
provisioning script (Node, Claude Code, Python pipeline, document tooling).

You will be asked one question: **Dedicated** machine (fresh VPS — full config
restore) or **Personal** machine (your existing Claude setup stays untouched).

Contains no secrets. Access to the agent repo itself is gated by GitHub
permissions — this installer cannot grant them.

Source of truth: `env/claude-env/bootstrap.ps1` in the agent repo; this copy is
published from there. macOS/Linux routes coming with the CLI onboarding.
