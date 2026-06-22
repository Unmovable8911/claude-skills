# setup.ps1 — Install, update, or uninstall Kilian's Claude Code skills (Windows)
#
# Usage:
#   .\setup.ps1 install [-Project] [-Skill a b] [-Category engineering]
#   .\setup.ps1 update  [-Project]
#   .\setup.ps1 uninstall [-KeepRepo]
#
# First-time install via PowerShell:
#   irm https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.ps1 | iex

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('install', 'update', 'uninstall', '')]
    [string]$Command = 'install',

    [switch]$All,
    [string[]]$Skill,
    [string]$Category,
    [switch]$Project,
    [string]$RepoUrl,
    [switch]$KeepRepo,
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DEFAULT_REPO_URL = 'https://github.com/Unmovable8911/claude-skills.git'
$script:DEFAULT_REPO_DIR = Join-Path $HOME '.agent\kilians-skills'

$script:SKILL_NAMES = @()
$script:SKILL_DIRS = @()
$script:SKILL_DESCS = @()

$script:RUN_CONTEXT = ''
$script:SCRIPT_DIR = ''
$script:TARGET_DIR = ''

# ── Colors ─────────────────────────────────────────────────────

function Write-Info($Message) {
    Write-Host ':: ' -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Ok($Message) {
    Write-Host 'ok ' -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn($Message) {
    Write-Host '!! ' -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err($Message) {
    Write-Host "** $Message" -ForegroundColor Red
}

# ── Platform helpers ───────────────────────────────────────────

function Test-SymlinkPrivilege {
    $testDir = $script:TARGET_DIR
    $testSrc = Join-Path $env:TEMP "symtest-src-$PID"
    $testLink = Join-Path $testDir ".symlink-test-$PID"

    New-Item -ItemType Directory -Path $testSrc -Force | Out-Null
    try {
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testSrc -ErrorAction Stop | Out-Null
        Remove-Item $testLink -Force
        return $true
    }
    catch {
        Write-Err 'Symlink creation failed. Enable Developer Mode or run as Administrator.'
        Write-Err '  Settings > Update & Security > For developers > Developer Mode'
        return $false
    }
    finally {
        Remove-Item $testSrc -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ── Run context ────────────────────────────────────────────────

function Detect-RunContext {
    $invocation = $MyInvocation.PSCommandPath
    if (-not $invocation) { $invocation = $PSCommandPath }

    if ($invocation -and (Test-Path $invocation)) {
        $dir = Split-Path $invocation -Parent
        if (Test-Path (Join-Path $dir 'skills.json')) {
            $script:RUN_CONTEXT = 'local'
            $script:SCRIPT_DIR = $dir
            return
        }
    }

    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'skills.json'))) {
        $script:RUN_CONTEXT = 'local'
        $script:SCRIPT_DIR = $PSScriptRoot
        return
    }

    $script:RUN_CONTEXT = 'remote'
}

# ── Prerequisites ──────────────────────────────────────────────

function Check-Prerequisites {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Err 'git is required but not installed.'
        exit 1
    }
}

# ── JSON parsing ──────────────────────────────────────────────

function Parse-SkillsJson($JsonFile) {
    if (-not (Test-Path $JsonFile)) {
        Write-Err "skills.json not found at $JsonFile"
        exit 1
    }

    $script:SKILL_NAMES = @()
    $script:SKILL_DIRS = @()
    $script:SKILL_DESCS = @()

    $json = Get-Content $JsonFile -Raw | ConvertFrom-Json
    foreach ($entry in $json) {
        $script:SKILL_NAMES += $entry.name
        $script:SKILL_DIRS += $entry.directory
        $script:SKILL_DESCS += $entry.description
    }
}

# ── Filtering ─────────────────────────────────────────────────

function Test-SkillFilter($Name, $Dir) {
    $cat = ($Dir -split '/')[0]

    if ($Skill -and $Category) {
        if ($Skill -contains $Name) { return $true }
        if ($cat -eq $Category) { return $true }
        return $false
    }

    if ($Skill) {
        return ($Skill -contains $Name)
    }

    if ($Category) {
        return ($cat -eq $Category)
    }

    if ($All) {
        return $true
    }

    return ($Name -eq 'setup-kilians-skills')
}

# ── Symlink operations ────────────────────────────────────────

function New-SkillSymlink($Name, $SkillDir, $TargetBase, $Repo) {
    $source = Join-Path $Repo $SkillDir | Resolve-Path -ErrorAction SilentlyContinue
    $target = Join-Path $TargetBase $Name

    if (-not $source -or -not (Test-Path $source)) {
        Write-Warn "Source directory missing: $Repo\$SkillDir — skipping $Name"
        return 2
    }
    $source = $source.Path

    if (Test-Path $target) {
        $item = Get-Item $target -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $existing = (Get-Item $target -Force).Target
            if ($existing) {
                $existingResolved = (Resolve-Path $existing -ErrorAction SilentlyContinue).Path
                if ($existingResolved -eq $source) {
                    return 1
                }
                Write-Warn "${Name}: symlink exists but points to $existing — skipping"
                return 2
            }
        }
        Write-Warn "${Name}: directory exists (not a symlink) — skipping"
        return 2
    }

    try {
        New-Item -ItemType SymbolicLink -Path $target -Target $source -ErrorAction Stop | Out-Null
        return 0
    }
    catch {
        Write-Warn "Failed to create symlink for $Name"
        return 2
    }
}

