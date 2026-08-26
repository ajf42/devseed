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

- Constitution at [`DESIGN.md`](DESIGN.md). All six sections substantive —
  §6 (amendment procedure) filled by Prompt 9 (T-010, ADR-0023). Quarterly
  self-audit: first run T-028, next due 2026-11-11.
- **The gate**, at `plugins/governed-dev/gates/`. `gate.sh` orchestrates seven
  checks in `check-*.sh`; `--fast` runs 1–3. Exit 0 pass, 2 fail, never 1.
  Verification only — it writes nothing. Run it as
  `bash plugins/governed-dev/gates/gate.sh`.
- **The drift guard**, check 7, at `gates/drift.sh`. Asks whether the four
  ledger documents still describe the repository (§5's row 7 lists the drift
  classes). Reports every finding rather than stopping at the first; runs
  standalone for CI. **Five sub-checks since ADR-0028** — what the two removed
  ones watched for, and what is now unguarded, is in that ADR and §5's Known
  limits.
- **The gate's own regression:** `bash scripts/gate-regression.sh`. devseed has
  no test suite of its own, so gate bugs involving real tooling are only
  findable against a scratch project that does — run it after touching
  anything under `gates/`.
- **CI parity** (T-009): `gate.yml` runs the real `gate.sh` plus all four
  regression suites (T-030, T-041) on a ubuntu/macos/windows matrix, fail-fast
  off, `fetch-depth: 0` (ADR-0025). First matrix run green 2026-08-11, run id
  `31534896418`, under T-009. Settles SG-0003 for devseed's own CI only
  (ADR-0020). `preflight.sh` installs `jq` under `$CI` (ADR-0019). `audit.yml`
  was **deleted** (ADR-0028), so T-026 is unbuilt again.
- **The hooks**, at `plugins/governed-dev/hooks/`. Eight entries in
  `hooks.json`; the load-bearing one is `Stop`, which runs the full gate and
  blocks the turn ending on failure. Event table, local mechanics and what
  bites: [`hooks/README.md`](plugins/governed-dev/hooks/README.md). Shell
  form, not exec form (ADR-0010). devseed wires the same eight against its
  own working tree in [`.claude/settings.json`](.claude/settings.json)
  (ADR-0011); consumers get them from the plugin.
- **The agent roster**, five agents at `plugins/governed-dev/agents/`:
  spec-guardian gates in, implementer builds, reviewer gates out, scribe
  records, auditor runs continuously. Every one declares `tools:` explicitly —
  omitting it inherits everything and silently deletes the boundary. The rule
  holding it together: the agent that makes a decision never writes the record
  justifying it. Loop and per-agent boundaries:
  [`.claude/rules/delegation.md`](.claude/rules/delegation.md).
  Mirrored to `.claude/agents/` so devseed can run its own roster (ADR-0014);
  drift check 6 enforces the two byte-identical.
- **The skills**, six at `plugins/governed-dev/skills/`: `bootstrap` seeds a
  project from `templates/`; `task` runs a task through the full agent loop
  then commits — the only thing that commits; `adr` appends a decision entry;
  `resume` reconstructs state from the ledger, changing nothing; `amend`
  executes §6 and is the sole sanctioned route to editing DESIGN.md (T-021);
  `autopilot` wraps the driver loop below.
  Mirrored to `.claude/skills/`, a third mirror on the hooks/roster reasoning
  (ADR-0016). `task` trailers commits with agent type, session, task id,
  model (T-027, ADR-0022), closing SG-0010.
- **The boundary's own regression:** `bash scripts/boundary-regression.sh`.
  73 synthetic `PreToolUse` events. Every defect found in that hook so far was
  invisible to inspection — run it after touching `boundary.sh` or any
  `tools:` list.
- **The bootstrap skill's own regression:** `bash scripts/bootstrap-regression.sh`.
  Seeds a scratch project and runs the real drift guard against it — caught
  dangling devseed ids in the shipped templates before T-008 landed.
