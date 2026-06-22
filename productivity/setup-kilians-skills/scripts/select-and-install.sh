#!/usr/bin/env bash
# select-and-install.sh — List available skills and install selected ones via symlinks
#
# Usage:
#   select-and-install.sh list    [--repo-dir DIR] [--global-dir DIR] [--project-dir DIR]
#   select-and-install.sh install [--repo-dir DIR] --target-dir DIR --skills SELECTION

set -uo pipefail

# ── Derive repo root from script location ─────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

COMMAND=""
REPO_DIR=""
TARGET_DIR=""
SKILL_SELECTION=""
GLOBAL_DIR=""
PROJECT_DIR=""

SKILL_NAMES=()
SKILL_DIRS=()
SKILL_DESCS=()

# ── Colors ────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  BLUE='\033[0;34m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
  RED='\033[0;31m' BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'
else
  BLUE="" GREEN="" YELLOW="" RED="" BOLD="" DIM="" RESET=""
fi

log_info()    { printf "${BLUE}::${RESET} %s\n" "$1"; }
log_success() { printf "${GREEN}ok${RESET} %s\n" "$1"; }
log_warn()    { printf "${YELLOW}!!${RESET} %s\n" "$1"; }
log_error()   { printf "${RED}** %s${RESET}\n" "$1" >&2; }

# ── Path resolution ───────────────────────────────────────────

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

# ── JSON parsing ─────────────────────────────────────────────

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
    _parse_json_fallback "$json_file"
  fi
}

