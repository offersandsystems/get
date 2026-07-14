# bootstrap.ps1 — HOP one-liner installer for fresh Windows machines.
# Breaks the bootstrap paradox: installs git, clones the repo, hands off to
# env\claude-env\setup-windows.ps1. Contains NOTHING sensitive — safe to publish.
#
# Source of truth: HOP repo env/claude-env/bootstrap.ps1.
# Published copy:  github.com/offersandsystems/get (public) — the client runs:
#
#   iwr -useb https://raw.githubusercontent.com/offersandsystems/get/main/bootstrap.ps1 | iex
#
# Overrides (set before invoking):
#   $env:HOP_BOOTSTRAP_ORG   (default: offersandsystems)
#   $env:HOP_BOOTSTRAP_REPO  (default: agents-HOP)
#   $env:HOP_BOOTSTRAP_DEST  (default: Desktop\PD; prompts if unset)
#   $env:HOP_BOOTSTRAP_MODE   ('dedicated' | 'personal'; if unset, auto-detects:
#                              no existing ~/.claude config -> dedicated silently;
#                              existing config -> asks keep (personal) or replace)
#   $env:HOP_BOOTSTRAP_LAUNCH ('no' skips the final Claude launch; for headless
#                              provisioning where ANTHROPIC_API_KEY is preset)

$ErrorActionPreference = 'Stop'

$Org  = if ($env:HOP_BOOTSTRAP_ORG)  { $env:HOP_BOOTSTRAP_ORG }  else { 'offersandsystems' }
$Repo = if ($env:HOP_BOOTSTRAP_REPO) { $env:HOP_BOOTSTRAP_REPO } else { 'agents-HOP' }

# Destination: Desktop\PD (Product Department) by default — visible, predictable.
# GetFolderPath handles OneDrive-redirected Desktops; env var skips the prompt.
$DefaultDest = Join-Path ([Environment]::GetFolderPath('Desktop')) 'PD'
$Dest = $env:HOP_BOOTSTRAP_DEST
if (-not $Dest) {
    $ans = Read-Host "Install location [$DefaultDest]"
    $Dest = if ([string]::IsNullOrWhiteSpace($ans)) { $DefaultDest } else { $ans.Trim() }
}

# Config mode by DETECTION, not interrogation. Fresh machine (no ~/.claude
# config) -> first agent here, full restore, no question. Existing config ->
# someone lives here (the user's own setup, or another agent employee) -> keep
# is the safe default; replacing is the exception. Covers personal laptops and
# multi-agent machines with the same rule. Override: HOP_BOOTSTRAP_MODE.
$Mode = $env:HOP_BOOTSTRAP_MODE
if (-not $Mode) {
    if (Test-Path (Join-Path $env:USERPROFILE '.claude\settings.json')) {
        $ans = Read-Host "Existing Claude config detected - [K]eep it (recommended) or [R]eplace with this agent's config? [K/r]"
        $Mode = if ($ans -match '^\s*r') { 'dedicated' } else { 'personal' }
    } else {
        $Mode = 'dedicated'   # fresh machine: full restore, silently
    }
}

Write-Host ''
Write-Host '== HOP bootstrap ==' -ForegroundColor Cyan
Write-Host "   repo: $Org/$Repo"
Write-Host "   dest: $Dest"
Write-Host "   mode: $Mode"
Write-Host ''

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# ---- 1. winget --------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error ('winget not found. Windows Server 2019/2022 does not ship it - ' +
        'install App Installer / winget-cli from ' +
        'https://github.com/microsoft/winget-cli/releases and rerun.')
}

# ---- 2. git ------------------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host '-- installing git...'
    winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements
    Update-SessionPath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error 'git installed but not yet on PATH - open a NEW terminal and rerun this one-liner.'
    }
} else {
    Write-Host '-- git present'
}

# ---- 3. clone ------------------------------------------------------------------
# Private repo: Git Credential Manager (ships with Git) opens a browser sign-in
# on first clone. Access is granted by OfferControl onboarding beforehand.
New-Item -ItemType Directory -Force $Dest | Out-Null
$RepoPath = Join-Path $Dest $Repo
if (Test-Path (Join-Path $RepoPath '.git')) {
    Write-Host "-- repo already cloned at $RepoPath"
} else {
    Write-Host "-- cloning $Org/$Repo (a browser window may open to sign in to GitHub)..."
    git clone "https://github.com/$Org/$Repo.git" $RepoPath
}

# ---- 4. per-clone git wiring ------------------------------------------------------
$hookSrc = Join-Path $RepoPath 'scripts\hooks\pre-push'
$hookDst = Join-Path $RepoPath '.git\hooks\pre-push'
if ((Test-Path $hookSrc) -and -not (Test-Path $hookDst)) {
    Copy-Item $hookSrc $hookDst
    Write-Host '-- installed pre-push guard'
}

# ---- 5. hand off to provisioning ------------------------------------------------
$setup = Join-Path $RepoPath 'env\claude-env\setup-windows.ps1'
if (-not (Test-Path $setup)) { Write-Error "setup script not found: $setup" }
Write-Host '-- handing off to setup-windows.ps1...'
$setupArgs = @{ Workspace = $RepoPath }
if ($Mode -eq 'personal') { $setupArgs.Personal = $true }
& $setup @setupArgs

# ---- 6. end in OPERATING state: onboarding (boot screen -> intake -> first asset) ----
Write-Host ''
Write-Host '== bootstrap complete ==' -ForegroundColor Cyan
Write-Host 'If you will commit: git config user.name "..." ; git config user.email "..."'
Write-Host ''

$launch = $env:HOP_BOOTSTRAP_LAUNCH
if ($launch -eq 'no') {
    Write-Host 'Launch skipped (HOP_BOOTSTRAP_LAUNCH=no). Headless auth: set ANTHROPIC_API_KEY.'
} elseif (Get-Command hop-claude -ErrorAction SilentlyContinue) {
    $ans = Read-Host 'Start HOP onboarding now? [Y/n]'
    if ($ans -notmatch '^\s*n') {
        Set-Location $RepoPath
        Write-Host '-- launching onboarding (first Claude launch will ask you to sign in + trust the workspace)...'
        hop-claude
    } else {
        Write-Host "Next: cd `"$RepoPath`" ; hop-claude   # boot screen + onboarding"
    }
} elseif (Get-Command claude -ErrorAction SilentlyContinue) {
    $ans = Read-Host 'Launch Claude now to sign in? [Y/n]'
    if ($ans -notmatch '^\s*n') {
        Set-Location $RepoPath
        Write-Host '-- launching Claude (sign in, then accept the workspace trust prompt)...'
        claude
    } else {
        Write-Host "Next: cd `"$RepoPath`" ; claude   # log in + accept workspace trust"
    }
} else {
    Write-Host "claude not on PATH yet - open a NEW terminal, then: cd `"$RepoPath`" ; hop-claude"
}
