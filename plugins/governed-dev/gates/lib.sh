#!/usr/bin/env bash
# Shared helpers for gate checks. Sourced by gate.sh, never executed directly.
# Verification only: nothing here writes to the repository.

# The gate inspects the CONSUMING PROJECT'S code. ${CLAUDE_PROJECT_DIR} is the
# authority; the git root is a fallback so the script also works standalone.
# Never root this at ${CLAUDE_PLUGIN_ROOT} -- that is where the gate LIVES, not
# what it checks, and a gate pointed at its own source passes unconditionally.
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" 2>/dev/null || {
  printf 'GATE FAIL: cannot enter %s. Set CLAUDE_PROJECT_DIR to the project root.\n' "$ROOT" >&2
  exit 2
}

# die() always exits 2. Never 1: Claude Code treats exit 1 as a non-blocking
# error and proceeds, which would silently turn this gate into a suggestion.
die()  { printf 'GATE FAIL [%s]: %s\n' "${CHECK:-gate}" "$1" >&2; exit 2; }
note() { printf 'gate: %s\n' "$1" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Windows ships a python3 shim that resolves on PATH but only prints a Store
# advert when run. Return the first interpreter that actually executes, not the
# first that resolves -- otherwise the gate blocks a working environment.
python_bin() {
  local p
  for p in python3 python py; do
    command -v "$p" >/dev/null 2>&1 || continue
    "$p" -c 'import sys' >/dev/null 2>&1 && { printf '%s' "$p"; return 0; }
  done
  return 1
}

require_git() {
  git rev-parse --git-dir >/dev/null 2>&1 || die \
"$ROOT is not a git repository, so changed files cannot be determined. Run 'git init' here, or point CLAUDE_PROJECT_DIR at the real project root."
}

# Everything changed since the last commit: staged, unstaged, and untracked.
changed_files() {
  { git diff HEAD --name-only 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
}