_parse_json_fallback() {
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

# ── Install status check ─────────────────────────────────────

check_install_status() {
  local skill_name="$1"
  local skill_source="$2"
  local in_global=false
  local in_project=false

  if [[ -n "$GLOBAL_DIR" ]] && [[ -L "${GLOBAL_DIR}/${skill_name}" ]]; then
    local target
    target="$(resolve_path "${GLOBAL_DIR}/${skill_name}")"
    [[ "$target" == "$skill_source" ]] && in_global=true
  fi

  if [[ -n "$PROJECT_DIR" ]] && [[ -L "${PROJECT_DIR}/${skill_name}" ]]; then
    local target
    target="$(resolve_path "${PROJECT_DIR}/${skill_name}")"
    [[ "$target" == "$skill_source" ]] && in_project=true
  fi

  if $in_global && $in_project; then
    echo "global+project"
  elif $in_global; then
    echo "global"
  elif $in_project; then
    echo "project"
  else
    echo ""
  fi
}

# ── List command ─────────────────────────────────────────────

do_list() {
  parse_skills_json "${REPO_DIR}/skills.json"

  local total=${#SKILL_NAMES[@]}
  if [[ $total -eq 0 ]]; then
    log_error "No skills found in skills.json"
    exit 1
  fi

  local categories=()
  local cat_indices=()

  for i in "${!SKILL_NAMES[@]}"; do
    local category="${SKILL_DIRS[$i]%%/*}"
    local found=false
    for ci in "${!categories[@]}"; do
      if [[ "${categories[$ci]}" == "$category" ]]; then
        cat_indices[$ci]="${cat_indices[$ci]} $i"
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      categories+=("$category")
      cat_indices+=("$i")
    fi
  done

  local installed_count=0
  local statuses=()
  for i in "${!SKILL_NAMES[@]}"; do
    local source
    source="$(resolve_path "${REPO_DIR}/${SKILL_DIRS[$i]}")"
    local status
    status="$(check_install_status "${SKILL_NAMES[$i]}" "$source")"
    statuses+=("$status")
    [[ -n "$status" ]] && ((installed_count++))
  done

  echo ""
  printf "  ${BOLD}Available Skills${RESET}  ${DIM}(%d total, %d installed)${RESET}\n" "$total" "$installed_count"
  echo ""

  local max_name_len=0
  for name in "${SKILL_NAMES[@]}"; do
    [[ ${#name} -gt $max_name_len ]] && max_name_len=${#name}
  done
  [[ $max_name_len -lt 4 ]] && max_name_len=4

  for ci in "${!categories[@]}"; do
    local cat="${categories[$ci]}"
    printf "  ${BOLD}${BLUE}%s/${RESET}\n" "$cat"

    local indices
    IFS=' ' read -ra indices <<< "${cat_indices[$ci]}"
    for i in "${indices[@]}"; do
      local num=$((i + 1))
      local name="${SKILL_NAMES[$i]}"
      local desc="${SKILL_DESCS[$i]}"
      local status="${statuses[$i]}"

      if [[ ${#desc} -gt 55 ]]; then
        desc="${desc:0:52}..."
      fi

      local status_str=""
      if [[ -n "$status" ]]; then
        status_str=" ${GREEN}[${status}]${RESET}"
      fi

      printf "    ${BOLD}%2d${RESET}  %-${max_name_len}s  ${DIM}%-57s${RESET}%s\n" "$num" "$name" "$desc" "$status_str"
    done
    echo ""
  done

  printf "  ${DIM}Select by number (e.g. 1,3,5), name (e.g. tdd,diagnose), or 'all'.${RESET}\n"
  echo ""
}

# ── Install command ──────────────────────────────────────────

do_install() {
  parse_skills_json "${REPO_DIR}/skills.json"

  local total=${#SKILL_NAMES[@]}
  if [[ $total -eq 0 ]]; then
    log_error "No skills found in skills.json"
    exit 1
  fi

  if [[ -z "$TARGET_DIR" ]]; then
    log_error "--target-dir is required for install"
    exit 1
  fi

  if [[ -z "$SKILL_SELECTION" ]]; then
    log_error "--skills is required for install"
    exit 1
  fi

  local selected_indices=()

  if [[ "$SKILL_SELECTION" == "all" ]]; then
    for i in "${!SKILL_NAMES[@]}"; do
      selected_indices+=("$i")
    done
  else
    IFS=',' read -ra items <<< "$SKILL_SELECTION"
    for item in "${items[@]}"; do
      item="${item#"${item%%[![:space:]]*}"}"
      item="${item%"${item##*[![:space:]]}"}"

      if [[ "$item" =~ ^[0-9]+$ ]]; then
        local idx=$((item - 1))
        if [[ $idx -ge 0 ]] && [[ $idx -lt $total ]]; then
          selected_indices+=("$idx")
        else
          log_warn "Invalid number: $item (valid range: 1-$total)"
        fi
      else
        local found=false
        for i in "${!SKILL_NAMES[@]}"; do
          if [[ "${SKILL_NAMES[$i]}" == "$item" ]]; then
            selected_indices+=("$i")
            found=true
            break
          fi
        done
        if [[ "$found" == false ]]; then
          log_warn "Unknown skill: $item"
        fi
      fi
    done
  fi

  if [[ ${#selected_indices[@]} -eq 0 ]]; then
    log_error "No valid skills selected"
    exit 1
  fi

  mkdir -p "$TARGET_DIR"

  # Test symlink support
  local test_src test_link
  test_src="$(mktemp -d)"
  test_link="${TARGET_DIR}/.symlink-test-$$"

  if ! ln -s "$test_src" "$test_link" 2>/dev/null; then
    rm -rf "$test_src"
    log_error "Symlink creation failed in $TARGET_DIR — check directory permissions."
    exit 1
  fi
  rm -f "$test_link"
  rm -rf "$test_src"

  local created=0 unchanged=0 skipped=0

  for idx in "${selected_indices[@]}"; do
    local name="${SKILL_NAMES[$idx]}"
    local skill_dir="${SKILL_DIRS[$idx]}"
    local source target

    source="$(resolve_path "${REPO_DIR}/${skill_dir}")"
    target="${TARGET_DIR}/${name}"

    if [[ ! -d "$source" ]]; then
      log_warn "Source missing: ${source} — skipping ${name}"
      ((skipped++))
      continue
    fi

    if [[ -L "$target" ]]; then
      local existing
      existing="$(resolve_path "$target")"
      if [[ "$existing" == "$source" ]]; then
        ((unchanged++))
        continue
      else
        log_warn "${name}: symlink exists → ${existing} — skipping"
        ((skipped++))
        continue
      fi
    elif [[ -d "$target" ]]; then
      log_warn "${name}: directory exists (not a symlink) — skipping"
      ((skipped++))
      continue
    fi

    if ln -s "$source" "$target" 2>/dev/null; then
      log_success "Linked: ${name}"
      ((created++))
    else
      log_warn "Failed to create symlink for ${name}"
      ((skipped++))
    fi
  done

  echo ""
  log_success "Install complete"
  printf "  Target:     %s\n" "$TARGET_DIR"
  printf "  Created: %d | Unchanged: %d | Skipped: %d\n" "$created" "$unchanged" "$skipped"
  echo ""
}

# ── Argument parsing ─────────────────────────────────────────

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      list|install)
        COMMAND="$1" ;;
      --repo-dir)
        shift; REPO_DIR="${1:-}"
        [[ -z "$REPO_DIR" ]] && { log_error "--repo-dir requires a value"; exit 1; }
        ;;
      --target-dir)
        shift; TARGET_DIR="${1:-}"
        [[ -z "$TARGET_DIR" ]] && { log_error "--target-dir requires a value"; exit 1; }
        ;;
      --skills)
        shift; SKILL_SELECTION="${1:-}"
        [[ -z "$SKILL_SELECTION" ]] && { log_error "--skills requires a value"; exit 1; }
        ;;
      --global-dir)
        shift; GLOBAL_DIR="${1:-}"
        [[ -z "$GLOBAL_DIR" ]] && { log_error "--global-dir requires a value"; exit 1; }
        ;;
      --project-dir)
        shift; PROJECT_DIR="${1:-}"
        [[ -z "$PROJECT_DIR" ]] && { log_error "--project-dir requires a value"; exit 1; }
        ;;
      --help|-h)
        cat <<'USAGE'
select-and-install.sh — List and install skills via symlinks

Usage:
  select-and-install.sh list    [--repo-dir DIR] [--global-dir DIR] [--project-dir DIR]
  select-and-install.sh install [--repo-dir DIR] --target-dir DIR --skills SELECTION

Commands:
  list      Display all available skills with numbers and install status
  install   Create symlinks for selected skills

Options:
  --repo-dir DIR      Skills repository path (default: auto-detected)
  --target-dir DIR    Where to create symlinks (e.g. ~/.claude/skills)
  --skills SELECTION  Comma-separated skill numbers, names, or 'all'
  --global-dir DIR    Global skills dir — used by 'list' to show install status
  --project-dir DIR   Project skills dir — used by 'list' to show install status

Examples:
  select-and-install.sh list
  select-and-install.sh list --global-dir ~/.claude/skills --project-dir .claude/skills
  select-and-install.sh install --target-dir ~/.claude/skills --skills 1,3,5
  select-and-install.sh install --target-dir ~/.claude/skills --skills all
USAGE
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done

  [[ -z "$COMMAND" ]] && { log_error "Command required: list or install"; exit 1; }
  [[ -z "$REPO_DIR" ]] && REPO_DIR="$DEFAULT_REPO_DIR"
}

# ── Main ─────────────────────────────────────────────────────

main() {
  parse_args "$@"

  case "$COMMAND" in
    list)    do_list    ;;
    install) do_install ;;
  esac
}

main "$@"
