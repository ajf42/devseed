#!/usr/bin/env bash
#
# boundary-regression.sh -- asserts hooks/boundary.sh denies what it claims to.
#
# The boundary is the load-bearing mechanism of the whole roster (ADR-0007), and
# it is the kind of thing that fails silently: a matcher that misses, a path
# spelling that does not compare equal, a tool that carries its target in a
# field nobody read. Every defect found in this hook so far was invisible to
# inspection and visible to a synthetic event -- including the one this file
# exists for, where `Bash` carried no file_path and the boundary allowed
# (ADR-0013).
#
# Feeds synthetic PreToolUse events to the hook and checks the decision. No
# agent runs; nothing is written.
#
# devseed's own dev tooling. Not shipped in the plugin.
#
# Usage: bash scripts/boundary-regression.sh   (exit 0 = all assertions passed)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/plugins/governed-dev/hooks/boundary.sh"
PASS=0; FAIL=0

ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }

# event <agent> <tool> <field> <value>  -> one PreToolUse JSON on stdout
event() {
  jq -nc --arg a "$1" --arg t "$2" --arg k "$3" --arg v "$4" --arg c "$ROOT" \
    '{hook_event_name:"PreToolUse", agent_type:$a, tool_name:$t, cwd:$c,
      session_id:"regression", tool_input:{($k):$v}}'
}

# assert <expect deny|allow> <desc> <agent> <tool> <field> <value> [needle]
assert() {
  local want="$1" desc="$2" agent="$3" tool="$4" field="$5" val="$6" needle="${7:-}"
  local out got decision
  out="$( event "$agent" "$tool" "$field" "$val" | CLAUDE_PROJECT_DIR="$ROOT" bash "$HOOK" 2>/dev/null )"
  got=$?

  decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null)"
  [ -n "$decision" ] || decision=allow

  if [ "$decision" = "$want" ]; then ok "$desc"; else bad "$desc -- wanted $want, got $decision"; fi
  [ "$got" = 0 ] || bad "$desc -- hook exited $got; a JSON decision is only honoured on exit 0"

  if [ -n "$needle" ]; then
    local reason; reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null)"
    case "$reason" in
      *"$needle"*) ok "$desc -- reason names '$needle'" ;;
      *)           bad "$desc -- reason does not name '$needle'"; printf '        %s\n' "$reason" ;;
    esac
  fi
}

# jq is installed here but off PATH -- winget's Links directory only reaches
# processes started after the install. The hooks' lib.sh solves this for the
# hooks; this harness needs it too, and cannot source that file because it
# consumes stdin on load. Same lookup, kept short.
if ! command -v jq >/dev/null 2>&1; then
  for _d in "$HOME/AppData/Local/Microsoft/WinGet/Links" "/c/Program Files/jq" \
            "/c/ProgramData/chocolatey/bin" "/usr/local/bin" "/opt/homebrew/bin" \
            $(ls -d "${LOCALAPPDATA:-$HOME/AppData/Local}"/Microsoft/WinGet/Packages/jqlang.jq_* 2>/dev/null); do
    if [ -x "$_d/jq" ] || [ -e "$_d/jq.exe" ]; then PATH="$_d:$PATH"; export PATH; break; fi
  done
fi
command -v jq >/dev/null 2>&1 || {
  printf 'boundary-regression: jq is required to build synthetic events.\n' >&2
  printf '  Windows  winget install --id jqlang.jq -e\n' >&2
  exit 2
}

printf 'boundary regression: %s\n\n' "$HOOK"

# --- Path boundaries (Edit/Write/NotebookEdit) --------------------------------
echo "path boundaries -- the three ledger documents:"
assert deny  "implementer may not Edit DECISIONS.md" \
  implementer Edit file_path "$ROOT/DECISIONS.md" "scribe"
assert deny  "implementer may not Write DESIGN.md" \
  implementer Write file_path "$ROOT/DESIGN.md" "amendment"
assert deny  "implementer may not Edit TASKS.md" \
  implementer Edit file_path "$ROOT/TASKS.md" "scribe"
assert allow "implementer MAY Edit code" \
  implementer Edit file_path "$ROOT/src/m.py"
assert allow "implementer MAY Edit CLAUDE.md (gate check 4 requires it)" \
  implementer Edit file_path "$ROOT/CLAUDE.md"
assert allow "implementer MAY Edit a shipped template skeleton" \
  implementer Edit file_path "$ROOT/plugins/governed-dev/templates/DECISIONS.md"

