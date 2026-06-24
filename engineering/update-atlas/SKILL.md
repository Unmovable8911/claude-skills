---
name: update-atlas
description: Generate or incrementally update a multi-file project atlas (atlas/ directory) for large codebases. Produces an INDEX.md with project overview and module tree, plus per-module detail files with dependencies, dependents, and internal structure. Invoke manually at the end of a session after making structural changes.
---

# Update Atlas

Generate or update the `atlas/` directory in the project root — a multi-file structured overview designed for AI model consumption in large codebases, enabling fast module-level navigation without reading irrelevant files.

## Determine mode

Check if `atlas/INDEX.md` exists in the project root.

- **Exists** → Incremental update mode
- **Does not exist** → Initial generation mode

## Initial generation

When `atlas/INDEX.md` does not exist, generate the full atlas from scratch.

### Step 1 — Gather context

Read available documentation first:

1. Read `README.md` if it exists
2. Read `CLAUDE.md` if it exists
3. Read `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or equivalent for tech stack and dependencies

### Step 2 — Breadth-first project scan

Scan the project using a breadth-first strategy to control depth and token consumption:

1. Map the top-level directory layout with `find` or `ls`
2. Identify entry points (e.g., `main.ts`, `index.js`, `cmd/`, `src/lib.rs`)
3. For each top-level directory, read only its entry/index/export files to determine module purpose
4. Identify sub-modules by scanning one level deeper within each top-level module
5. Infer dependency relationships by grepping import/require statements across module boundaries

Do NOT read implementation files. Module purpose and relationships should be derivable from entry files, export files, and import statements alone.

### Step 3 — Create atlas/ directory and files

1. Create the `atlas/` directory in the project root
2. Write `atlas/INDEX.md` following the INDEX template below
3. Write one `.md` file per module following the module file template below

File naming convention: use the module name in kebab-case. For sub-modules, prefix with the parent module name separated by a hyphen. Examples:
- Top-level module `auth` → `atlas/auth.md`
- Sub-module `auth/oauth` → `atlas/auth-oauth.md`
- Sub-module `auth/oauth/providers` → `atlas/auth-oauth-providers.md`

### Step 4 — Post-creation guidance

After writing all files, output:

1. A brief summary (number of modules identified, number of files generated)
2. A suggestion: *"Consider adding the following line to your CLAUDE.md to ensure the atlas is read at the start of every session:"*

```
Read atlas/INDEX.md at the start of every conversation for project context.
```

## Incremental update

When `atlas/INDEX.md` already exists, update based on what changed in the current session.

### Step 1 — Read INDEX.md

Read `atlas/INDEX.md` to understand the current atlas state.

### Step 2 — Determine what changed

Use your session context to identify structural changes. Then determine which files need updating:

- New module added → create new module file + update INDEX.md
- Module removed → delete module file + update INDEX.md + update Dependents/Dependencies in affected module files
- Module responsibility changed → update that module's file
- Dependency added/removed → update both sides (see bidirectional sync rule)
- Data flow altered → update INDEX.md Data Flow section
- External dependency added/removed → update INDEX.md External Dependencies section
- Tech stack or entry points changed → update INDEX.md Project Summary

### Step 3 — Apply changes

Edit only the affected files. Do not rewrite files that have not changed.

**Bidirectional sync rule**: when a dependency relationship changes, ALWAYS update both sides:
- If module A adds a dependency on module B:
  - Add B to `atlas/a.md` → Dependencies
  - Add A to `atlas/b.md` → Dependents
- If a dependency is removed, remove from both sides
- If a module is deleted, remove it from Dependencies and Dependents in ALL module files that reference it

### Step 4 — Output summary

Output a brief summary of what was updated:

- **Added**: new module files created
- **Updated**: existing files modified
- **Removed**: module files deleted

If nothing needs updating (session involved no structural changes), say so and do not modify any files.

## Templates

Template files are located in this skill's directory. Read them for the exact structure:

- **INDEX.md template** → `INDEX_TEMPLATE.md`
- **Module file template** → `MODULE_TEMPLATE.md`

## Writing guidelines

- **Audience is AI models, not humans.** Optimize for parseability and information density over readability.
- **Module-level + key-file-level granularity.** Do not document individual functions or methods.
- **Be concrete.** Use actual file paths, actual module names, actual dependency names. No placeholders.
- **Be terse.** One sentence per purpose. Short lists over paragraphs.
- **Dependencies are directional.** `A depends on B` means A imports from or calls into B.
- **Dependents are the reverse.** `A is depended on by C` means C imports from or calls into A.
- **Exposes describes the module boundary.** List what other modules actually use, not every export.
- **Data Flow and Internal Structure are optional per module.** Only include when the module has identifiable data flows or complex internal structure.
- **Keep INDEX.md navigable.** The Module Tree must stay compact — one line per module with a brief purpose and file link.