function Remove-SkillSymlink($Name, $TargetBase, $Repo) {
    $target = Join-Path $TargetBase $Name
    $resolvedRepo = (Resolve-Path $Repo -ErrorAction SilentlyContinue).Path

    if (-not (Test-Path $target)) { return $false }

    $item = Get-Item $target -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        return $false
    }

    $linkTarget = $item.Target
    if (-not $linkTarget) { return $false }

    $resolvedLink = (Resolve-Path $linkTarget -ErrorAction SilentlyContinue).Path
    if ($resolvedLink -and $resolvedLink.StartsWith($resolvedRepo)) {
        Remove-Item $target -Force
        return $true
    }

    return $false
}

# ── Operations ────────────────────────────────────────────────

function Do-Install {
    $repoDir = $script:ResolvedRepoDir

    if ($script:RUN_CONTEXT -eq 'remote') {
        if (Test-Path $repoDir) {
            Write-Info "Repository already exists at $repoDir"
        }
        else {
            Write-Info 'Cloning skills repository...'
            $parent = Split-Path $repoDir -Parent
            if (-not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            git clone $script:ResolvedRepoUrl $repoDir
            if ($LASTEXITCODE -ne 0) {
                Write-Err 'Failed to clone repository. Check your network and try again.'
                exit 1
            }
            Write-Ok "Cloned to $repoDir"
        }
    }
    else {
        $repoDir = $script:SCRIPT_DIR
    }

    Parse-SkillsJson (Join-Path $repoDir 'skills.json')

    if ($script:SKILL_NAMES.Count -eq 0) {
        Write-Err 'No skills found in skills.json'
        exit 1
    }

    if (-not (Test-Path $script:TARGET_DIR)) {
        New-Item -ItemType Directory -Path $script:TARGET_DIR -Force | Out-Null
    }

    if (-not (Test-SymlinkPrivilege)) { exit 1 }

    $created = 0; $unchanged = 0; $skipped = 0
    for ($i = 0; $i -lt $script:SKILL_NAMES.Count; $i++) {
        if (-not (Test-SkillFilter $script:SKILL_NAMES[$i] $script:SKILL_DIRS[$i])) {
            continue
        }

        $result = New-SkillSymlink $script:SKILL_NAMES[$i] $script:SKILL_DIRS[$i] $script:TARGET_DIR $repoDir
        switch ($result) {
            0 { $created++ }
            1 { $unchanged++ }
            2 { $skipped++ }
        }
    }

    Write-Host ''
    Write-Ok 'Install complete'
    Write-Host "  Repository:  $repoDir"
    Write-Host "  Target:      $($script:TARGET_DIR)"
    Write-Host "  Created: $created | Unchanged: $unchanged | Skipped: $skipped"
    Show-SkillList $repoDir
}

function Do-Update {
    $repoDir = $script:ResolvedRepoDir
    if ($script:RUN_CONTEXT -eq 'local') { $repoDir = $script:SCRIPT_DIR }

    if (-not (Test-Path $repoDir)) {
        Write-Err "Skills repo not found at $repoDir. Run 'setup.ps1 install' first."
        exit 1
    }

    if (Test-Path (Join-Path $repoDir '.git')) {
        Write-Info 'Pulling latest changes...'
        git -C $repoDir pull --ff-only 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn 'Pull failed (local changes or network issue). Refreshing symlinks from current state.'
        }
        else {
            Write-Ok 'Repository updated'
        }
    }
    else {
        Write-Warn "$repoDir is not a git repository — skipping pull"
    }

    Parse-SkillsJson (Join-Path $repoDir 'skills.json')
    if (-not (Test-Path $script:TARGET_DIR)) {
        New-Item -ItemType Directory -Path $script:TARGET_DIR -Force | Out-Null
    }

    $created = 0; $unchanged = 0; $skipped = 0; $removed = 0
    for ($i = 0; $i -lt $script:SKILL_NAMES.Count; $i++) {
        $result = New-SkillSymlink $script:SKILL_NAMES[$i] $script:SKILL_DIRS[$i] $script:TARGET_DIR $repoDir
        switch ($result) {
            0 { $created++ }
            1 { $unchanged++ }
            2 { $skipped++ }
        }
    }

    $resolvedRepo = (Resolve-Path $repoDir -ErrorAction SilentlyContinue).Path
    if (Test-Path $script:TARGET_DIR) {
        Get-ChildItem $script:TARGET_DIR | ForEach-Object {
            $item = $_
            if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return }

            $linkName = $item.Name
            $linkTarget = $item.Target
            if (-not $linkTarget) { return }

            $resolvedLink = (Resolve-Path $linkTarget -ErrorAction SilentlyContinue).Path

            if ($resolvedLink -and $resolvedLink.StartsWith($resolvedRepo)) {
                $found = $script:SKILL_NAMES -contains $linkName
                if (-not $found) {
                    Remove-Item $item.FullName -Force
                    Write-Info "Removed stale symlink: $linkName"
                    $script:removed++
                }
            }

            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and -not (Test-Path $item.FullName -ErrorAction SilentlyContinue)) {
                Remove-Item $item.FullName -Force
                Write-Info "Removed broken symlink: $linkName"
                $script:removed++
            }
        }
    }

    Write-Host ''
    Write-Ok 'Update complete'
    Write-Host "  New: $created | Unchanged: $unchanged | Removed: $removed | Skipped: $skipped"
}

