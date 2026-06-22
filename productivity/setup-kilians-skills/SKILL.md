---
name: setup-kilians-skills
description: Install skills from Kilian's skills collection into the global or project-level Claude skills directory via symbolic links. Use this skill whenever the user wants to install, set up, link, or add skills from this collection to their Claude Code environment — whether globally or for a specific project.
---

# Setup Kilian's Skills

Install skills from this repository into global or project-level Claude skills directories by creating symbolic links. This avoids copying files and keeps installed skills in sync with the source.

## Resolve paths

Before doing anything else, detect the operating system and resolve all paths accordingly.

### Detect OS

Run `uname -s 2>/dev/null || echo Windows` to detect the platform. Classify as:
- **macOS** — output contains `Darwin`
- **Linux** — output contains `Linux`
- **Windows** — output contains `MINGW`, `MSYS`, `CYGWIN`, or `Windows`

### Derive the home directory

- macOS / Linux: use `$HOME`
- Windows: use `$USERPROFILE` (in PowerShell/cmd) or `$HOME` (in Git Bash / WSL). Run `echo $HOME` first — if it returns a valid path, use it; otherwise fall back to `$USERPROFILE`.

### Derive key paths

| Path | macOS / Linux | Windows (Git Bash / WSL) | Windows (PowerShell / cmd) |
|---|---|---|---|
| **Skills repo** | `$HOME/.agent/kilians-skills` | `$HOME/.agent/kilians-skills` | `$USERPROFILE\.agent\kilians-skills` |
| **Global install dir** | `$HOME/.claude/skills` | `$HOME/.claude/skills` | `$USERPROFILE\.claude\skills` |
| **Project install dir** | `.claude/skills` (relative to cwd) | `.claude/skills` | `.claude\skills` |

### Validate the skills repo exists

Check that the skills repo directory actually exists at the resolved path. If it doesn't, tell the user the expected location and stop — the repository may not have been cloned yet.

## Process

### 1. Ask where to install

Use `AskUserQuestion` to ask the user whether skills should be installed globally or at the project level:

- **Global** — symlinks go into the global install dir
- **Project** — symlinks go into `.claude/skills/` relative to the current working directory

If the user picks project-level, verify that the current working directory is a sensible project root (has a `.git/`, `package.json`, `Cargo.toml`, or similar). Create the target directory if it doesn't exist.

### 2. List available skills

Run the bundled script to display the full skill list. Pass both the global and project skill directories so the script can show installation status for each skill. Choose the script matching the detected OS:

- **macOS / Linux / Git Bash / WSL:**
  ```bash
  bash <repo-dir>/productivity/setup-kilians-skills/scripts/select-and-install.sh list \
    --repo-dir <repo-dir> \
    --global-dir <global-install-dir> \
    --project-dir <project-install-dir>
  ```

- **Windows (PowerShell / cmd):**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "<repo-dir>\productivity\setup-kilians-skills\scripts\select-and-install.ps1" list -RepoDir "<repo-dir>" -GlobalDir "<global-install-dir>" -ProjectDir "<project-install-dir>"
  ```

Where `<global-install-dir>` is the global skills directory (e.g. `$HOME/.claude/skills`) and `<project-install-dir>` is the project-level skills directory (e.g. `.claude/skills` relative to cwd). If a directory does not exist, omit that flag — the script handles missing dirs gracefully.

The script reads `skills.json` and outputs a numbered, categorized table of all available skills with install status markers (`[global]`, `[project]`, or `[global+project]`). Present the script output directly to the user — do not regenerate or reformat the list yourself.

Then ask the user which skills they want to install. They can respond with:
- Numbers (e.g. `1,3,5`)
- Names (e.g. `tdd,diagnose`)
- `all` to install everything

### 3. Create symbolic links

Run the bundled script with the user's selection:

- **macOS / Linux / Git Bash / WSL:**
  ```bash
  bash <repo-dir>/productivity/setup-kilians-skills/scripts/select-and-install.sh install \
    --repo-dir <repo-dir> \
    --target-dir <install-dir> \
    --skills <user-selection>
  ```

- **Windows (PowerShell / cmd):**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "<repo-dir>\productivity\setup-kilians-skills\scripts\select-and-install.ps1" install -RepoDir "<repo-dir>" -TargetDir "<install-dir>" -Skills "<user-selection>"
  ```

Where `<install-dir>` is the global or project-level directory determined in step 1, and `<user-selection>` is the user's comma-separated input from step 2.

The script handles symlink creation, conflict detection, and error reporting. On Windows, if symlink creation fails, the script will prompt the user to enable Developer Mode or run as Administrator. Report the script's output to the user.

### 4. Reload skills

After linking, run `/reload-skills` so Claude picks up the newly installed skills without restarting the session.
