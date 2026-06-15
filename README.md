# AI Coding Skills

A personal collection of Claude Code skills for software engineering, productivity, writing, and daily workflows. Skills are structured prompts that extend Claude Code with reusable, opinionated behaviours — invoke them with `/skill-name` inside a Claude Code session.

## Structure

```
engineering/   — software development workflows
productivity/  — meta-skills for working with Claude itself
```

---

## Engineering

Skills for software development: planning, implementing, debugging, and maintaining codebases.

- **diagnose** — A structured six-phase debugging methodology (build a feedback loop → reproduce → hypothesise → instrument → fix with regression test → cleanup). Use when investigating hard bugs, failures, or performance regressions.

- **dispatch-issues** — Orchestrates an issue backlog in `.docs/issues/` by dispatching each slice to a dedicated TDD sub-agent in dependency-respecting waves (up to 3 in parallel), then commits and marks each resolved. Use when you want to drive a full issue backlog to completion automatically.

- **grill-with-docs** — Conducts a relentless one-question-at-a-time interview to stress-test a plan against the project's domain model, sharpening terminology and updating `CONTEXT.md` and ADRs inline as decisions crystallise. Use when validating a design against existing domain language and documented decisions.

- **improve-codebase-architecture** — Scans a codebase for shallow modules and tight coupling, then produces an interactive HTML report of "deepening opportunities" — refactors that put more behaviour behind smaller interfaces. Use when you want to improve testability, locality, or AI-navigability of the architecture.

- **prototype** — Builds a clearly-throwaway prototype to answer a specific design question, routing to either an interactive terminal app (logic/state-model questions) or multiple toggleable UI variations (visual questions). Use when validating a data model, state machine, or UI design before committing to it.

- **tdd** — Implements features via strict red-green-refactor vertical slices (one test then one implementation at a time), keeping tests coupled to public behaviour rather than implementation details. Use when building new features or fixing bugs test-first.

- **to-issues** — Breaks a plan, spec, or PRD into independently-deliverable vertical-slice issues, quizzes the user on granularity and dependencies, then saves an outline and individual issue docs to `.docs/issues/`. Use when converting a plan into a structured implementation backlog.

- **to-prd** — Synthesises the current conversation context and codebase understanding into a PRD (problem statement, user stories, implementation/testing decisions) saved to `.docs/prd/`. Use when formalising what has already been discussed into a product requirements document.

---

## Productivity

Meta-skills for working more effectively with Claude itself.

- **caveman** — Activates a persistent ultra-compressed communication mode that strips articles, filler, and pleasantries (~75% token reduction) while preserving full technical accuracy. Use when you want brevity or need to reduce token usage.

- **grill-me** — Relentlessly interviews the user one question at a time about every aspect of a plan or design, walking down the decision tree and providing a recommended answer for each question. Use when you want to stress-test a plan or get grilled on your design.

- **skill-creator** — Guides the full lifecycle of creating, testing, and iteratively improving Claude skills — from capturing intent and drafting a `SKILL.md`, through running parallel eval/baseline runs with a browser-based reviewer, to description optimisation. Use when creating a skill from scratch, editing an existing one, or benchmarking skill performance.

- **teach** — Sets up and maintains a stateful teaching workspace in the current directory, producing self-contained HTML lessons, reference documents, and learning records tailored to the user's mission and zone of proximal development. Use when learning a topic across multiple sessions.

- **write-a-skill** — A lightweight guide for quickly drafting a new skill with proper structure (`SKILL.md`, optional reference files, and utility scripts), covering requirements gathering, file layout, description requirements, and a review checklist. Use when creating a new skill.
