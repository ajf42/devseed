# `hooks/` — the lifecycle wiring

The gate defines *done*. These hooks are what make it unavoidable. A rule the
agent has to remember to run is advice; a rule the harness runs is a rule.

`hooks.json` registers eight entries. Each one locates its script under
`${CLAUDE_PLUGIN_ROOT}/hooks/` and each script resolves the project it acts on
itself, from `${CLAUDE_PROJECT_DIR}`. The `_CONVENTION_*` keys in `hooks.json`
say why that split is load-bearing; read them before editing it.

devseed additionally wires the same eight events in its own
`/.claude/settings.json`, pointed at the working tree — an installed plugin is
pinned to a commit SHA and stale by default, so without it a hook edit would not
take effect until it was published (ADR-0011). That file is a **mirror**;
`hooks.json` is the source of truth. Only the event set, matchers and async
flags are duplicated — there is one copy of each script.

| Event | Script | Does | Blocks? |
|---|---|---|---|
| `Setup` | `preflight.sh` | Installs `jq` under CI, reports it elsewhere; verifies `git`, gate, bash-on-PATH, and declared build/test/lint via `gate.sh --fast` (T-025) | No — cannot |
| `SessionStart` | `orient.sh` | Briefs the session as `additionalContext` | No |
| `PreToolUse` | `boundary.sh` | Denies writes crossing an agent's boundary | **Yes** |
| `PostToolUse` | `fast-gate.sh` | `gate.sh --fast` on source edits | No — rewakes |
| `Stop` | `stop-gate.sh` | Full gate; blocks the turn ending | **Yes** |
| `PreCompact` | `flush.sh` | Writes `.claude/in-flight.md` | No — never |
| `SessionEnd` | `activity.sh` | Appends to `.claude/activity.jsonl` | No |
| `SubagentStop` | `activity.sh` | Same | No |

## Things that bite

**Exit 2 does not mean the same thing twice.** It blocks `PreToolUse`, `Stop`,
`SubagentStop` and `PreCompact`. It is merely reported for `SessionStart`,
`SessionEnd`, `Setup` and `PostToolUse`. `flush.sh` therefore always exits 0 —
exiting 2 there would block compaction and strand a session at a full context
window. Check which event a script serves before adding a failure path to it.

**JSON output is only honoured on exit 0.** `stop-gate.sh` blocks by printing
`{"decision":"block","reason":…}` and exiting 0, not by exiting 2. Exit 2 also
blocks, but frames the gate's message as a hook error rather than as work
remaining.

**`asyncRewake`, not `async`.** Both run in the background. Only `asyncRewake`
wakes Claude on exit 2 and shows it the stderr. `PostToolUse` under plain
`async` would run the gate, fail, and discard the result.

**These hooks write to the project; the gate does not.** `gate.sh` is
verification-only on purpose (DESIGN.md §5) — it is run by CI and by humans and
must behave identically for both. Hooks are session machinery, not verification,
and they own three paths:

- `.claude/activity.jsonl` — the audit trail. Committed, per ADR-0003.
- `.claude/in-flight.md` — compaction handoff note. Ignored; last 4 snapshots.
- `.claude/.hook-state/` — per-session scratch: the HEAD a session started at,
  the last gate result, the Stop-hook block counter. Ignored.

**Shell form, not exec form.** Exec form is the documented recommendation for
path placeholders, and it is wrong here: it spawns the command with no shell, so
`bash` must be on `PATH`. Git Bash is commonly installed and *not* on `PATH`, in
which case no hook runs and nothing reports it. Shell form with
`"shell": "bash"` lets the harness find Git Bash itself; the quotes around each
placeholder do what exec form was wanted for. See ADR-0010 before "fixing" this
back to the default.

**`jq` is a hard dependency, and is not always on `PATH`.** These scripts parse
a JSON event and emit JSON decisions. Hand-rolled escaping in shell is how a
deny reason containing a quote becomes a malformed object the harness drops — a
boundary that stops enforcing and says nothing. Without `jq`, `boundary.sh`
denies every write and `stop-gate.sh` blocks every turn, by design: an
enforcement point that cannot evaluate itself must not default to allow.
`lib.sh` probes the standard install locations when `PATH` misses — winget's
Links directory only reaches processes started after the install, so a freshly
installed `jq` is invisible to the session that installed it.

**The Stop hook has a circuit breaker.** Today's API has no `stop_hook_active`
flag, so nothing else prevents it re-blocking a failure the agent cannot fix.
After three consecutive blocks it releases and escalates loudly to the human.
That is a degradation and it is deliberate — see ADR-0008.

**Agent names arrive namespaced.** `governed-dev:implementer`, not
`implementer`. `hook_agent_type()` strips the prefix; a boundary matching the
bare string would evaporate the moment the plugin is installed rather than run
from a checkout.

**`preflight.sh` means something different called directly.** `Setup`'s exit
code is only *reported* when the harness runs it — Setup cannot block a
session. `.github/workflows/gate.yml` (T-009) calls the same script directly
as a plain CI step, where exit 2 fails the job like any other command. Same
script, two different consequences for the same exit code, because one caller
is a harness event and the other is a shell.

**`NotebookEdit` is in the write matchers.** It takes `notebook_path`, not
`file_path`. A boundary reading only `file_path` has a documented way around it.
