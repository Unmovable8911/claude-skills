---
name: update-memory
description: Generate or incrementally update a CODEBASE.md file that gives AI models a structured overview of the project. Invoke manually by user at the end of a session after making structural changes, adding modules, or modifying architecture.
---

# Update Memory

Generate or update `CODEBASE.md` in the project root — a structured overview designed for AI model consumption, enabling fast project comprehension without reading irrelevant files.

## Determine mode

Check if `CODEBASE.md` exists in the project root.

- **Exists** → Incremental update mode
- **Does not exist** → Initial generation mode

## Initial generation

When `CODEBASE.md` does not exist, generate it from scratch.

### Step 1 — Gather context

Read available documentation first for a baseline understanding:

1. Read `README.md` if it exists
2. Read `CLAUDE.md` if it exists
3. Read `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or equivalent for tech stack and dependencies

Then scan the project structure:

1. Run `find` or `ls` to map the top-level directory layout
2. Identify entry points (e.g., `main.ts`, `index.js`, `cmd/`, `src/lib.rs`)
3. For each top-level directory that represents a module, read its key files to understand its purpose and what it exports
4. Trace import/dependency relationships between modules

### Step 2 — Write CODEBASE.md

Generate the file following the template structure defined below. Cover all six sections. Be concise — the goal is a map, not documentation.

### Step 3 — Post-creation guidance

After writing the file, output:

1. A brief summary of what was generated (number of modules identified, key architectural patterns found)
2. A suggestion: *"Consider adding the following line to your CLAUDE.md to ensure this file is read at the start of every session:"*

```
Read CODEBASE.md at the start of every conversation for project context.
```

## Incremental update

When `CODEBASE.md` already exists, update it based on what changed in the current session.

### Step 1 — Read existing file

Read the current `CODEBASE.md` in full.

### Step 2 — Determine what changed

Use your session context — you already know what files were created, modified, deleted, or restructured during this session. Identify which sections of `CODEBASE.md` are affected:

- New modules or directories added → add to Directory Structure and Modules
- Modules removed → remove from all sections
- Module responsibilities changed → update the module's Purpose and Key Files
- Dependency relationships changed → update the module's Dependencies field
- New external dependencies introduced for significant functionality → update External Dependencies
- Data flow altered → update Data Flow
- Tech stack changed (new framework, language, entry point) → update Project Summary

### Step 3 — Apply changes

Edit only the affected sections. Do not rewrite sections that have not changed. Preserve any content that remains accurate.

### Step 4 — Output summary

Output a brief summary of what was updated, structured as:

- **Added**: modules or sections that were newly added
- **Updated**: modules or sections whose content changed
- **Removed**: modules or sections that were removed

If nothing needs updating (session involved no structural changes), say so and do not modify the file.

## Template structure

The generated `CODEBASE.md` must follow the template in `CODEBASE_TEMPLATE.md` (located in this skill's directory). Read that file for the exact structure.

## Writing guidelines

- **Audience is AI models, not humans.** Optimize for parseability and information density over readability.
- **Module-level + key-file-level granularity.** Do not document individual functions or methods.
- **Be concrete.** Use actual file paths, actual module names, actual dependency names. No placeholders.
- **Be terse.** One sentence per purpose. Short lists over paragraphs.
- **Dependencies are directional.** `A depends on B` means A imports from or calls into B.
- **Exposes describes the module boundary.** List what other modules actually use, not every export.
- **Data Flow is optional.** Only include it if the project has clear data pipelines or request flows. Libraries, CLI tools, and utility collections often do not.
- **External Dependencies is selective.** Only include libraries that a developer needs to know about to understand the architecture. Skip standard/obvious ones (e.g., don't list `typescript` for a TypeScript project).