- **Autopilot**, `bash scripts/autopilot.sh` and the `/autopilot` skill (T-041,
  ADR-0030). Runs `/task` headless over the `todo` queue and **routes on the
  gate's verdict**, which it obtains by running the gate itself — never on the
  worker's account of its own correctness. Agreement → one digest line and
  continue; a new SG entry, anything `/amend`-shaped, a question, or any edit
  to DESIGN.md → stop; gate exit 2 → one retry with the findings appended, then
  stop; anything else → stop. Bounded: 3 tasks per run, a cost ceiling, three
  strikes per task. It never touches DESIGN.md, never pushes, never merges, and
  commits only `reports/`. Its own regression, with a stubbed worker and the
  real gate: `bash scripts/autopilot-regression.sh`. **Never run against a real
  worker yet** — no `claude` CLI here; the first real run wants explicit ids
  and `--max-tasks 1`.
- Four rule files at [`.claude/rules/`](.claude/rules/) — `precedence.md`
  (document authority), `ambiguity.md` (never invent past a spec gap),
  `ledger.md` (which document owns which fact), `delegation.md` (the agent
  loop). Govern devseed itself; ship in consumer-facing form, ids and paths
  stripped, at `templates/rules/`, installed by bootstrap (ADR-0017; closes
  SG-0007). No guard compares the two copies — SG-0011.
- Plugin/marketplace manifests. `plugin.json` declares `"version": "0.1.0"`
  (ADR-0026); the marketplace entry stays versionless so the fact has one copy.
  `claude plugin validate` **has not been re-run since** — no `claude` CLI on
  this machine — so whether `--strict` now passes is unverified, not assumed
  (T-035). Published to `github.com/ajf42/devseed`; install loop verified end
  to end from outside this repo.
- Ledger documents: this file, [`TASKS.md`](TASKS.md),
  `.claude/activity.jsonl`, and the ADRs — **one file each under
  [`docs/adr/`](docs/adr/)** since ADR-0029, with
  [`DECISIONS.md`](DECISIONS.md) generated from them by
  `scripts/rebuild-adr-index.sh` and carrying the hand-written spec gaps
  inline. Retiring an ADR is a `git mv` into `docs/adr/archive/`; ids resolve
  from either directory forever. Drift check 5 verifies index against
  directory and never regenerates.

**Not built yet:**