function Do-Uninstall {
    $repoDir = $script:ResolvedRepoDir
    if ($script:RUN_CONTEXT -eq 'local') { $repoDir = $script:SCRIPT_DIR }

    $removed = 0

    if (Test-Path (Join-Path $repoDir 'skills.json')) {
        Parse-SkillsJson (Join-Path $repoDir 'skills.json')
        for ($i = 0; $i -lt $script:SKILL_NAMES.Count; $i++) {
            if (Remove-SkillSymlink $script:SKILL_NAMES[$i] $script:TARGET_DIR $repoDir) {
                $removed++
            }
        }
    }

    $resolvedRepo = (Resolve-Path $repoDir -ErrorAction SilentlyContinue).Path
    if ($resolvedRepo -and (Test-Path $script:TARGET_DIR)) {
        Get-ChildItem $script:TARGET_DIR | ForEach-Object {
            $item = $_
            if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return }

            $linkTarget = $item.Target
            if (-not $linkTarget) { return }

            $resolvedLink = (Resolve-Path $linkTarget -ErrorAction SilentlyContinue).Path
            if ($resolvedLink -and $resolvedLink.StartsWith($resolvedRepo)) {
                $linkName = $item.Name
                Remove-Item $item.FullName -Force
                $script:removed++
            }
        }
    }

    Write-Host ''
    Write-Ok "Removed $removed symlinks"

    if (-not $KeepRepo -and (Test-Path $repoDir) -and $script:RUN_CONTEXT -eq 'remote') {
        Remove-Item $repoDir -Recurse -Force
        $parent = Split-Path $repoDir -Parent
        if ((Test-Path $parent) -and (Get-ChildItem $parent | Measure-Object).Count -eq 0) {
            Remove-Item $parent -Force -ErrorAction SilentlyContinue
        }
        Write-Ok "Deleted $repoDir"
    }
}

