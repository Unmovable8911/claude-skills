#!/usr/bin/env bash
# setup.sh — Install, update, or uninstall Kilian's Claude Code skills
#
# Usage:
#   ./setup.sh install [--project] [--skill a b] [--category engineering]
#   ./setup.sh update  [--project]
#   ./setup.sh uninstall [--keep-repo]
#
# First-time install via curl:
#   curl -fsSL https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.sh | bash

set -uo pipefail

readonly DEFAULT_REPO_URL="https://github.com/Unmovable8911/claude-skills.git"
readonly DEFAULT_REPO_DIR="${HOME}/.agent/kilians-skills"

SKILL_NAMES=()
SKILL_DIRS=()
SKILL_DESCS=()

COMMAND=""
USE_PROJECT=false
REPO_URL=""
REPO_DIR=""
KEEP_REPO=false
FILTER_SKILLS=""
FILTER_CATEGORY=""
INSTALL_ALL=false
RUN_CONTEXT=""
SCRIPT_DIR=""
TARGET_DIR=""

# ── Colors ─────────────────────────────────────────────────────

setup_colors() {
  BLUE='\033[0;34m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
  RED='\033[0;31m' BOLD='\033[1m' RESET='\033[0m'
}

log_info()    { printf "${BLUE}::${RESET} %s\n" "$1"; }
log_success() { printf "${GREEN}ok${RESET} %s\n" "$1"; }
log_warn()    { printf "${YELLOW}!!${RESET} %s\n" "$1"; }
log_error()   { printf "${RED}** %s${RESET}\n" "$1" >&2; }

# ── Platform helpers ───────────────────────────────────────────

check_os() {
  case "$(uname -s)" in
    Darwin*|Linux*) ;;
    *) log_error "Unsupported OS: $(uname -s). This script supports macOS and Linux only."
       exit 1 ;;
  esac
}

resolve_path() {
  if command -v realpath &>/dev/null; then
    realpath "$1" 2>/dev/null && return
  fi
  if command -v greadlink &>/dev/null; then
    greadlink -f "$1" 2>/dev/null && return
  fi
  if readlink -f "$1" &>/dev/null 2>&1; then
    readlink -f "$1" && return
  fi
  (cd "$(dirname "$1")" 2>/dev/null && echo "$(pwd)/$(basename "$1")")
}

# ── Run context ────────────────────────────────────────────────

detect_run_context() {
  if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${SCRIPT_DIR}/skills.json" ]]; then
      RUN_CONTEXT="local"
      return
    fi
  fi
  RUN_CONTEXT="remote"
}

# ── Prerequisites ──────────────────────────────────────────────

check_prerequisites() {
  if ! command -v git &>/dev/null; then
    log_error "git is required but not installed."
    exit 1
  fi
}

# ── Symlink support test ──────────────────────────────────────

test_symlink_support() {
  local target_dir="$1"
  local test_src test_link

  test_src="$(mktemp -d)"
  test_link="${target_dir}/.symlink-test-$$"

  if ! ln -s "$test_src" "$test_link" 2>/dev/null; then
    rm -rf "$test_src"
    log_error "Symlink creation failed in $target_dir — check directory permissions."
    exit 1
  fi

  rm -f "$test_link"
  rm -rf "$test_src"
}

# ── JSON parsing ──────────────────────────────────────────────

parse_skills_json() {
  local json_file="$1"

  if [[ ! -f "$json_file" ]]; then
    log_error "skills.json not found at $json_file"
    exit 1
  fi

  SKILL_NAMES=()
  SKILL_DIRS=()
  SKILL_DESCS=()

  if command -v jq &>/dev/null; then
    while IFS=$'\t' read -r name dir desc; do
      SKILL_NAMES+=("$name")
      SKILL_DIRS+=("$dir")
      SKILL_DESCS+=("$desc")
    done < <(jq -r '.[] | [.name, .directory, .description] | @tsv' "$json_file")
  else
    _parse_skills_json_fallback "$json_file"
  fi
}

_parse_skills_json_fallback() {
  local json_file="$1"
  local name="" dir="" desc="" line=""

  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    case "$line" in
      '"name"'*)
        name="${line#*: \"}"
        name="${name%\"*}"
        ;;
      '"directory"'*)
        dir="${line#*: \"}"
        dir="${dir%\"*}"
        ;;
      '"description"'*)
        desc="${line#*: \"}"
        desc="${desc%\"*}"
        ;;
      '}'*)
        if [[ -n "$name" ]] && [[ -n "$dir" ]]; then
          SKILL_NAMES+=("$name")
          SKILL_DIRS+=("$dir")
          SKILL_DESCS+=("$desc")
        fi
        name="" dir="" desc=""
        ;;
    esac
  done < "$json_file"
}