# ADR-0029 moved the ADRs out of DECISIONS.md into docs/adr/. Denying the file
# but not the directory it became would have silently reopened the route this
# boundary exists to close -- the implementer editing the record that justifies
# its own work. Archived entries are the same record and carry the same denial.
assert deny  "implementer may not Edit an ADR file" \
  implementer Edit file_path "$ROOT/docs/adr/0001-split-plugin-content.md" "scribe"
assert deny  "implementer may not Edit an ARCHIVED ADR file" \
  implementer Edit file_path "$ROOT/docs/adr/archive/0021-headless-auditor-action.md" "scribe"
assert deny  "implementer may not redirect into docs/adr/ via the shell" \
  implementer Bash command 'echo x >> docs/adr/0001-split-plugin-content.md' "scribe"

echo
echo "path boundaries -- Windows drive-letter spelling (regression, T-005):"
assert deny  "implementer denied via C:/ spelling" \
  implementer Edit file_path "C:/Users/themu/Projects/devseed/devseed/DECISIONS.md" "scribe"
assert deny  "implementer denied via backslash spelling" \
  implementer Edit file_path 'C:\Users\themu\Projects\devseed\devseed\DECISIONS.md' "scribe"

echo
echo "path boundaries -- the other agents:"
assert allow "scribe MAY Edit DECISIONS.md" \
  scribe Edit file_path "$ROOT/DECISIONS.md"
assert allow "scribe MAY Edit an ADR file (it owns them, ADR-0029)" \
  scribe Edit file_path "$ROOT/docs/adr/0001-split-plugin-content.md"
assert allow "scribe MAY Edit an archived ADR file" \
  scribe Edit file_path "$ROOT/docs/adr/archive/0021-headless-auditor-action.md"
assert allow "scribe MAY Edit TASKS.md" \
  scribe Edit file_path "$ROOT/TASKS.md"
assert deny  "scribe may not Edit code" \
  scribe Edit file_path "$ROOT/src/m.py" "implementer"
assert deny  "scribe may not Edit DESIGN.md" \
  scribe Edit file_path "$ROOT/DESIGN.md" "implementer"
assert deny  "reviewer may not Edit anything" \
  reviewer Edit file_path "$ROOT/src/m.py" "read-only"
assert deny  "auditor may not Write anything" \
  auditor Write file_path "$ROOT/report.txt" "read-only"
assert deny  "spec-guardian may not Edit anything" \
  spec-guardian Edit file_path "$ROOT/DESIGN.md" "read-only"
assert deny  "NotebookEdit is watched too (notebook_path)" \
  reviewer NotebookEdit notebook_path "$ROOT/nb.ipynb" "read-only"

echo
echo "path boundaries -- unknown and absent agents:"
assert deny  "an agent with no defined boundary is denied, not assumed safe" \
  some-new-agent Edit file_path "$ROOT/DECISIONS.md" "no boundary defined"
assert allow "main thread (no agent_type) is unbounded -- SG-0005" \
  "" Edit file_path "$ROOT/DECISIONS.md"

# --- Shell boundaries (ADR-0013) ----------------------------------------------
echo
echo "shell boundaries -- the hole ADR-0013 closes:"
assert deny  "implementer: echo >> DECISIONS.md" \
  implementer Bash command 'echo x >> DECISIONS.md' "scribe"
assert deny  "implementer: printf > DESIGN.md" \
  implementer Bash command 'printf "y" > DESIGN.md' "amendment"
assert deny  "implementer: sed -i on TASKS.md" \
  implementer Bash command 'sed -i "s/todo/done/" TASKS.md' "scribe"
assert deny  "implementer: tee into DECISIONS.md" \
  implementer Bash command 'echo x | tee -a DECISIONS.md' "scribe"
assert deny  "implementer: heredoc into DECISIONS.md" \
  implementer Bash command 'cat > DECISIONS.md <<EOF
x
EOF' "scribe"
assert deny  "implementer: python writing DECISIONS.md" \
  implementer Bash command "python -c \"open('DECISIONS.md','a').write('x')\"" "scribe"
assert deny  "implementer: git checkout DECISIONS.md" \
  implementer Bash command 'git checkout -- DECISIONS.md' "scribe"
assert deny  "implementer: even READING a ledger doc via shell (blunt on purpose)" \
  implementer Bash command 'cat DECISIONS.md' "Read and Grep"

echo
echo "shell boundaries -- the implementer must still be able to work:"
assert allow "implementer: run the test suite" \
  implementer Bash command 'pytest -q'
assert allow "implementer: run the gate with a benign redirect" \
  implementer Bash command 'bash plugins/governed-dev/gates/gate.sh 2>&1 | tail -3'
assert allow "implementer: write a source file via shell" \
  implementer Bash command 'printf "x\n" > src/new.py'
assert allow "implementer: read a shipped template skeleton" \
  implementer Bash command 'cat plugins/governed-dev/templates/DECISIONS.md'
