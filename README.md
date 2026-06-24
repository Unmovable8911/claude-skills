# AI Coding Skills

A personal collection of Claude Code skills for software engineering, productivity, writing, and daily workflows. Skills are structured prompts that extend Claude Code with reusable, opinionated behaviours — invoke them with `/skill-name` inside a Claude Code session.

## Prerequisites

- [Git](https://git-scm.com/) installed and available in your `PATH`
- **Windows only:** Developer Mode enabled, or run PowerShell as Administrator (required for symlink creation)

## Installation

### macOS / Linux

**Quick start (installs the `setup-kilians-skills` skill globally):**

```bash
curl -fsSL https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.sh | bash
```

Once installed, use `/setup-kilians-skills` inside Claude Code to interactively install more skills.

**Or clone and run locally:**

```bash
git clone https://github.com/Unmovable8911/claude-skills.git ~/.agent/kilians-skills
cd ~/.agent/kilians-skills
./setup.sh install                               # installs setup-kilians-skills
./setup.sh install --all                         # installs all skills
```

**Selective install:**

```bash
./setup.sh install --category engineering        # only engineering skills
./setup.sh install --skill tdd diagnose          # specific skills
```

**Project-level install (from any project directory):**

```bash
# Via the cloned repo — run from your project directory:
~/.agent/kilians-skills/setup.sh install --project --all
~/.agent/kilians-skills/setup.sh install --project --skill tdd diagnose

# Or via curl — run from your project directory:
curl -fsSL https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.sh | bash -s -- install --project --all
curl -fsSL https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.sh | bash -s -- install --project --skill tdd diagnose
```

This creates symlinks in `<your-project>/.claude/skills/` instead of the global `~/.claude/skills/`.

**Update & uninstall:**

```bash
./setup.sh update                                # pull latest + refresh symlinks
./setup.sh uninstall                             # remove symlinks + cloned repo
./setup.sh uninstall --keep-repo                 # remove symlinks only
```

### Windows (PowerShell)

**Quick start:**

```powershell
irm https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.ps1 | iex
```

**Or clone and run locally:**

```powershell
git clone https://github.com/Unmovable8911/claude-skills.git "$HOME\.agent\kilians-skills"
cd "$HOME\.agent\kilians-skills"
.\setup.ps1 install                              # installs setup-kilians-skills
.\setup.ps1 install -All                         # installs all skills
```

**Selective install:**

```powershell
.\setup.ps1 install -Category engineering        # only engineering skills
.\setup.ps1 install -Skill tdd diagnose          # specific skills
```

**Project-level install (from any project directory):**

```powershell
# Via the cloned repo — run from your project directory:
& "$HOME\.agent\kilians-skills\setup.ps1" install -Project -All
& "$HOME\.agent\kilians-skills\setup.ps1" install -Project -Skill tdd diagnose

# Or via remote — run from your project directory:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.ps1))) install -Project -All
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.ps1))) install -Project -Skill tdd diagnose
```

This creates symlinks in `<your-project>\.claude\skills\` instead of the global `~\.claude\skills\`.

**Update & uninstall:**

```powershell
.\setup.ps1 update                               # pull latest + refresh symlinks
.\setup.ps1 uninstall                            # remove symlinks + cloned repo
.\setup.ps1 uninstall -KeepRepo                  # remove symlinks only
```


## Post-Installation

After running `setup.sh`, the `setup-kilians-skills` skill is available in Claude Code. Start a session and type:

```
/setup-kilians-skills
```

The skill will walk you through:

1. **Choose install scope** — global (`~/.claude/skills/`) or project-level (`.claude/skills/` in the current directory)
2. **Select skills** — browse all available skills with names, categories, and descriptions, then pick the ones you want
3. **Automatic linking** — creates symbolic links so installed skills stay in sync with the source repository
4. **Reload prompt** — reminds you to run `/reload-skills` so Claude picks up the newly installed skills

You can re-run `/setup-kilians-skills` at any time to install additional skills or set up skills for a new project.

## Structure

```
engineering/   — software development workflows
office/        — document creation and manipulation
productivity/  — meta-skills for working with Claude itself
```

---

## Engineering

Skills for software development: planning, implementing, debugging, and maintaining codebases.

- **codebase-design** — Shared vocabulary for designing deep modules: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface. Use when designing or improving a module's interface, finding deepening opportunities, or deciding where a seam goes.

- **diagnose** — A structured six-phase debugging methodology (build a feedback loop → reproduce → hypothesise → instrument → fix with regression test → cleanup). Use when investigating hard bugs, failures, or performance regressions.

- **dispatch-issues** — Orchestrates an issue backlog in `.docs/issues/` by dispatching each slice to a dedicated TDD sub-agent in dependency-respecting waves (up to 3 in parallel), then commits and marks each resolved. Use when you want to drive a full issue backlog to completion automatically.

- **domain-modeling** — Actively builds and sharpens a project's domain model by challenging terms, inventing edge-case scenarios, and writing the glossary and architectural decisions down as they crystallise. Use when pinning down domain terminology, recording architectural decisions, or maintaining a ubiquitous language.

- **frontend-design** — Guidance for distinctive, intentional visual design when building new UI or reshaping an existing one. Helps with aesthetic direction, typography, and making choices that don't read as templated defaults. Use when creating or redesigning a user interface.

- **grill-with-docs** — Conducts a relentless one-question-at-a-time interview to stress-test a plan against the project's domain model, sharpening terminology and updating `CONTEXT.md` and ADRs inline as decisions crystallise. Use when validating a design against existing domain language and documented decisions.

- **improve-codebase-architecture** — Scans a codebase for shallow modules and tight coupling, then produces an interactive HTML report of "deepening opportunities" — refactors that put more behaviour behind smaller interfaces. Use when you want to improve testability, locality, or AI-navigability of the architecture.

- **prototype** — Builds a clearly-throwaway prototype to answer a specific design question, routing to either an interactive terminal app (logic/state-model questions) or multiple toggleable UI variations (visual questions). Use when validating a data model, state machine, or UI design before committing to it.

- **tdd** — Implements features via strict red-green-refactor vertical slices (one test then one implementation at a time), keeping tests coupled to public behaviour rather than implementation details. Use when building new features or fixing bugs test-first.

- **to-issues** — Breaks a plan, spec, or PRD into independently-deliverable vertical-slice issues, quizzes the user on granularity and dependencies, then saves an outline and individual issue docs to `.docs/issues/`. Use when converting a plan into a structured implementation backlog.

- **to-prd** — Synthesises the current conversation context and codebase understanding into a PRD (problem statement, user stories, implementation/testing decisions) saved to `.docs/prd/`. Use when formalising what has already been discussed into a product requirements document.

- **update-atlas** — Generate or incrementally update a multi-file project atlas (`atlas/` directory) for large codebases. Produces an `INDEX.md` with project overview and module tree, plus per-module detail files with dependencies, dependents, and internal structure. Use at the end of a session on large projects after making structural changes.

- **update-memory** — Generate or incrementally update a `CODEBASE.md` file that gives AI models a structured overview of the project — architecture, modules, dependencies, and data flow — so they can navigate and modify the codebase without blind exploration. Use at the end of a session after making structural changes.

- **webapp-testing** — Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs. Use when you need to test or interact with a running web application.

---

## Office

Skills for creating, reading, editing, and manipulating office documents.

- **docx** — Create, read, edit, and manipulate Word documents (.docx files) with professional formatting, tables of contents, headings, and page numbers. Use when producing or modifying Word documents, reports, memos, letters, or templates.

- **pdf** — Read, extract, combine, split, rotate, watermark, create, fill forms, encrypt/decrypt, and OCR PDF files. Use when doing anything with PDF files.

- **pptx** — Create, read, edit, and manipulate PowerPoint presentations (.pptx files), including slide decks, pitch decks, templates, layouts, and speaker notes. Use when working with presentation files.

- **xlsx** — Create, read, edit, and manipulate spreadsheet files (.xlsx, .xlsm, .csv, .tsv) with support for financial models, charts, formulas, and data cleaning. Use when producing or modifying spreadsheet files.

---

## Productivity

Meta-skills for working more effectively with Claude itself.

- **brainstorming** — Collaborative design process that explores user intent, requirements and constraints through one-at-a-time questions, proposes approaches with trade-offs, and produces a validated design spec before any implementation begins. Use before any creative work — creating features, building components, or modifying behavior.

- **caveman** — Activates a persistent ultra-compressed communication mode that strips articles, filler, and pleasantries (~75% token reduction) while preserving full technical accuracy. Use when you want brevity or need to reduce token usage.

- **doc-coauthoring** — A structured three-stage workflow for co-authoring documentation: context gathering, iterative refinement, and reader testing with a fresh agent to catch blind spots. Use when writing docs, proposals, technical specs, or decision docs.

- **grill-me** — Relentlessly interviews the user one question at a time about every aspect of a plan or design, walking down the decision tree and providing a recommended answer for each question. Use when you want to stress-test a plan or get grilled on your design.

- **handoff** — Compacts the current conversation into a handoff document so a fresh agent can continue the work, referencing existing artifacts by path rather than duplicating them. Use when ending a session and wanting to enable seamless continuation.

- **mcp-builder** — Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools, supporting both Python (FastMCP) and Node/TypeScript (MCP SDK). Use when building MCP servers to integrate external APIs or services.

- **skill-creator** — Guides the full lifecycle of creating, testing, and iteratively improving Claude skills — from capturing intent and drafting a `SKILL.md`, through running parallel eval/baseline runs with a browser-based reviewer, to description optimisation. Use when creating a skill from scratch, editing an existing one, or benchmarking skill performance.

- **setup-kilians-skills** — Installs skills from this collection into the global (`~/.claude/skills/`) or project-level (`.claude/skills/`) Claude skills directory by creating symbolic links, keeping installed skills in sync with the source. Use when you want to install or update skills from this repository.

- **teach** — Sets up and maintains a stateful teaching workspace in the current directory, producing self-contained HTML lessons, reference documents, and learning records tailored to the user's mission and zone of proximal development. Use when learning a topic across multiple sessions.

- **write-a-skill** — A lightweight guide for quickly drafting a new skill with proper structure (`SKILL.md`, optional reference files, and utility scripts), covering requirements gathering, file layout, description requirements, and a review checklist. Use when creating a new skill.

- **writing-plans** — Writes comprehensive implementation plans from a spec or requirements, breaking work into bite-sized TDD tasks with exact file paths, complete code, and testing commands. Use when you have a spec or requirements for a multi-step task, before touching code.