# ── Filtering ─────────────────────────────────────────────────

skill_matches_filter() {
  local name="$1" dir="$2"
  local category="${dir%%/*}"

  if [[ -n "$FILTER_SKILLS" ]] && [[ -n "$FILTER_CATEGORY" ]]; then
    _name_in_list "$name" "$FILTER_SKILLS" && return 0
    [[ "$category" == "$FILTER_CATEGORY" ]] && return 0
    return 1
  fi

  if [[ -n "$FILTER_SKILLS" ]]; then
    _name_in_list "$name" "$FILTER_SKILLS" && return 0
    return 1
  fi

  if [[ -n "$FILTER_CATEGORY" ]]; then
    [[ "$category" == "$FILTER_CATEGORY" ]] && return 0
    return 1
  fi

  if [[ "$INSTALL_ALL" == true ]]; then
    return 0
  fi

  [[ "$name" == "setup-kilians-skills" ]]
}

_name_in_list() {
  local name="$1" list="$2"
  local IFS=','
  for item in $list; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ "$item" == "$name" ]] && return 0
  done
  return 1
}

# ── Symlink operations ────────────────────────────────────────

create_skill_symlink() {
  local name="$1" skill_dir="$2" target_base="$3" repo="$4"
  local source target existing

  source="$(resolve_path "${repo}/${skill_dir}")"
  target="${target_base}/${name}"

  if [[ ! -d "$source" ]]; then
    log_warn "Source directory missing: ${source} — skipping ${name}"
    return 2
  fi

  if [[ -L "$target" ]]; then
    existing="$(resolve_path "$target")"
    if [[ "$existing" == "$source" ]]; then
      return 1
    else
      log_warn "${name}: symlink exists but points to ${existing} — skipping"
      return 2
    fi
  elif [[ -d "$target" ]]; then
    log_warn "${name}: directory exists (not a symlink) — skipping"
    return 2
  fi

  if ln -s "$source" "$target" 2>/dev/null; then
    return 0
  else
    log_warn "Failed to create symlink for ${name}"
    return 2
  fi
}

