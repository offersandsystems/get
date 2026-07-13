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
#   $env:HOP_BOOTSTRAP_DEST  (default: %USERPROFILE%\PD)
#   $env:HOP_BOOTSTRAP_MODE  ('dedicated' | 'personal'; prompts if unset)

$ErrorActionPreference = 'Stop'

$Org  = if ($env:HOP_BOOTSTRAP_ORG)  { $env:HOP_BOOTSTRAP_ORG }  else { 'offersandsystems' }
$Repo = if ($env:HOP_BOOTSTRAP_REPO) { $env:HOP_BOOTSTRAP_REPO } else { 'agents-HOP' }
$Dest = if ($env:HOP_BOOTSTRAP_DEST) { $env:HOP_BOOTSTRAP_DEST } else { Join-Path $env:USERPROFILE 'PD' }

# Machine type decides whether global ~/.claude config is restored (dedicated
# VPS) or left untouched (personal machine with its own Claude setup).
$Mode = $env:HOP_BOOTSTRAP_MODE
if (-not $Mode) {
    $ans = Read-Host 'Machine type: [D]edicated (fresh VPS - full config restore) or [P]ersonal (keep my existing Claude config)? [D/p]'
    $Mode = if ($ans -match '^\s*p') { 'personal' } else { 'dedicated' }
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

# ---- 6. what remains manual ---------------------------------------------------------
Write-Host ''
Write-Host '== bootstrap complete ==' -ForegroundColor Cyan
Write-Host 'Remaining manual steps:'
Write-Host "  1. cd `"$RepoPath`""
Write-Host '  2. claude          # log in + accept workspace trust'
Write-Host '  3. git config user.name "..." ; git config user.email "..."   # if you will commit'
