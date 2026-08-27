#!/usr/bin/env bash
#
# lib.sh -- shared helpers for the hook scripts in this directory. Sourced by
# them, never executed directly.
#
# Every hook reads one JSON event on stdin and answers with some combination of
# an exit code, a JSON object on stdout, and text on stderr. The contract is
# per-event and is documented in ./README.md; ./hooks.json wires it up.
#
# EXIT CODES ARE NOT UNIFORM ACROSS EVENTS. Exit 2 blocks PreToolUse, Stop,
# SubagentStop and PreCompact; it is merely reported for SessionStart,
# SessionEnd, Setup and PostToolUse. A script here must know which event it
# serves before it decides to exit 2 -- exiting 2 from the PreCompact hook
# would block compaction, which is the opposite of what that hook is for.
#
# Deliberately not `set -e`, for the same reason gates/gate.sh omits it: exit
# codes carry meaning here, and -e surfaces failures as exit 1, which blocks
# nothing anywhere.
set -uo pipefail

HOOK_NAME="${HOOK_NAME:-hook}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

hook_note() { printf 'hook [%s]: %s\n' "$HOOK_NAME" "$1" >&2; }
hook_die()  { printf 'HOOK FAIL [%s]: %s\n' "$HOOK_NAME" "$1" >&2; exit 2; }

# The event JSON arrives on stdin exactly once. Read it here so every script
# consumes it identically and none of them can consume it twice.
HOOK_JSON="$(cat 2>/dev/null || true)"

have() { command -v "$1" >/dev/null 2>&1; }

# jq is not always on PATH even when it is installed. winget drops it in a Links
# directory that only reaches processes started AFTER the install, and a session
# already running never sees it -- so a freshly installed jq looks missing to
# every hook this session spawns. gates/gate.ps1 already solves the same problem
# for bash by probing the standard install locations rather than trusting PATH;
# this is that pattern, for jq.
_jq_dir() {
  local d
  for d in \
    "${LOCALAPPDATA:-}/Microsoft/WinGet/Links" \
    "${USERPROFILE:-}/AppData/Local/Microsoft/WinGet/Links" \
    "/c/Program Files/jq" \
    "/usr/local/bin" \
    "/opt/homebrew/bin"
  do
    [ -n "$d" ] || continue
    [ -x "$d/jq" ] || [ -x "$d/jq.exe" ] || continue
    printf '%s' "$d"; return 0
  done
  # winget's Packages tree, whose leaf directory carries a version-dependent name.
  [ -n "${LOCALAPPDATA:-}" ] || return 1
  d="$(ls -d "$LOCALAPPDATA"/Microsoft/WinGet/Packages/jqlang.jq_* 2>/dev/null | head -1)"
  [ -n "$d" ] && [ -e "$d/jq.exe" ] && { printf '%s' "$d"; return 0; }
  return 1
}
if ! have jq; then
  _d="$(_jq_dir)" && [ -n "$_d" ] && PATH="$_d:$PATH" && export PATH
  unset _d
fi

# jq is a hard dependency of these hooks: they parse a JSON event and emit JSON
# decisions, and hand-rolled JSON escaping in shell is how a deny reason
# containing a quote turns into a malformed object that the harness discards --
# a boundary that silently stops enforcing. Callers decide how to react to its
# absence, because the right reaction differs by event. See hook_jq_advice.
have_jq() { have jq; }

hook_jq_advice() {
  printf 'jq is not installed, and these hooks parse and emit JSON with it.\n'
  printf 'Install it, then start a new session:\n'
  printf '  Windows   winget install --id jqlang.jq -e\n'
  printf '  macOS     brew install jq\n'
  printf '  Debian    sudo apt-get install jq\n'
}

# Read a field from the event. Missing fields come back as the empty string
# rather than the string "null", so `[ -n "$x" ]` is a valid presence test.
hook_field() {
  have_jq || return 1
  printf '%s' "$HOOK_JSON" | jq -r "${1} // empty" 2>/dev/null
}

