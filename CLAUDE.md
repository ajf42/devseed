# CLAUDE.md — devseed working memory

> **Line budget: target 200, hard ceiling 300.** This file is working memory,
> not an archive. It is read in full every session; every line spends context
> that belongs to the task. See "Compression protocol" below before adding.

This file governs **devseed itself**. It is not the template shipped to consumer
projects — that is
[`plugins/governed-dev/templates/CLAUDE.md`](plugins/governed-dev/templates/CLAUDE.md).

---

## How this relates to DESIGN.md

[`DESIGN.md`](DESIGN.md) says what devseed **should be**. This file says what
devseed **is right now**. Spec questions resolve against DESIGN.md; current-state
questions resolve against this file.

This file is expected to go stale — code moves faster than notes. Ordinary
staleness is corrected in place, no ceremony. But if the two documents describe
*incompatible systems* rather than the same system at two times, that is not
staleness and must not be reconciled silently. Stop and surface it.

Never edit DESIGN.md to match drifted code: that converts an accident into a
sanctioned constraint. Full rule:
[`.claude/rules/precedence.md`](.claude/rules/precedence.md).

Where to write a given fact:
[`.claude/rules/ledger.md`](.claude/rules/ledger.md).

## Current state

devseed is a **governance scaffold**, not an application. It has no runtime, no
dependencies, and no build step. It serves two roles at once — it is a project
governed by its own DESIGN.md, and it is the source of the `governed-dev`
plugin installed into other projects. See ADR-0001.

**Built and working:**

- Constitution at [`DESIGN.md`](DESIGN.md). Sections 1–5 substantive.
  §6 (amendment procedure) is still a placeholder.
- **The gate**, at `plugins/governed-dev/gates/`. `gate.sh` orchestrates seven
  checks in `check-*.sh`; `--fast` runs 1–3. Exit 0 pass, 2 fail, never 1.
  Verification only — it writes nothing. Run it as
  `bash plugins/governed-dev/gates/gate.sh`.
- **The drift guard**, check 7, at `gates/drift.sh`. Asks whether the four
  ledger documents still describe the repository: duplication, staleness,
  budget, orphaned ids, deleted ADRs, hook-wiring parity. Unlike checks 1–6 it
  reports every finding instead of stopping at the first, and runs standalone
  for CI. Derives its canaries from DESIGN.md at runtime, so editing the spec
  never means editing the guard. Limits are listed in DESIGN.md §5; ADR-0012
  says why it is one script rather than six checks.
- **The gate's own regression:** `bash scripts/gate-regression.sh`. devseed has
  no test suite of its own, so gate bugs involving real tooling are only
  findable against a scratch project that does — run it after touching
  anything under `gates/`.
- **The hooks**, at `plugins/governed-dev/hooks/`. Eight entries in
  `hooks.json` wire the gate and the agent boundaries into the lifecycle:
  `Stop` runs the full gate and blocks the turn ending on failure (the
  load-bearing one), `PreToolUse` denies writes across an agent boundary,
  `PostToolUse` runs `--fast` on source edits, `SessionStart` briefs the
  session, `PreCompact` saves in-flight state, `SessionEnd`/`SubagentStop`
  append to `activity.jsonl`, `Setup` preflights `jq`. Shell form, not exec
  form (ADR-0010). devseed wires the same eight against its own working tree in
  [`.claude/settings.json`](.claude/settings.json) (ADR-0011); consumers get
  them from the plugin. Local mechanics and what bites:
  [`hooks/README.md`](plugins/governed-dev/hooks/README.md).
- **The agent roster**, five agents at `plugins/governed-dev/agents/`:
  spec-guardian gates in, implementer builds, reviewer gates out, scribe
  records, auditor runs continuously. Every one declares `tools:` explicitly —
  omitting it inherits everything and silently deletes the boundary. The rule
  holding it together: the agent that makes a decision never writes the record
  justifying it. Loop and per-agent boundaries:
  [`.claude/rules/delegation.md`](.claude/rules/delegation.md).
  Mirrored to `.claude/agents/` so devseed can run its own roster (ADR-0014);
  drift check 6 enforces the two byte-identical.