remove_skill_symlink() {
  local name="$1" target_base="$2" repo="$3"
  local target existing resolved_repo

  target="${target_base}/${name}"
  resolved_repo="$(resolve_path "$repo")"

  if [[ ! -L "$target" ]]; then
    return 1
  fi

  existing="$(resolve_path "$target")"
  if [[ "$existing" == "${resolved_repo}"/* ]]; then
    rm "$target"
    return 0
  else
    return 1
  fi
}

# ── Operations ────────────────────────────────────────────────

do_install() {
  local repo_dir="$REPO_DIR"

  if [[ "$RUN_CONTEXT" == "remote" ]]; then
    if [[ -d "$repo_dir" ]]; then
      log_info "Repository already exists at ${repo_dir}"
    else
      log_info "Cloning skills repository..."
      mkdir -p "$(dirname "$repo_dir")"
      if ! git clone "$REPO_URL" "$repo_dir"; then
        log_error "Failed to clone repository. Check your network and try again."
        exit 1
      fi
      log_success "Cloned to ${repo_dir}"
    fi
  else
    repo_dir="$SCRIPT_DIR"
  fi

  parse_skills_json "${repo_dir}/skills.json"

  local total=${#SKILL_NAMES[@]}
  if [[ $total -eq 0 ]]; then
    log_error "No skills found in skills.json"
    exit 1
  fi

  mkdir -p "$TARGET_DIR"
  test_symlink_support "$TARGET_DIR"

  local created=0 unchanged=0 skipped=0
  for i in "${!SKILL_NAMES[@]}"; do
    if ! skill_matches_filter "${SKILL_NAMES[$i]}" "${SKILL_DIRS[$i]}"; then
      continue
    fi

    create_skill_symlink "${SKILL_NAMES[$i]}" "${SKILL_DIRS[$i]}" "$TARGET_DIR" "$repo_dir"
    case $? in
      0) ((created++)) ;;
      1) ((unchanged++)) ;;
      2) ((skipped++)) ;;
    esac
  done

  echo ""
  log_success "Install complete"
  printf "  Repository:  %s\n" "$repo_dir"
  printf "  Target:      %s\n" "$TARGET_DIR"
  printf "  Created: %d | Unchanged: %d | Skipped: %d\n" "$created" "$unchanged" "$skipped"
  _print_skill_list "$repo_dir"
}

do_update() {
  local repo_dir="$REPO_DIR"
  [[ "$RUN_CONTEXT" == "local" ]] && repo_dir="$SCRIPT_DIR"

  if [[ ! -d "$repo_dir" ]]; then
    log_error "Skills repo not found at ${repo_dir}. Run 'setup.sh install' first."
    exit 1
  fi

  if [[ -d "${repo_dir}/.git" ]]; then
    log_info "Pulling latest changes..."
    if ! git -C "$repo_dir" pull --ff-only 2>/dev/null; then
      log_warn "Pull failed (local changes or network issue). Refreshing symlinks from current state."
    else
      log_success "Repository updated"
    fi
  else
    log_warn "${repo_dir} is not a git repository — skipping pull"
  fi

  parse_skills_json "${repo_dir}/skills.json"
  mkdir -p "$TARGET_DIR"

  local created=0 unchanged=0 skipped=0 removed=0
  for i in "${!SKILL_NAMES[@]}"; do
    create_skill_symlink "${SKILL_NAMES[$i]}" "${SKILL_DIRS[$i]}" "$TARGET_DIR" "$repo_dir"
    case $? in
      0) ((created++)) ;;
      1) ((unchanged++)) ;;
      2) ((skipped++)) ;;
    esac
  done

  local resolved_repo
  resolved_repo="$(resolve_path "$repo_dir")"
  if [[ -d "$TARGET_DIR" ]]; then
    for link in "$TARGET_DIR"/*; do
      [[ -L "$link" ]] || continue
      local link_name link_target
      link_name="$(basename "$link")"
      link_target="$(resolve_path "$link" 2>/dev/null || true)"

      if [[ "$link_target" == "${resolved_repo}"/* ]]; then
        local found=false
        for name in "${SKILL_NAMES[@]}"; do
          [[ "$name" == "$link_name" ]] && { found=true; break; }
        done
        if [[ "$found" == false ]]; then
          rm "$link"
          log_info "Removed stale symlink: ${link_name}"
          ((removed++))
        fi
      fi

      if [[ -L "$link" ]] && [[ ! -e "$link" ]]; then
        rm "$link"
        log_info "Removed broken symlink: ${link_name}"
        ((removed++))
      fi
    done
  fi

  echo ""
  log_success "Update complete"
  printf "  New: %d | Unchanged: %d | Removed: %d | Skipped: %d\n" \
    "$created" "$unchanged" "$removed" "$skipped"
}

do_uninstall() {
  local repo_dir="$REPO_DIR"
  [[ "$RUN_CONTEXT" == "local" ]] && repo_dir="$SCRIPT_DIR"

  local removed=0

  if [[ -f "${repo_dir}/skills.json" ]]; then
    parse_skills_json "${repo_dir}/skills.json"
    for i in "${!SKILL_NAMES[@]}"; do
      if remove_skill_symlink "${SKILL_NAMES[$i]}" "$TARGET_DIR" "$repo_dir"; then
        ((removed++))
      fi
    done
  fi

  local resolved_repo
  resolved_repo="$(resolve_path "$repo_dir" 2>/dev/null || echo "$repo_dir")"
  if [[ -d "$TARGET_DIR" ]]; then
    for link in "$TARGET_DIR"/*; do
      [[ -L "$link" ]] || continue
      local link_target
      link_target="$(resolve_path "$link" 2>/dev/null || true)"
      if [[ "$link_target" == "${resolved_repo}"/* ]]; then
        local link_name
        link_name="$(basename "$link")"
        rm "$link"
        ((removed++))
      fi
    done
  fi

  echo ""
  log_success "Removed ${removed} symlinks"

  if [[ "$KEEP_REPO" == false ]] && [[ -d "$repo_dir" ]] && [[ "$RUN_CONTEXT" == "remote" ]]; then
    rm -rf "$repo_dir"
    rmdir "$(dirname "$repo_dir")" 2>/dev/null || true
    log_success "Deleted ${repo_dir}"
  fi
}

# ── Helpers ───────────────────────────────────────────────────

_print_skill_list() {
  local repo_dir="$1"
  local categories=() cat_skills=()

  for i in "${!SKILL_NAMES[@]}"; do
    local category="${SKILL_DIRS[$i]%%/*}"
    local found=false
    for ci in "${!categories[@]}"; do
      if [[ "${categories[$ci]}" == "$category" ]]; then
        cat_skills[$ci]="${cat_skills[$ci]}, ${SKILL_NAMES[$i]}"
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      categories+=("$category")
      cat_skills+=("${SKILL_NAMES[$i]}")
    fi
  done

  echo ""
  for ci in "${!categories[@]}"; do
    printf "  ${BOLD}%s/${RESET}  %s\n" "${categories[$ci]}" "${cat_skills[$ci]}"
  done
}

# ── Usage ─────────────────────────────────────────────────────

show_usage() {
  cat <<'USAGE'
setup.sh — Install, update, or uninstall Kilian's Claude Code skills

Usage:
  setup.sh install   [options]   Clone repo (if needed) and symlink skills
  setup.sh update    [options]   Pull latest and refresh symlinks
  setup.sh uninstall [options]   Remove symlinks and cloned repo

Options:
  --all                  Install all skills (default: only setup-kilians-skills)
  --skill <name> ...     Install specific skills (space-separated)
  --category <name>      Install skills from a category (engineering, productivity)
  --project              Install to .claude/skills/ in cwd (default: global)
  --repo-url URL         Override git clone URL
  --keep-repo            On uninstall, keep the cloned repo (only remove symlinks)
  --help, -h             Show this help

Examples:
  # Install setup-kilians-skills (default)
  ./setup.sh install

  # Install all skills globally
  ./setup.sh install --all

  # Install only engineering skills
  ./setup.sh install --category engineering

  # Install specific skills to current project
  ./setup.sh install --project --skill tdd diagnose

  # Update to latest
  ./setup.sh update

  # Uninstall but keep the repo
  ./setup.sh uninstall --keep-repo

  # First-time install via curl
  curl -fsSL https://raw.githubusercontent.com/Unmovable8911/claude-skills/main/setup.sh | bash
USAGE
}

# ── Argument parsing ──────────────────────────────────────────

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      install|update|uninstall)
        COMMAND="$1" ;;
      --project)
        USE_PROJECT=true ;;
      --skill)
        shift
        [[ $# -eq 0 || "$1" == --* ]] && { log_error "--skill requires at least one skill name"; exit 1; }
        FILTER_SKILLS="$1"
        shift
        while [[ $# -gt 0 ]] && [[ "$1" != --* ]] && [[ "$1" != install ]] && [[ "$1" != update ]] && [[ "$1" != uninstall ]]; do
          FILTER_SKILLS="${FILTER_SKILLS},$1"
          shift
        done
        continue
        ;;
      --category)
        shift; FILTER_CATEGORY="${1:-}"
        [[ -z "$FILTER_CATEGORY" ]] && { log_error "--category requires a value"; exit 1; }
        ;;
      --repo-url)
        shift; REPO_URL="${1:-}"
        [[ -z "$REPO_URL" ]] && { log_error "--repo-url requires a value"; exit 1; }
        ;;
      --all)
        INSTALL_ALL=true ;;
      --keep-repo)
        KEEP_REPO=true ;;
      --help|-h)
        show_usage; exit 0 ;;
      *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
    shift
  done

  [[ -z "$COMMAND" ]] && COMMAND="install"
}

# ── Main ──────────────────────────────────────────────────────

main() {
  parse_args "$@"
  setup_colors
  check_os
  detect_run_context
  check_prerequisites

  if [[ -z "$REPO_DIR" ]]; then
    if [[ "$RUN_CONTEXT" == "local" ]]; then
      REPO_DIR="$SCRIPT_DIR"
    else
      REPO_DIR="$DEFAULT_REPO_DIR"
    fi
  fi
  [[ -z "$REPO_URL" ]] && REPO_URL="$DEFAULT_REPO_URL"

  if [[ "$USE_PROJECT" == true ]]; then
    TARGET_DIR="$(pwd)/.claude/skills"
  else
    TARGET_DIR="${HOME}/.claude/skills"
  fi

  echo ""
  printf "  ${BOLD}Kilian's Claude Code Skills${RESET}\n"
  echo ""

  case "$COMMAND" in
    install)   do_install   ;;
    update)    do_update    ;;
    uninstall) do_uninstall ;;
  esac

  echo ""
}

main "$@"
