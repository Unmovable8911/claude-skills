#!/usr/bin/env python3
"""Deterministic planner/updater for a .docs/issues outline.

Subcommands:
  plan            Parse 00-outline.md, resolve issue file paths, and emit JSON:
                  every slice's status, the current ready set (unresolved slices
                  whose deps are all resolved), and a deadlock flag (unresolved
                  slices remain but nothing is ready -> cycle / unmet blocker).
  resolve <N>     Flip slice N's status pending -> resolved, in place.

Usage:
  outline.py plan       [--issues-dir .docs/issues]
  outline.py resolve N  [--issues-dir .docs/issues]

The orchestrator should rely on `plan` for wave computation rather than parsing
the outline by hand, and on `resolve` rather than editing the file as text.
"""
import argparse
import json
import os
import re
import sys

OUTLINE = "00-outline.md"

# Matches:  "2. Homepage listing — blocked by: 1 — status: pending"
# Tolerates en-dash or hyphen separators and flexible whitespace.
LINE_RE = re.compile(
    r"^\s*(?P<num>\d+)\.\s*(?P<title>.+?)\s*[—-]+\s*"
    r"blocked by:\s*(?P<deps>.+?)\s*[—-]+\s*"
    r"status:\s*(?P<status>\w+)\s*$"
)


def parse_deps(raw):
    raw = raw.strip().lower()
    if raw in ("none", "-", ""):
        return []
    return [int(x) for x in re.findall(r"\d+", raw)]


def load(issues_dir):
    path = os.path.join(issues_dir, OUTLINE)
    if not os.path.isfile(path):
        sys.exit(f"error: outline not found: {path}")
    slices, raw_lines = [], []
    with open(path, encoding="utf-8") as f:
        for line in f:
            raw_lines.append(line)
            m = LINE_RE.match(line)
            if not m:
                continue
            slices.append({
                "number": int(m.group("num")),
                "title": m.group("title").strip(),
                "deps": parse_deps(m.group("deps")),
                "status": m.group("status").strip().lower(),
            })
    if not slices:
        sys.exit(f"error: no slice lines parsed from {path}")
    return path, raw_lines, slices


def resolve_issue_paths(slices, issues_dir):
    """Match each slice number to its <NN>-*.md file via directory listing."""
    by_num = {}
    for name in os.listdir(issues_dir):
        m = re.match(r"^(\d+)-.*\.md$", name)
        if m and int(m.group(1)) != 0:
            by_num[int(m.group(1))] = os.path.join(issues_dir, name)
    for s in slices:
        s["issue_path"] = by_num.get(s["number"])


def cmd_plan(args):
    _, _, slices = load(args.issues_dir)
    resolve_issue_paths(slices, args.issues_dir)
    resolved = {s["number"] for s in slices if s["status"] == "resolved"}
    unresolved = [s for s in slices if s["status"] != "resolved"]
    ready = [
        s for s in unresolved
        if all(d in resolved for d in s["deps"])
    ]
    missing_files = [s["number"] for s in slices if s["issue_path"] is None]
    deadlock = bool(unresolved) and not ready
    out = {
        "slices": slices,
        "ready": [s["number"] for s in ready],
        "ready_detail": ready,
        "unresolved": [s["number"] for s in unresolved],
        "resolved": sorted(resolved),
        "missing_issue_files": missing_files,
        "deadlock": deadlock,
        "all_done": not unresolved,
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))
    if deadlock:
        sys.exit(2)


def cmd_resolve(args):
    path, raw_lines, slices = load(args.issues_dir)
    nums = {s["number"] for s in slices}
    if args.number not in nums:
        sys.exit(f"error: slice {args.number} not in outline")
    changed = False
    new_lines = []
    for line in raw_lines:
        m = LINE_RE.match(line)
        if m and int(m.group("num")) == args.number:
            if m.group("status").strip().lower() == "resolved":
                sys.exit(f"error: slice {args.number} already resolved")
            line = re.sub(r"(status:\s*)\w+", r"\g<1>resolved", line)
            changed = True
        new_lines.append(line)
    if not changed:
        sys.exit(f"error: could not update slice {args.number}")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print(f"slice {args.number} -> resolved")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--issues-dir", default=".docs/issues")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("plan")
    r = sub.add_parser("resolve")
    r.add_argument("number", type=int)
    args = p.parse_args()
    {"plan": cmd_plan, "resolve": cmd_resolve}[args.cmd](args)


if __name__ == "__main__":
    main()