- **The boundary's own regression:** `bash scripts/boundary-regression.sh`.
  73 synthetic `PreToolUse` events. Every defect found in that hook so far was
  invisible to inspection — run it after touching `boundary.sh` or any
  `tools:` list.
- Four rule files at [`.claude/rules/`](.claude/rules/) — `precedence.md`
  (document authority), `ambiguity.md` (never invent past a spec gap),
  `ledger.md` (which document owns which fact), `delegation.md` (the agent
  loop). These govern devseed and are deliberately **not** shipped — which
  the shipped agents cite anyway, open as SG-0007.
- Plugin/marketplace manifests. `claude plugin validate .` passes with one
  warning: `version` is intentionally omitted from `plugin.json`, so the
  installed version resolves to the commit SHA. `--strict` fails on that
  warning by design and is unusable until a release is pinned.
- Published to `github.com/ajf42/devseed`. Install loop verified end to end
  from a directory outside this repo:
  `claude plugin marketplace add ajf42/devseed` then
  `claude plugin install governed-dev@ajf42-devtools`.
- Ledger documents: this file, [`DECISIONS.md`](DECISIONS.md),
  [`TASKS.md`](TASKS.md), and `.claude/activity.jsonl`.

**Not built yet:**

- `plugins/governed-dev/skills/` is empty (T-008). The roster now exists, so
  `hooks/boundary.sh` has real agents to bind — but it binds **only real
  subagents**: the main session thread carries no `agent_type` and is unbounded
  (SG-0005). Most work happens on the main thread, so most work is unbounded.
- The shell half of the boundary is **syntactic** and stops the expedient
  redirect, not a determined evasion through a variable or glob (ADR-0013).
  What carries the weight is the capability boundary — the scribe and
  spec-guardian hold no shell at all.
- Nothing else. `jq` is installed (1.8.2) and `lib.sh` locates it even when it
  is off `PATH`, which it is here — winget's Links directory only reaches
  processes started after the install.
- Checks 1–3 pass vacuously in devseed, which by DESIGN.md §3 has no build,
  tests, or linter. They trigger on *declared* tooling; see ADR-0004 and the
  Known limits in §5. Verified against a scratch project that does have tests.
- `templates/gate.sh` is still a placeholder — whether consumers vendor their
  own copy is open as SG-0003, and CI (T-009) forces the answer.
- `plugins/governed-dev/templates/` holds structural skeletons only, with no
  project-specific content by design.
- Repository visibility is **public**; private was required. `gh` is not
  installed on this machine. Open as SG-0002.

**Two facts that bite if forgotten:**

1. Four filenames exist twice with opposite roles. Root `DESIGN.md`,
   `CLAUDE.md`, `DECISIONS.md`, `TASKS.md` govern devseed and are never
   copied. The same names under `templates/` are shipped to consumers.
   Check which directory you are in before editing.
2. Plugin skills install namespaced — `/governed-dev:bootstrap`, not
   `/bootstrap`. A "missing" skill is usually this.
3. **An installed plugin is pinned to a commit SHA and goes stale silently.**
   `plugin.json` omits `version` by design (ADR-0001), so `install` resolves to
   the SHA at install time and never moves. The copy on this machine sits at
   `70542ef`, before the gate existed. This is why devseed wires its own hooks
   from the working tree rather than through the plugin (ADR-0011).

## File structure as it stands