# ── Helpers ───────────────────────────────────────────────────

function Show-SkillList($RepoPath) {
    $catMap = [ordered]@{}

    for ($i = 0; $i -lt $script:SKILL_NAMES.Count; $i++) {
        $cat = ($script:SKILL_DIRS[$i] -split '/')[0]
        if (-not $catMap.Contains($cat)) {
            $catMap[$cat] = @()
        }
        $catMap[$cat] += $script:SKILL_NAMES[$i]
    }

    Write-Host ''
    foreach ($cat in $catMap.Keys) {
        $pad = "$cat/".PadRight(15)
        Write-Host "  $pad" -NoNewline
        Write-Host ($catMap[$cat] -join ', ')
    }
}

function Show-Usage {
    @"
setup.ps1 — Install, update, or uninstall Kilian's Claude Code skills (Windows)

Usage:
  .\setup.ps1 install   [options]   Clone repo (if needed) and symlink skills
  .\setup.ps1 update    [options]   Pull latest and refresh symlinks
  .\setup.ps1 uninstall [options]   Remove symlinks and cloned repo

Options:
  -All                     Install all skills (default: only setup-kilians-skills)
  -Skill <name> ...        Install specific skills (space-separated)
  -Category <name>         Install skills from a category (engineering, productivity)
  -Project                 Install to .claude\skills\ in cwd (default: global)
  -RepoUrl URL             Override git clone URL
  -KeepRepo                On uninstall, keep the cloned repo (only remove symlinks)
  -Help                    Show this help

Examples:
  # Install setup-kilians-skills (default)
  .\setup.ps1 install

  # Install all skills globally
  .\setup.ps1 install -All

  # Install only engineering skills
  .\setup.ps1 install -Category engineering

  # Install specific skills to current project
  .\setup.ps1 install -Project -Skill tdd diagnose

  # Update to latest
  .\setup.ps1 update

  # Uninstall but keep the repo
  .\setup.ps1 uninstall -KeepRepo

  # First-time install via PowerShell
  irm https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.ps1 | iex
"@
}

# ── Main ──────────────────────────────────────────────────────

if ($Help) {
    Show-Usage
    return
}

Detect-RunContext
Check-Prerequisites

$script:ResolvedRepoDir = if ($script:RUN_CONTEXT -eq 'local') { $script:SCRIPT_DIR }
    else { $script:DEFAULT_REPO_DIR }

$script:ResolvedRepoUrl = if ($RepoUrl) { $RepoUrl } else { $script:DEFAULT_REPO_URL }

$script:TARGET_DIR = if ($Project) {
    Join-Path (Get-Location) '.claude\skills'
}
else {
    Join-Path $HOME '.claude\skills'
}

Write-Host ''
Write-Host "  Kilian's Claude Code Skills Installation Wizard"
Write-Host ''

switch ($Command) {
    'install'   { Do-Install }
    'update'    { Do-Update }
    'uninstall' { Do-Uninstall }
    default     { Do-Install }
}

Write-Host ''
