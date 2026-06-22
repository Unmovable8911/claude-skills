# select-and-install.ps1 — List available skills and install selected ones via symlinks
#
# Usage:
#   select-and-install.ps1 list    [-RepoDir DIR] [-GlobalDir DIR] [-ProjectDir DIR]
#   select-and-install.ps1 install [-RepoDir DIR] -TargetDir DIR -Skills SELECTION

param(
    [Parameter(Position = 0)]
    [ValidateSet("list", "install")]
    [string]$Command,

    [string]$RepoDir,
    [string]$TargetDir,
    [string]$Skills,
    [string]$GlobalDir,
    [string]$ProjectDir,

    [switch]$Help
)

$ErrorActionPreference = "Stop"

# ── Derive repo root from script location ─────────────────────

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DefaultRepoDir = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path

# ── Helpers ───────────────────────────────────────────────────

function Write-Info    { param([string]$Msg) Write-Host ":: $Msg" -ForegroundColor Blue }
function Write-Ok      { param([string]$Msg) Write-Host "ok $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "!! $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "** $Msg" -ForegroundColor Red }

function Show-Usage {
    @"
select-and-install.ps1 — List and install skills via symlinks

Usage:
  select-and-install.ps1 list    [-RepoDir DIR] [-GlobalDir DIR] [-ProjectDir DIR]
  select-and-install.ps1 install [-RepoDir DIR] -TargetDir DIR -Skills SELECTION

Commands:
  list      Display all available skills with numbers and install status
  install   Create symlinks for selected skills

Options:
  -RepoDir DIR      Skills repository path (default: auto-detected)
  -TargetDir DIR    Where to create symlinks (e.g. ~\.claude\skills)
  -Skills SELECTION Comma-separated skill numbers, names, or 'all'
  -GlobalDir DIR    Global skills dir — used by 'list' to show install status
  -ProjectDir DIR   Project skills dir — used by 'list' to show install status

Examples:
  select-and-install.ps1 list -GlobalDir "$env:USERPROFILE\.claude\skills"
  select-and-install.ps1 install -TargetDir "$env:USERPROFILE\.claude\skills" -Skills "1,3,5"
  select-and-install.ps1 install -TargetDir "$env:USERPROFILE\.claude\skills" -Skills "all"
"@
}

# ── JSON parsing ─────────────────────────────────────────────

function Read-SkillsJson {
    param([string]$JsonPath)

    if (-not (Test-Path $JsonPath)) {
        Write-Err "skills.json not found at $JsonPath"
        exit 1
    }

    $raw = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json
    $skills = @()
    foreach ($item in $raw) {
        $skills += [PSCustomObject]@{
            Name        = $item.name
            Directory   = $item.directory
            Description = $item.description
        }
    }
    return $skills
}

# ── Install status check ─────────────────────────────────────

function Get-InstallStatus {
    param([string]$SkillName, [string]$SkillSource, [string]$GDir, [string]$PDir)

    $inGlobal = $false
    $inProject = $false

    if ($GDir -and (Test-Path (Join-Path $GDir $SkillName))) {
        $item = Get-Item (Join-Path $GDir $SkillName) -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = $item.Target
            if ($target -is [System.Array]) { $target = $target[0] }
            $resolved = (Resolve-Path $target -ErrorAction SilentlyContinue).Path
            if ($resolved -eq $SkillSource) { $inGlobal = $true }
        }
    }

    if ($PDir -and (Test-Path (Join-Path $PDir $SkillName))) {
        $item = Get-Item (Join-Path $PDir $SkillName) -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = $item.Target
            if ($target -is [System.Array]) { $target = $target[0] }
            $resolved = (Resolve-Path $target -ErrorAction SilentlyContinue).Path
            if ($resolved -eq $SkillSource) { $inProject = $true }
        }
    }

    if ($inGlobal -and $inProject) { return "global+project" }
    elseif ($inGlobal) { return "global" }
    elseif ($inProject) { return "project" }
    else { return "" }
}

# ── List command ─────────────────────────────────────────────