```
.claude-plugin/marketplace.json    marketplace "ajf42-devtools"
.claude/
  settings.json                    devseed's OWN hook wiring (ADR-0011)
  activity.jsonl                   append-only audit log (committed; ADR-0003)
  in-flight.md                     PreCompact handoff note (ignored; ADR-0009)
  .hook-state/                     per-session hook scratch (ignored)
  agents/                          MIRROR of the shipped roster (ADR-0014)
  rules/
    precedence.md                  DESIGN.md vs CLAUDE.md authority
    ambiguity.md                   spec gaps: ask or record, never invent
    ledger.md                      which document owns which information
    delegation.md                  the agent loop; deciders never record
DESIGN.md                          constitution (§5, §6 are placeholders)
CLAUDE.md                          this file
DECISIONS.md                       ADR log + spec gaps observed
TASKS.md                           backlog, one task per commit
scripts/gate-regression.sh         asserts gate behaviour; devseed-only
scripts/boundary-regression.sh     asserts boundary.sh denials; devseed-only
README.md                          one line; not yet written
.gitignore
.gitattributes                     forces LF for *.sh on checkout (ADR-0015)
plugins/governed-dev/              THE PLUGIN — everything below ships
  .claude-plugin/plugin.json       no "version" key, deliberately
  agents/                          THE ROSTER — tools: is the enforcement
    spec-guardian.md               gates in; SANCTIONED/GAP/CONFLICT
    implementer.md                 builds, test-first; denied the 3 ledgers
    reviewer.md                    gates out; NO FINDINGS is a real result
    scribe.md                      records only; no Write, no shell
    auditor.md                     runs the guards; proposes nothing
  skills/                          empty — Prompt 7 adds bootstrap
  gates/                           THE GATE — definition of "done"
    gate.sh                        orchestrator; --fast = checks 1-3
    lib.sh                         die/note/have, changed_files
    check-0[1-7]-*.sh              one check each, sourced in order
    drift.sh                       check 7's body; also runs standalone
  hooks/                           THE LIFECYCLE WIRING — see its README.md
    hooks.json                     8 hooks; carries the path conventions
    lib.sh                         stdin JSON, jq guard, root/gate/state paths
    preflight.sh   Setup           reports missing jq, git, gate, bash-on-PATH
    orient.sh      SessionStart    briefs the session; flags state disagreement
    boundary.sh    PreToolUse      denies writes across an agent boundary
    fast-gate.sh   PostToolUse     gate --fast on source edits (asyncRewake)
    stop-gate.sh   Stop            full gate; blocks the turn. Load-bearing.
    flush.sh       PreCompact      writes .claude/in-flight.md (ADR-0009)
    activity.sh    SessionEnd,     appends to .claude/activity.jsonl
                   SubagentStop
  templates/                       seed docs copied into consumer projects
    DESIGN.md CLAUDE.md DECISIONS.md TASKS.md gate.sh README.md
```

Path rule for remaining work: content specified as `.claude/agents/*`,
`.claude/skills/*`, `.claude/gates/*`, or `.claude/hooks/*` is built under
`plugins/governed-dev/<same-subpath>`. Only `.claude/rules/` and
`.claude/activity.jsonl` keep their literal root paths.

Hook path variables are reversible by accident and both reversals fail
silently: `${CLAUDE_PLUGIN_ROOT}` **locates** scripts shipped with the plugin
(it is copied to a cache dir on install); `${CLAUDE_PROJECT_DIR}` **roots the
code a gate inspects**. Recorded in `hooks/hooks.json`.

## Build rules

Described in **[`DESIGN.md`](DESIGN.md) §5**, but the *authority* is
`plugins/governed-dev/gates/gate.sh`. If the prose and the script disagree, the
script wins and the prose gets fixed. Do not restate the rules here.

## Compression protocol

When a change would push this file past **300 lines**, compress *before*
continuing the change. Do not commit an over-budget file with a note to clean
it later.

Route the detail by what it is:

- **Spec** — a constraint, an intent, something that should be true → move to
  `DESIGN.md` via its amendment procedure. Leave a one-line pointer here.
- **Rationale** — why a choice was made → move to `DECISIONS.md` as an ADR.
- **Local mechanics** — how one directory works → move to a `README.md` in
  that directory. Link it from the file-structure block above.
- **Pending work** → move to `TASKS.md`.
- **Superseded state** → delete it. This file is not an archive; git holds
  the history.

The budget is the point, not an aspiration. A CLAUDE.md that grows without
bound stops being read carefully, and an unread current-state record is worse
than none: it looks authoritative while nobody checks it.
