---
name: setup-kilians-skills
description: Install skills from Kilian's skills collection into the global or project-level Claude skills directory via symbolic links. Use this skill whenever the user wants to install, set up, link, or add skills from this collection to their Claude Code environment — whether globally or for a specific project.
---

# Setup Kilian's Skills

Install skills from this repository into Claude skills directories by creating symbolic links. The bundled script handles all heavy lifting — listing skills, checking install status, and creating symlinks. Your role is to resolve paths, ask the user for scope and selection, and relay script output.

Do NOT read `skills.json` or create symlinks yourself. The script does both.

## Resolve paths

Detect the OS and resolve all paths before running the script.

### Detect OS

Run `uname -s 2>/dev/null || echo Windows`. Classify as:
- **macOS** — output contains `Darwin`
- **Linux** — output contains `Linux`
- **Windows** — output contains `MINGW`, `MSYS`, `CYGWIN`, or `Windows`

### Derive paths

| Path | macOS / Linux | Windows (Git Bash / WSL) | Windows (PowerShell / cmd) |
|---|---|---|---|
| **Skills repo** | `$HOME/.agent/kilians-skills` | `$HOME/.agent/kilians-skills` | `$USERPROFILE\.agent\kilians-skills` |
| **Global install dir** | `$HOME/.claude/skills` | `$HOME/.claude/skills` | `$USERPROFILE\.claude\skills` |
| **Project install dir** | `.claude/skills` (relative to cwd) | `.claude/skills` | `.claude\skills` |

Validate the skills repo directory exists. If it doesn't, tell the user the expected location and stop.

## Process

### 1. Ask where to install

Use `AskUserQuestion` to ask global or project-level:

- **Global** — symlinks go into the global install dir
- **Project** — symlinks go into `.claude/skills/` relative to cwd

If project-level, verify the cwd looks like a project root (has `.git/`, `package.json`, `Cargo.toml`, or similar).

### 2. List skills and collect selection

Run the script's `list` command to show all available skills:

```bash
bash <repo-dir>/productivity/setup-kilians-skills/scripts/select-and-install.sh list \
  --repo-dir <repo-dir> \
  --global-dir <global-install-dir> \
  --project-dir <project-install-dir>
```

On Windows, use the `.ps1` variant:
```powershell
powershell -ExecutionPolicy Bypass -File "<repo-dir>\productivity\setup-kilians-skills\scripts\select-and-install.ps1" list `
  -RepoDir "<repo-dir>" -GlobalDir "<global-install-dir>" -ProjectDir "<project-install-dir>"
```

If a directory does not exist, omit that flag — the script handles missing dirs gracefully.

Present the script output directly to the user — do not regenerate or reformat the list. Then ask which skills to install. The user can respond with numbers (`1,3,5`), names (`tdd,diagnose`), or `all`.

### 3. Install selected skills

Pass the user's selection to the script's `install` command:

```bash
bash <repo-dir>/productivity/setup-kilians-skills/scripts/select-and-install.sh install \
  --repo-dir <repo-dir> \
  --target-dir <install-dir> \
  --skills <user-selection>
```

On Windows:
```powershell
powershell -ExecutionPolicy Bypass -File "<repo-dir>\productivity\setup-kilians-skills\scripts\select-and-install.ps1" install `
  -RepoDir "<repo-dir>" -TargetDir "<install-dir>" -Skills "<user-selection>"
```

Where `<install-dir>` is the directory from step 1, and `<user-selection>` is the user's verbatim input from step 2.

Report the script's output to the user.

### 4. Prompt to reload

After linking completes, tell the user to run `/reload-skills` in Claude Code to pick up the newly installed skills. Display a clear message like:

> Skills installed successfully. Run `/reload-skills` to make them available in this session.