# Read MANY fields in ONE jq. `hook_field` above spawns a jq per call, and
# boundary.sh needed four before it did any thinking -- on every Edit, Write,
# NotebookEdit, Bash and PowerShell call, in every governed session. That is the
# cost a consumer feels most, because it is per-keystroke rather than per-turn
# (ADR-0031).
#
# Usage:  hook_fields VAR1 'jq-expr-1' VAR2 'jq-expr-2' ...
# Sets each VAR to its expression's value, empty string when absent, exactly as
# hook_field does. Returns non-zero if jq could not produce every field, leaving
# the caller to treat that as it treats a missing field.
#
# THE DELIMITER IS NUL, AND THAT IS THE WHOLE POINT. The obvious encoding --
# `jq -r '[...] | @tsv'` and a read-split -- is WRONG here, and verified so
# rather than supposed: @tsv escapes a literal tab to the two characters `\t`
# and a literal newline to `\n`, so a Bash command containing either comes back
# as a DIFFERENT STRING from the one the agent ran. boundary.sh rules on that
# text (ADR-0013), so the encoding would decide verdicts. Newline-delimiting
# fails on the same input for the same reason. NUL is the one byte that cannot
# appear in a shell variable anyway, which makes it the only delimiter that
# cannot collide with a field's contents.
#
# Process substitution, not a pipe: the `while` must run in THIS shell or the
# variables it sets would die with the subshell.
hook_fields() {
  have_jq || return 1
  local _prog="" _n=0 _i=0 _v
  local _names
  _names=()
  while [ "$#" -gt 1 ]; do
    _names[$_n]="$1"
    _prog="$_prog(${2} // \"\"), \"\u0000\", "
    _n=$((_n + 1))
    shift 2
  done
  [ "$_n" -gt 0 ] || return 0
  _prog="${_prog%, }"

  while IFS= read -r -d '' _v; do
    [ "$_i" -lt "$_n" ] || break
    printf -v "${_names[$_i]}" '%s' "$_v"
    _i=$((_i + 1))
  done < <(printf '%s' "$HOOK_JSON" | jq -j "$_prog" 2>/dev/null)

  [ "$_i" -eq "$_n" ]
}

# The project under change. ${CLAUDE_PROJECT_DIR} is the authority, matching
# gates/lib.sh; the event's own cwd is the fallback. Never ${CLAUDE_PLUGIN_ROOT}
# -- see the _CONVENTION notes in hooks.json.
hook_root() {
  local r="${CLAUDE_PROJECT_DIR:-}"
  # A caller that already read .cwd in a hook_fields batch sets HOOK_CWD, so
  # this costs no second jq. Unset, the lookup below is unchanged.
  [ -n "$r" ] || r="${HOOK_CWD:-}"
  [ -n "$r" ] || r="$(hook_field '.cwd')"
  [ -n "$r" ] || r="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  printf '%s' "$r"
}

# The gate lives beside these hooks, one level up, in both worlds: installed,
# that is <cache>/governed-dev/<sha>/gates/; from a checkout, it is
# plugins/governed-dev/gates/. So the path relative to THIS FILE is always the
# gate belonging to the same copy of the plugin as the script now running.
#
# ${CLAUDE_PLUGIN_ROOT} is only the fallback, and deliberately second. devseed
# wires these same scripts from its own .claude/settings.json against the
# working tree while a STALE copy of the plugin is also installed; taking the
# env var first would run the working tree's hook against the installed copy's
# gate -- two different definitions of done in one invocation.
hook_gate() {
  local sibling="$HOOK_DIR/../gates/gate.sh"
  if [ -f "$sibling" ]; then printf '%s' "$sibling"
  else printf '%s/gates/gate.sh' "${CLAUDE_PLUGIN_ROOT:-$HOOK_DIR/..}"; fi
}

# Scratch state shared between hooks within one session: the HEAD a session
# started at, the last gate result, the Stop-hook block counter. Hooks write to
# the project; the GATE does not, and that asymmetry is deliberate -- see
# README.md. Ignored by git via .gitignore.
hook_state_dir() {
  local d
  d="$(hook_root)/.claude/.hook-state"
  mkdir -p "$d" 2>/dev/null || return 1
  printf '%s' "$d"
}

# Session ids come from the harness and are used in filenames. Strip anything
# that is not safe in a path rather than trusting the format.
hook_session_slug() {
  local s
  s="$(hook_field '.session_id')"
  [ -n "$s" ] || s="nosession"
  printf '%s' "$s" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64
}

# Plugin agents are namespaced on install -- "governed-dev:implementer", not
# "implementer". Match on the bare name so a boundary does not evaporate the
# moment the plugin is installed rather than run from a checkout.
hook_agent_type() {
  local a
  a="$(hook_field '.agent_type')"
  printf '%s' "${a##*:}"
}

# Everything changed since the last commit, artifacts filtered, mirroring
# gates/lib.sh changed_files(). Duplicated rather than sourced: gates/lib.sh
# cd's to the project root and exits 2 on failure, which is correct for a gate
# and wrong for a hook that must not take the session down with it.
hook_changed_files() {
  local root; root="$(hook_root)"
  { git -C "$root" diff HEAD --name-only 2>/dev/null
    git -C "$root" ls-files --others --exclude-standard 2>/dev/null
  } | grep -Ev '(^|/)(__pycache__|\.pytest_cache|\.ruff_cache|\.mypy_cache|node_modules|dist|build|htmlcov|\.nyc_output)/|\.pyc$|(^|/)(\.coverage|coverage\.xml|\.coverage\..*)$' | sort -u
}