assert allow "implementer: git diff" \
  implementer Bash command 'git diff --stat'

echo
echo "shell boundaries -- read-only agents:"
assert allow "reviewer: run tests" \
  reviewer Bash command 'pytest -q'
assert allow "reviewer: run the gate quietly" \
  reviewer Bash command 'bash gate.sh 2>/dev/null'
assert allow "reviewer: git log" \
  reviewer Bash command 'git log --oneline -5'
assert allow "auditor: run the drift guard" \
  auditor Bash command 'bash plugins/governed-dev/gates/drift.sh'
assert deny  "reviewer: any redirect to a real file" \
  reviewer Bash command 'echo findings > review.txt' "read-only"
assert deny  "reviewer: git commit" \
  reviewer Bash command 'git commit -am wip' "read-only"
assert deny  "auditor: writing its report to a file" \
  auditor Bash command 'bash drift.sh > report.txt' "read-only"
assert deny  "auditor: rm" \
  auditor Bash command 'rm -f stale.txt' "read-only"
assert deny  "spec-guardian: shell writes" \
  spec-guardian Bash command 'echo x > note.txt' "read-only"

echo
echo "shell boundaries -- the scribe holds no shell at all:"
assert deny  "scribe: any Bash means the roster and the hook disagree" \
  scribe Bash command 'echo x' "no shell"

echo
echo "shell boundaries -- PowerShell is watched too:"
assert deny  "implementer: PowerShell Add-Content into DECISIONS.md" \
  implementer PowerShell command 'Add-Content DECISIONS.md "x"' "scribe"
assert deny  "reviewer: PowerShell redirect" \
  reviewer PowerShell command 'echo x > out.txt' "read-only"

echo
echo "shell boundaries -- namespaced agent names survive install:"
assert deny  "governed-dev:implementer is matched as implementer" \
  "governed-dev:implementer" Bash command 'echo x >> DECISIONS.md' "scribe"

# --- T-048: the encoding landmine --------------------------------------------
# The obvious way to read many fields in one jq -- `[...] | @tsv` and a
# read-split -- corrupts exactly the input this boundary rules on. @tsv escapes
# a literal tab to the two characters \t and a literal newline to \n, so a
# command carrying either comes back as a DIFFERENT STRING and the shell
# matchers below decide on text the agent never ran (ADR-0013). This was
# reproduced, not supposed, before hook_fields was written; the delimiter is NUL
# because NUL is the one byte that cannot occur in a shell variable.
#
# NOTE ON CR: jq.exe writes stdout in text mode on Windows, so an embedded
# newline arrives as CRLF. That predates this change -- the single-field
# hook_field did it too -- and it is why the comparison below strips CR rather
# than pretending the platform does not. The tab is compared exactly, because
# the tab is what @tsv would have destroyed.
echo
echo "encoding -- a command carrying a literal tab and a literal newline (T-048):"

_TABC="$(printf '\t')"
_CMD_DENY="$(printf 'echo a\tb\ncat x >> DECISIONS.md')"
_CMD_ALLOW="$(printf 'echo a\tb\nls -l')"

assert deny  "multi-line command with a tab still denied when it writes a ledger" \
  implementer Bash command "$_CMD_DENY" "scribe"
assert allow "multi-line command with a tab still allowed when it writes nothing" \
  implementer Bash command "$_CMD_ALLOW"

# What the hook actually read, taken from the same helper the hook uses.
_LIB="$ROOT/plugins/governed-dev/hooks/lib.sh"
_GOT="$( event implementer Bash command "$_CMD_DENY" \
         | ( . "$_LIB" >/dev/null 2>&1; hook_fields _X '.tool_input.command'; printf '%s' "${_X:-}" ) )"

if [ "$(printf '%s' "$_GOT" | tr -d '\r')" = "$(printf '%s' "$_CMD_DENY" | tr -d '\r')" ]; then
  ok "hook_fields returns the command byte-for-byte (CR aside)"
else
  bad "hook_fields altered the command"
  printf '        want: %s\n' "$(printf '%s' "$_CMD_DENY" | od -c | head -3)"
  printf '        got:  %s\n' "$(printf '%s' "$_GOT" | od -c | head -3)"
fi

case "$_GOT" in
  *"$_TABC"*) ok "the literal tab survived as a tab" ;;
  *)          bad "the literal tab did not survive -- the encoding ate it" ;;
esac

case "$_GOT" in
  *'\t'*) bad "command contains the two-character sequence \t -- @tsv-style escaping corrupted it" ;;
  *)       ok "no \t escape sequence was introduced" ;;
esac

echo
echo "summary: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || exit 2
exit 0