function Invoke-List {
    param([string]$Repo, [string]$GDir, [string]$PDir)

    $skills = Read-SkillsJson (Join-Path $Repo "skills.json")

    if ($skills.Count -eq 0) {
        Write-Err "No skills found in skills.json"
        exit 1
    }

    $categories = [ordered]@{}
    for ($i = 0; $i -lt $skills.Count; $i++) {
        $cat = ($skills[$i].Directory -split "/")[0]
        if (-not $categories.Contains($cat)) {
            $categories[$cat] = @()
        }
        $categories[$cat] += $i
    }

    $maxNameLen = ($skills | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    if ($maxNameLen -lt 4) { $maxNameLen = 4 }

    $statuses = @()
    $installedCount = 0
    for ($i = 0; $i -lt $skills.Count; $i++) {
        $source = (Resolve-Path (Join-Path $Repo $skills[$i].Directory) -ErrorAction SilentlyContinue).Path
        $status = Get-InstallStatus -SkillName $skills[$i].Name -SkillSource $source -GDir $GDir -PDir $PDir
        $statuses += $status
        if ($status) { $installedCount++ }
    }

    Write-Host ""
    Write-Host "  Available Skills  ($($skills.Count) total, $installedCount installed)" -ForegroundColor White
    Write-Host ""

    foreach ($cat in $categories.Keys) {
        Write-Host "  $cat/" -ForegroundColor Blue

        foreach ($i in $categories[$cat]) {
            $num = $i + 1
            $name = $skills[$i].Name
            $desc = $skills[$i].Description
            $status = $statuses[$i]
            if ($desc.Length -gt 55) {
                $desc = $desc.Substring(0, 52) + "..."
            }

            $numStr = $num.ToString().PadLeft(4)
            $nameStr = $name.PadRight($maxNameLen)
            $descStr = $desc.PadRight(57)
            Write-Host "${numStr}  ${nameStr}  " -NoNewline
            Write-Host "$descStr" -ForegroundColor DarkGray -NoNewline
            if ($status) {
                Write-Host " [$status]" -ForegroundColor Green
            } else {
                Write-Host ""
            }
        }
        Write-Host ""
    }

    Write-Host "  Select by number (e.g. 1,3,5), name (e.g. tdd,diagnose), or 'all'." -ForegroundColor DarkGray
    Write-Host ""
}

# ── Install command ──────────────────────────────────────────

function Invoke-Install {
    param([string]$Repo, [string]$Target, [string]$Selection)

    if (-not $Target) {
        Write-Err "-TargetDir is required for install"
        exit 1
    }
    if (-not $Selection) {
        Write-Err "-Skills is required for install"
        exit 1
    }

    $skills = Read-SkillsJson (Join-Path $Repo "skills.json")
    $total = $skills.Count

    if ($total -eq 0) {
        Write-Err "No skills found in skills.json"
        exit 1
    }

    $selectedIndices = @()

    if ($Selection -eq "all") {
        $selectedIndices = 0..($total - 1)
    }
    else {
        $items = $Selection -split "," | ForEach-Object { $_.Trim() }
        foreach ($item in $items) {
            if ($item -match '^\d+$') {
                $idx = [int]$item - 1
                if ($idx -ge 0 -and $idx -lt $total) {
                    $selectedIndices += $idx
                }
                else {
                    Write-Warn "Invalid number: $item (valid range: 1-$total)"
                }
            }
            else {
                $found = $false
                for ($i = 0; $i -lt $total; $i++) {
                    if ($skills[$i].Name -eq $item) {
                        $selectedIndices += $i
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    Write-Warn "Unknown skill: $item"
                }
            }
        }
    }

    $selectedIndices = $selectedIndices | Select-Object -Unique

    if ($selectedIndices.Count -eq 0) {
        Write-Err "No valid skills selected"
        exit 1
    }

    if (-not (Test-Path $Target)) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }

    # Test symlink support
    $testSrc = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "symtest-$PID") -Force
    $testLink = Join-Path $Target ".symlink-test-$PID"
    try {
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testSrc.FullName -ErrorAction Stop | Out-Null
        Remove-Item $testLink -Force
    }
    catch {
        Remove-Item $testSrc.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Err "Symlink creation failed in $Target. Enable Developer Mode or run as Administrator."
        exit 1
    }
    finally {
        Remove-Item $testSrc.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    $created = 0; $unchanged = 0; $skipped = 0

    foreach ($idx in $selectedIndices) {
        $name = $skills[$idx].Name
        $skillDir = $skills[$idx].Directory
        $source = (Resolve-Path (Join-Path $Repo $skillDir) -ErrorAction SilentlyContinue).Path
        $target_path = Join-Path $Target $name

        if (-not $source -or -not (Test-Path $source)) {
            Write-Warn "Source missing: $Repo\$skillDir — skipping $name"
            $skipped++
            continue
        }

        if (Test-Path $target_path) {
            $item = Get-Item $target_path -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $existing = $item.Target
                if ($existing -is [System.Array]) { $existing = $existing[0] }
                $existingResolved = (Resolve-Path $existing -ErrorAction SilentlyContinue).Path
                if ($existingResolved -eq $source) {
                    $unchanged++
                    continue
                }
                else {
                    Write-Warn "${name}: symlink exists -> $existing — skipping"
                    $skipped++
                    continue
                }
            }
            else {
                Write-Warn "${name}: directory exists (not a symlink) — skipping"
                $skipped++
                continue
            }
        }

        try {
            New-Item -ItemType SymbolicLink -Path $target_path -Target $source -ErrorAction Stop | Out-Null
            Write-Ok "Linked: $name"
            $created++
        }
        catch {
            Write-Warn "Failed to create symlink for $name"
            $skipped++
        }
    }

    Write-Host ""
    Write-Ok "Install complete"
    Write-Host "  Target:     $Target"
    Write-Host "  Created: $created | Unchanged: $unchanged | Skipped: $skipped"
    Write-Host ""
}

# ── Main ─────────────────────────────────────────────────────

if ($Help -or -not $Command) {
    Show-Usage
    exit 0
}

if (-not $RepoDir) { $RepoDir = $DefaultRepoDir }

switch ($Command) {
    "list"    { Invoke-List -Repo $RepoDir -GDir $GlobalDir -PDir $ProjectDir }
    "install" { Invoke-Install -Repo $RepoDir -Target $TargetDir -Selection $Skills }
}