- §6 bypass reconciliation holds by review — mechanical enforcement was
  declined at audit closure (T-029's note). The CI-invocation assertion
  landed in `gate-regression.sh`; reviewer/auditor `Bash` accepted
  permanently (ADR-0024).
- The roster now exists, so `hooks/boundary.sh` has real agents to bind — but
  it binds **only real subagents**: the main session thread carries no
  `agent_type` and is unbounded (SG-0005). Most work happens on the main
  thread, so most work is unbounded.
- The shell half of the boundary is **syntactic** and stops the expedient
  redirect, not a determined evasion through a variable or glob (ADR-0013).
  What carries the weight is the capability boundary — the scribe and
  spec-guardian hold no shell at all.
- Machine freshly set up 2026-08-11: `jq`, Python 3.12, pytest installed —
  all off `PATH` for existing shells (winget quirk). `gh` still absent.
- Checks 1–3 pass vacuously in devseed, which by DESIGN.md §3 has no build,
  tests, or linter. They trigger on *declared* tooling; see ADR-0004 and the
  Known limits in §5. Verified against a scratch project that does have tests.
- `templates/gate.sh` is still a placeholder. T-009 answered SG-0003 for
  devseed's own CI (ADR-0020); the consumer half stays open.
- `plugins/governed-dev/templates/` holds structural skeletons only, with no
  project-specific content by design.
- Repository visibility is **public**; private was required. `gh` is not
  installed on this machine. Open as SG-0002.

**Three facts that bite if forgotten:**

1. Four filenames exist twice with opposite roles. Root `DESIGN.md`,
   `CLAUDE.md`, `DECISIONS.md`, `TASKS.md` govern devseed and are never
   copied. The same names under `templates/` are shipped to consumers.
   Check which directory you are in before editing.
2. Plugin skills install namespaced — `/governed-dev:bootstrap`, not
   `/bootstrap`. A "missing" skill is usually this.
3. **An installed plugin never tracks this working tree**, and since ADR-0026
   moves only on a version bump: pushing commits alone reaches nobody. The
   installed copy is a copy, which is why devseed wires hooks, roster and
   skills from the working tree instead (ADR-0011, ADR-0014, ADR-0016).

## File structure as it stands

```
.github/workflows/
  gate.yml                         CI parity: calls gate.sh directly (T-009)
.claude-plugin/marketplace.json    marketplace "ajf42-devtools"
.claude/
  settings.json                    devseed's OWN hook wiring (ADR-0011)
  activity.jsonl                   append-only audit log (committed; ADR-0003)
  in-flight.md                     PreCompact handoff note (ignored; ADR-0009)
  .hook-state/                     per-session hook scratch (ignored)
  agents/                          MIRROR of the shipped roster (ADR-0014)
  skills/                          MIRROR of the shipped skills (ADR-0016)
  rules/
    precedence.md                  DESIGN.md vs CLAUDE.md authority
    ambiguity.md                   spec gaps: ask or record, never invent
    ledger.md                      which document owns which information
    delegation.md                  the agent loop; deciders never record
DESIGN.md                          constitution, all six sections substantive
CLAUDE.md                          this file
DECISIONS.md                       GENERATED index over docs/adr/ + spec gaps
TASKS.md                           backlog, one task per commit
docs/adr/                          one file per ADR, NNNN-slug.md (ADR-0029)
  archive/                         retired ADRs; ids still resolve forever
scripts/rebuild-adr-index.sh       regenerates DECISIONS.md; the gate never runs it
scripts/gate-regression.sh         asserts gate behaviour; devseed-only
scripts/boundary-regression.sh     asserts boundary.sh denials; devseed-only
scripts/bootstrap-regression.sh    seeds a scratch project, runs drift.sh
scripts/autopilot.sh               drives /task headless, routes on the gate (ADR-0030)
scripts/autopilot-regression.sh    asserts the routing; stub worker, real gate
reports/                           autopilot run reports: the decision queue
  README.md                        what lands here and how to read it
README.md                          what devseed is, install, the sharp edges
LICENSE                            MIT, © 2026 Andrew Fitzpatrick (T-034)
.gitignore
.gitattributes                     forces LF for *.sh on checkout (ADR-0015)
plugins/governed-dev/              THE PLUGIN — everything below ships
  .claude-plugin/plugin.json       "version": "0.1.0" (ADR-0026)
  agents/                          THE ROSTER — tools: is the enforcement
    spec-guardian.md               gates in; SANCTIONED/GAP/CONFLICT
    implementer.md                 builds, test-first; denied the 3 ledgers
    reviewer.md                    gates out; NO FINDINGS is a real result
    scribe.md                      records only; no Write, no shell
    auditor.md                     runs the guards; proposes nothing
  skills/                          THE SKILLS — bootstrap, task, adr, resume, amend
    bootstrap/SKILL.md             seeds templates/ into a fresh project
    task/SKILL.md                  runs a task end to end; the only committer
    adr/SKILL.md                   appends a DECISIONS.md entry
    resume/SKILL.md                reconstructs context from the ledger
    amend/SKILL.md                 executes §6; sole route to editing DESIGN.md
    autopilot/SKILL.md             drives scripts/autopilot.sh; surfaces its report
  gates/                           THE GATE — definition of "done"
    gate.sh                        orchestrator; --fast = checks 1-3
    lib.sh                         die/note/have, changed_files
    check-0[1-7]-*.sh              one check each, sourced in order
    drift.sh                       check 7's body; also runs standalone
  hooks/                           THE LIFECYCLE WIRING — see its README.md
    hooks.json                     8 hooks; carries the path conventions
    lib.sh                         stdin JSON, jq guard, root/gate/state paths
    preflight.sh   Setup           installs jq under CI, else reports (T-025)
    orient.sh      SessionStart    briefs the session; flags state disagreement
    boundary.sh    PreToolUse      denies writes across an agent boundary
    fast-gate.sh   PostToolUse     gate --fast on source edits (asyncRewake)
    stop-gate.sh   Stop            full gate; blocks the turn. Load-bearing.
    flush.sh       PreCompact      writes .claude/in-flight.md (ADR-0009)
    activity.sh    SessionEnd,     appends to .claude/activity.jsonl
                   SubagentStop
  templates/                       seed docs copied into consumer projects
    DESIGN.md CLAUDE.md DECISIONS.md TASKS.md gate.sh README.md .gitignore
    .gitattributes                 seeds *.sh text eol=lf into consumers
    rules/                         consumer-facing rules, ids/paths stripped
      precedence.md ambiguity.md delegation.md ledger.md
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
