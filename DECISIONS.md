# DECISIONS.md — devseed

Decision log for **devseed's own development**. Append-only; entries are
superseded, never edited away.

This is not the template that ships to consumer projects — that one lives at
[`plugins/governed-dev/templates/DECISIONS.md`](plugins/governed-dev/templates/DECISIONS.md)
and is a skeleton by design.

## Format

Every entry carries four parts, in this order:

- **Status** — `Accepted`, `Superseded by ADR-NNNN`, or `Rejected`.
- **Context** — the situation forcing a choice, and **the alternatives
  considered with why each was rejected**. An ADR that names only the option
  taken records a preference, not a decision; the rejected paths are what make
  it possible to tell later whether the reasoning still holds.
- **Decision** — what was chosen, stated so it can be checked against reality.
- **Consequences** — what follows, including the costs accepted. An entry with
  only upsides in this section is incomplete.

## Conventions

- **Newer entries append to the bottom.** Reading top to bottom is reading
  chronologically.
- **Superseded decisions are marked superseded, never deleted.** Set the old
  entry's Status to `Superseded by ADR-NNNN` and leave everything else intact.
  The superseding entry names what it replaces and why. History is not
  rewritten: a decision that was reversed is evidence about how this project
  reasons, and deleting it makes the reversal invisible to the next reader —
  who then has no way to know the ground has already been walked.
- **Numbering is permanent.** `ADR-0003` refers to the same thing forever, even
  once superseded. Numbers are never reused.
- Corrections to typos and links are fine in place. Corrections to *reasoning*
  are a new entry.

---

## ADR-0001 — Split plugin content from the repo's own governance

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

devseed came to serve two roles at once, and they were tangled in a single
`.claude/` directory:

1. **A governed project.** devseed is itself built under the constitution in
   `/DESIGN.md`, with the rules in `.claude/rules/` constraining agent work on
   devseed. Prompts 2–9 apply to devseed directly. This is dogfooding — the
   tool is developed under the discipline it exports.
2. **A plugin source.** devseed produces `governed-dev`, a Claude Code plugin
   installed into every other project.

Left tangled, the two roles fail in a specific way. `.claude/agents/` would be
read both as devseed's own agent roster and as the roster shipped to consumers,
with no way to tell which a given file was for. A file's audience would be
inferable only from its content, which is exactly the condition under which an
assumption becomes indistinguishable from a sanctioned decision — the failure
mode `/DESIGN.md` §2 exists to prevent. Worse, the tooling that governs projects
would depend on being copy-pasted between them, inheriting the drift problem it
exists to eliminate.

**Alternatives considered:**

- **Keep one `.claude/` and separate by naming convention** (e.g. a `shipped-`
  prefix). Rejected: audience would depend on unenforced discipline, and a
  misnamed file fails silently — either shipping devseed's internal rules to
  every consumer, or withholding a rule the consumers need. Path-based
  separation cannot be forgotten mid-edit.
- **Two repositories, one for governance and one for the plugin.** Rejected:
  ends the dogfooding. The plugin would no longer be developed under the
  discipline it exports, which is the only ongoing test that the discipline is
  usable. It also makes every change a cross-repo coordination problem.
- **No plugin — copy `.claude/` into each project by hand.** Rejected: this is
  precisely the drift problem devseed exists to prevent. Every copy diverges
  from the day it is made, and there is no route for a fix to propagate.
- **Make the repository root itself the plugin**, with no `plugins/`
  subdirectory. Rejected: the plugin root is what gets installed, so devseed's
  own `DESIGN.md`, `CLAUDE.md`, and rules would ship to every consumer. It also
  forces marketplace and plugin manifests to share one root, coupling the
  question "what is published" to "what is installed".

### Decision

Separate by directory, so the audience of a file is determined by its path
rather than by reading it.

- **`plugins/governed-dev/`** is the plugin. `agents/`, `skills/`, `gates/`,
  and `hooks/` moved here from `.claude/`. Its manifest is
  `plugins/governed-dev/.claude-plugin/plugin.json`.
- **`plugins/governed-dev/templates/`** holds seed documents — `DESIGN.md`,
  `CLAUDE.md`, `DECISIONS.md`, `TASKS.md`, `gate.sh` — copied into consumer
  projects by the bootstrap skill. Skeletons only.
- **`.claude/rules/`** stays at the repo root. `precedence.md` and
  `ambiguity.md` govern devseed itself and are deliberately not shipped.
- **`/.claude-plugin/marketplace.json`** at the repo root publishes the
  marketplace `ajf42-devtools` containing the single plugin `governed-dev`.
- **Root `DESIGN.md`, `CLAUDE.md`, `DECISIONS.md`, `TASKS.md`** govern devseed's
  own development. Permanent, and never copied anywhere.

`plugin.json` deliberately **omits `version`**. For a solo, actively-iterated
tool, every commit being the current version is the right default. A version
string gets pinned only once another project depends on stability across a
specific release — at which point the need is real rather than anticipated.

### Consequences

- **Anything under `plugins/governed-dev/templates/` is distributable content.
  Anything at the repo root is not.** This is the test to apply when unsure
  where a file belongs.
- Four filenames now exist twice with opposite roles. `templates/README.md`
  warns about this at the point of contact; it remains the sharpest edge in the
  layout.
- Prompts 2–9 redirect: content specified as `.claude/agents/*.md`,
  `.claude/skills/*`, `.claude/gates/gate.sh`, or `.claude/hooks/hooks.json`
  is built under `plugins/governed-dev/<same-subpath>`. Only `.claude/rules/`
  keeps its literal root path.
- Hook path variables are now load-bearing and reversible by accident:
  `${CLAUDE_PLUGIN_ROOT}` locates scripts shipped with the plugin, since the
  plugin is copied to a cache directory on install; `${CLAUDE_PROJECT_DIR}`
  roots the code a gate inspects. Recorded in `hooks/hooks.json` because both
  reversals fail silently rather than loudly.
- Plugin skills will be namespaced on install — `/governed-dev:bootstrap`, not
  `/bootstrap`. Noted now so it is not mistaken later for a broken install.
- devseed must be installable from its GitHub source, not just a local path.
  The marketplace is only reachable on the default branch.

---

## ADR-0002 — Ledger documents exist as two parallel sets

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

The instruction to create four ledger documents (`CLAUDE.md`, `DECISIONS.md`,
`TASKS.md`, alongside `DESIGN.md`) collided with ADR-0001. ADR-0001 assigned the
*skeletons* of those four to `plugins/governed-dev/templates/`, explicitly "not
files that live in this repo's own root". But the acceptance criterion — a fresh
session reading only these four files can tell what exists and what is next —
describes a filled-in record of devseed's actual state, which a skeleton cannot
provide.

**Alternatives considered:**

- **Root only, no templates.** Rejected: the bootstrap skill (T-008) would have
  to generate each consumer's documents as fresh prose, which ADR-0001's
  redirect explicitly forbids. Generated prose also varies per invocation, so
  two projects bootstrapped a week apart would receive different structures and
  neither would be traceable to a reviewed source.
- **Templates only, no root set.** Rejected: devseed would have no working
  memory and no backlog, ending the dogfooding that ADR-0001 preserved. It also
  leaves `precedence.md` pointing at a `CLAUDE.md` that does not exist, so the
  rule cannot be followed as written.
- **One shared set, symlinked or generated from a single source.** Rejected: the
  two sets have deliberately opposite content. Root is filled in and specific;
  templates are structural and opinion-free. Sharing a source means either
  shipping devseed's internal state to every consumer, or emptying devseed's own
  record to keep the template clean.

### Decision

Maintain both. Root `CLAUDE.md`, `DECISIONS.md`, `TASKS.md`, and `DESIGN.md` are
devseed's own, filled in and specific. The four under `templates/` are
structural skeletons with no project-specific content, and are the sole source
the bootstrap skill copies from.

### Consequences

- Closes SG-0001: root `CLAUDE.md` and `TASKS.md` now exist.
- Four filenames exist twice with opposite roles, as ADR-0001 already noted.
  This decision makes that permanent rather than transitional.
- A change to the *structure* of a ledger document must be applied twice, and
  the two can silently diverge. `templates/README.md` flags this at the point of
  contact; there is no mechanical enforcement, and there should be once gates
  exist (T-004).
- Templates must stay free of opinions. A default that ships inside a skeleton
  installs an unsanctioned constraint into every project at once — the failure
  mode of `DESIGN.md` §2, at scale.

---

## ADR-0003 — `.claude/activity.jsonl` is committed, not ignored

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

The activity log is an append-only audit trail of what agents did in this repo.
It has to live somewhere, and the choice is whether git tracks it.

**Alternatives considered:**

- **Add it to `.gitignore`.** Rejected as the default: an audit trail that does
  not survive a clone is not an audit trail. It would also be invisible in
  review, which removes the only moment anyone would actually read it.
- **Store it outside the repo** (e.g. under a user-level directory). Rejected:
  decouples the record from the commit history it describes, so the two can no
  longer be read against each other.

### Decision

Commit it. Empty at creation.

### Consequences

- Every session that appends produces a diff, and concurrent branches appending
  to the same file will conflict on merge.
- If that noise becomes real rather than theoretical, the first mitigation is a
  `.gitattributes` entry marking the file `merge=union`, not reversing this
  decision. Reversing it is a new ADR superseding this one.
- Nothing writes to the file yet. It stays empty until hooks exist (T-005).

---

## ADR-0004 — The gate triggers on declared tooling, not on its absence

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

`gate.sh` must satisfy two requirements that pull against each other. "A check
that cannot run is a failed check — if pytest is missing, that's exit 2, not a
skip." And: the gate must exit 0 on a clean tree, including devseed's own, which
by `DESIGN.md` §3 has no runtime, no build step, and no tests by design.

**Alternatives considered:**

- **Strict — any absent runner fails.** Rejected: devseed's own clean tree would
  exit 2 permanently, so the gate could never be dogfooded, and every
  documentation-only project would be unable to adopt it. It also cannot
  distinguish "the test runner broke" from "there are no tests", which is the
  distinction that carries all the meaning.
- **Permissive — skip whatever is not installed.** Rejected: this is precisely
  the silent degradation the gate exists to prevent. A project whose pytest
  disappeared would go green.
- **A config file declaring which checks apply.** Rejected: a project could
  disable a check by editing config, so the gate would enforce only what a
  future agent had not yet switched off. It also adds a spec surface nobody
  asked for.

### Decision

Trigger on **evidence in the repository**. A build script in `package.json`, a
`build:` target, `pyproject.toml`, a `tests/` directory, a ruff or ESLint
config — each means the corresponding tool *must* be present and *must* pass;
missing tooling is exit 2. A project that declares none of them passes checks
1–3 vacuously and says so on stderr.

Spec-gap markers link to `DECISIONS.md` by an explicit `SG-NNNN` id rather than
by text matching, which would be brittle, or by merely requiring a non-empty
"Spec gaps observed" section, which any unrelated entry would satisfy.

The gate is split across `gates/check-*.sh` with `gate.sh` orchestrating, since
six checks with actionable messages exceed the 100-line ceiling in one file.

### Consequences

- The protection is narrower than "a check that cannot run fails". It catches
  **declared-but-unrunnable**, not **never-declared**. `DESIGN.md` §5 states
  this under Known limits so it is not mistaken for full coverage.
- A project can weaken the gate by removing a declaration — deleting `tests/`
  makes check 2 vacuous. That is visible in a diff, which is the mitigation.
- Adding a language or toolchain means editing a check file. Expected.
- Check 6 skips `.md`, because the documents defining the marker convention
  would otherwise match it. A marker in prose is not caught.

---

## ADR-0005 — The gate excludes generated artifacts unconditionally

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

On a fully committed Python project with a `tests/` directory, `gate.sh` exited
2 reporting "Files under src/ changed but CLAUDE.md did not" — on the first run
and every run after. Check 2 runs pytest, pytest writes `src/__pycache__/`, and
`changed_files()` counted those untracked files as source changes when check 4
inspected the tree moments later. The gate created the condition that failed it.

A gate that passes once and fails on re-run is the worst available failure mode:
it produces a blocking error that no edit can clear, and trains the reader to
ignore the gate entirely.

**Alternatives considered:**

- **Rely on the consumer's `.gitignore`.** `changed_files()` already passes
  `--exclude-standard`, so a correctly configured project was unaffected.
  Rejected: the gate cannot depend on the consumer having configured one, and a
  freshly bootstrapped project has none at all — so the very first gate run in a
  new project would fail, which is precisely when a reader decides whether the
  tool is trustworthy.
- **Reorder checks so 4 runs before 2.** Rejected: it hides the problem rather
  than fixing it. The artifacts still land in the tree and still pollute the
  next run, and the correctness of the whole gate would silently depend on an
  ordering constraint nothing records. The spec also fixes the order as
  cheapest-first with `--fast` = 1–3.
- **Have the gate delete artifacts after running.** Rejected: `gate.sh` is
  verification only and never writes to the consumer's tree. A gate that deletes
  files behaves differently — or dangerously — depending on who invoked it,
  which is the reasoning already recorded for its no-side-effects rule.

### Decision

`changed_files()` filters a fixed list of generated-artifact paths
unconditionally, independent of the consumer's `.gitignore`:
`__pycache__/`, `*.pyc`, `.pytest_cache/`, `.ruff_cache/`, `.mypy_cache/`,
`node_modules/`, `dist/`, `build/`, `htmlcov/`, `.nyc_output/`, and coverage
output. `templates/.gitignore` ships the same set so bootstrapped projects also
keep a clean tree.

### Consequences

- A project that legitimately tracks a directory named `build/` or `dist/` will
  have changes there invisible to checks 4 and 6. Recorded under Known limits in
  `DESIGN.md` §5.
- The list is maintained by hand; a new toolchain writing somewhere else
  reintroduces the class of bug until its path is added.
- `scripts/gate-regression.sh` asserts the gate exits 0 on two consecutive runs
  over a committed tree. This bug was invisible to every previous check because
  devseed itself has no test suite to generate artifacts — it could only be
  found by running the gate against a project that does.

---

## ADR-0006 — Bash is the gate's platform; Git Bash is a Windows prerequisite

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

`DESIGN.md` §3 required that hooks and gates "must run on Windows/PowerShell and
POSIX shells," and gave the reason: "A gate that only runs on one platform is a
gate that silently does not run." The implementation never met that. Every gate
script is `#!/usr/bin/env bash` and `gate.sh` uses `BASH_SOURCE` — bash-only.

Claude Code runs hooks on Windows under bash, or under PowerShell when Git Bash
is not installed. On such a machine the gate would not run at all: verbatim the
failure §3 names, sitting inside §3.

This is an unmet requirement in §3, not a §5 description of gate behaviour, so
"the script wins and the prose gets fixed" does not apply. §6 does not exist
yet, so it is resolved here by ADR.

**Alternatives considered:**

- **Write a real PowerShell implementation of all six checks.** Rejected: it
  produces two gates that must stay in step, and ADR-0002 already identifies
  duplicate maintenance as this layout's sharpest cost. Here the duplicate is
  *executable*, so drift would yield two different definitions of "done" — a
  strictly worse failure than prose drift, and undetectable without running both
  on every platform. It also doubles the surface for the exit-1 mistake.
- **Soften §3's wording to say bash-only and call it a correction.** Rejected on
  principle: that reconciles a spec to an implementation to make a requirement
  disappear, which `precedence.md` forbids. The requirement is real — the gate
  must not silently skip on Windows — and it deserved to be met, not deleted.
- **Drop Windows support.** Rejected: primary development happens on Windows 11.

### Decision

One implementation, in bash. §3 narrowed to bash with **Git Bash a stated
prerequisite on Windows**, and the requirement enforced rather than assumed:

- `gates/gate.ps1` is a PowerShell shim. It locates bash on `PATH` or in the
  standard Git for Windows install locations and hands off, preserving arguments
  and exit code. Finding none, it exits **2** with `winget` and download
  instructions. It makes no decisions about what "done" means, so it is a second
  file but not a second gate.
- `gate.sh` refuses to run under a non-bash shell rather than mis-resolving
  `BASH_SOURCE` and checking the wrong directory.

### Consequences

- Git Bash is a hard dependency on Windows. It ships with Git, which the gate
  already requires, so the marginal cost is close to zero — but it is now stated
  in §3 and in the README rather than assumed.
- A Windows consumer without Git Bash gets a blocking, actionable failure
  instead of a silent pass. That is the whole point of the change.
- `gate.ps1` must track `gate.sh`'s argument surface (currently only `--fast`).
  Small, but it is a second thing to keep in step and will be forgotten
  eventually.
- The `BASH_VERSION` guard is unexercised on the development machine, where
  Git Bash's `sh` is bash in POSIX mode and still sets it. It is verified by
  inspection, not by test.

---

## ADR-0007 — Tool boundaries are mechanism, not speculative agents

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

`DESIGN.md` §4 defers the contents of `agents/` and `skills/`: "Added when a
repeated procedure actually recurs. Speculative agents are unsanctioned
constraints wearing a different hat." That rule is sound and was written against
a real risk — inventing five agent personas before knowing what the work needs.

But the agent roster collapsed to a single task covering the scribe, and the
part that got lost was not the roster. It was the **tool boundaries**. The
implementer cannot write `DECISIONS.md`; that is what stops an agent which hits
a spec wall from writing itself permission and continuing. Without it there is
no separation of duties — only five prompts that can each do everything.

A boundary that prevents an agent from sanctioning its own assumptions is the
mechanism this whole system is built on. §4's rule does not reach it.

**Alternatives considered:**

- **Keep the single scribe task and argue the boundaries are unnecessary.**
  Rejected: nothing else prevents an agent from resolving its own spec gap by
  editing the document that defines the gap. `ambiguity.md` asks it not to, and
  a rule an agent can edit its way around is advice. The gate cannot catch this
  either — an agent that writes a plausible ADR produces a repo that passes
  every check.
- **Add all five agents now with no tool restrictions**, deferring boundaries.
  Rejected: that is the speculative-persona failure §4 names, and it ships the
  cost of five agents while deferring the only part that earns it.
- **Enforce boundaries by instruction in each agent's prompt.** Rejected: the
  same category error as leaving a build rule in prose. An instruction not to
  write a file is not a boundary; `tools:` allowlists and a `PreToolUse` deny
  are.

### Decision

Narrow §4's deferral to what it was written against: **speculative agents**.
Boundary-enforced agents are mechanism and are in scope now. T-007 expands to
the full roster — spec-guardian, implementer, reviewer, scribe, auditor — with
an explicit `tools:` allowlist per agent, and acceptance stated as an observable
denial rather than as a declared intention.

### Consequences

- `tools:` allowlists cannot express *path* restrictions: they gate which tools
  an agent has, not which files it may touch. "The implementer cannot write
  `DECISIONS.md`" therefore needs a `PreToolUse` hook to deny by path, which
  couples T-007 to T-005. Recorded here because the coupling is easy to miss and
  the boundary silently does not exist until both land.
- Five agents is a larger surface than one, and §4's warning still applies to
  anything added beyond this roster.
- Until the hooks exist, an agent's boundary is documentation. Nothing enforces
  it, and CLAUDE.md must not describe it as enforced.

---

## ADR-0008 — The Stop gate releases after three consecutive blocks

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

The `Stop` hook runs the full gate and blocks the turn from ending when it
fails. That is the load-bearing mechanism of the whole scaffold — the executable
form of "do not consider a task complete until all steps are done".

It also has no natural exit. Earlier versions of the hooks API passed a
`stop_hook_active` flag so a Stop hook could tell it was already the reason the
session was continuing. **Today's API has no such field** — verified against the
published reference on 2026-07-31, which documents no loop-prevention mechanism
for `Stop` at all. So a gate failure the agent cannot fix — a missing toolchain,
a spec question only the human can settle — produces an unbounded loop: block,
attempt, block, attempt, with no way out but killing the session.

**Alternatives considered:**

- **Block unconditionally, forever.** Rejected. It is the purest reading of "no
  silent degradation", but the failure it produces is not loud, it is *stuck* —
  and a tool that can wedge a session teaches its user to disable it. A gate
  that gets switched off enforces nothing, which is a worse outcome than a gate
  that escalates.
- **Track the flag ourselves from the transcript.** Rejected: it means parsing
  `transcript_path` to infer whether the last stop was hook-induced, which
  couples the hook to an undocumented file format that can change without
  notice, to reconstruct a signal the API no longer offers.
- **Block only on some checks.** Rejected: it makes "done" negotiable per check,
  and the gate is deliberately a single verdict. Any subset is a second
  definition of done that nothing records.
- **Release after one block.** Rejected: one attempt is not an attempt. Most
  gate failures are fixable by the agent on the next edit, which is exactly the
  case the hook exists to catch.

### Decision

`stop-gate.sh` keeps a per-session counter under `.claude/.hook-state/`. It
blocks on gate failure up to three consecutive times, resetting the counter on
any pass. On the fourth it stops blocking and instead emits the gate's failure
plus a `systemMessage` stating that the turn ended **unfinished** and that the
failure has outlived three attempts and is probably not the agent's to fix.

The release is made at least as loud as the block. The block text tells the
agent in advance that the counter exists and that a turn ending that way ends
unfinished, so it can stop and say so rather than burning the attempts.

### Consequences

- A turn *can* end with the gate red. That is a real hole and it is the price of
  not being able to wedge the session. It is visible in the transcript, in the
  `systemMessage`, and in `.claude/activity.jsonl`, which records `gate_result`
  on every session end.
- `3` is a judgement, not a derived number. If it proves wrong the fix is to
  change `MAX_BLOCKS` in `stop-gate.sh`, which is the single place it lives.
- The counter is session-scoped state in the project directory, so the hooks now
  write to the consumer's tree. The gate still does not — that asymmetry is
  stated in `hooks/README.md` so it is not read as an erosion of §5's
  no-side-effects rule.
- If `stop_hook_active` or an equivalent returns to the API, this counter should
  be replaced by it, and this entry superseded.

---

## ADR-0009 — The compaction flush writes `.claude/in-flight.md`, not `CLAUDE.md`

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

The `PreCompact` hook exists because compaction is the most common cause of
working-memory drift: the session survives, the knowledge of what it was halfway
through does not, and the agent afterwards reconstructs a plausible substitute.
The specified behaviour was to append the in-flight state to `CLAUDE.md`'s
current-state section before that context is lost.

Appending to `CLAUDE.md` breaks two things at once.

**It defeats gate check 4.** Check 4 fails a change when files under `src/`
changed and `CLAUDE.md` did not. A hook that writes `CLAUDE.md` on every
compaction satisfies that condition mechanically, with no one having thought
about what changed. The check keeps reporting green while enforcing nothing —
silent degradation, in the mechanism built to detect it.

**It breaks the line budget.** `CLAUDE.md` has a hard 300-line ceiling and a
compression protocol for routing detail elsewhere. A machine appending a
timestamped block per compaction blows through it, and the protocol explicitly
forbids committing an over-budget file with a note to clean it later.

**Alternatives considered:**

- **Append to `CLAUDE.md` as specified and accept the check-4 hole.** Rejected:
  it disables the working-memory check in the name of protecting working memory.
- **Append to `CLAUDE.md` inside a delimited block, and teach check 4 to ignore
  changes confined to that block.** Rejected: it works, but it modifies the gate
  to accommodate a hook. The gate is the authority on what "done" means
  (DESIGN.md §5); carving an exception into it so a convenience feature can
  write to a governed document inverts that.
- **Write nothing and rely on the agent to summarise before compaction.**
  Rejected: that is the aspirational version this hook replaces. An instruction
  that fires only when a long session remembers to follow it is unreliable
  exactly when the session is long enough to need it.

### Decision

`flush.sh` writes to `.claude/in-flight.md` — git-ignored, capped at the four
most recent snapshots — and never touches `CLAUDE.md`. `orient.sh` reads the
file back at `SessionStart` and reports its presence as a state disagreement, so
a compacted session resumes from a record rather than a reconstruction.

The prompt's requirement is met at the level of intent: in-flight state survives
compaction and reaches the next session. Only the destination changed, and it
changed to avoid disabling the check that catches the very drift being guarded
against.

### Consequences

- `CLAUDE.md` remains hand-maintained, which is the point. Check 4 still fails a
  `src/` change that did not update it.
- In-flight state is now in a second place. `hooks/README.md` and `CLAUDE.md`'s
  file-structure block both name it so it is findable; an unnamed file is worse
  than no file.
- The snapshot is local: git-ignored, so it does not survive a clone and cannot
  hand off between machines. That is correct for transient session state and
  wrong for anything durable — durable records belong in the ledger documents.
- If the file is ever wanted in review, that is a new decision superseding this
  one, not an edit to `.gitignore`.

---

## ADR-0010 — Hooks are registered in shell form, not exec form

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

Hook commands can be written two ways. **Exec form** sets an `args` array and
spawns the command directly with no shell, so every argument is passed verbatim
— a project path containing spaces cannot split, and no quoting is needed.
**Shell form** passes a command string to a shell, which tokenizes it; the
harness uses Git Bash for this on Windows.

Exec form is the documented recommendation wherever a path placeholder appears,
and it was what T-005 built first. It does not work here.

Exec form resolves `command` against `PATH`. On this machine Git Bash is
installed at `C:\Program Files\Git\bin\bash.exe` and `bash` does **not** resolve
on `PATH` — confirmed by `Get-Command bash` returning nothing. Under exec form
every hook would fail to spawn: no gate, no boundary, no orientation, and no
error attributable to any of them. ADR-0006 established Git Bash as a Windows
prerequisite but said nothing about `PATH`, and the two are not the same claim.

This is the failure mode the whole project is built against. A gate that cannot
run fails loudly by design; a hook whose command cannot be spawned does not run,
enforces nothing, and announces nothing.

**Alternatives considered:**

- **Keep exec form and add `C:\Program Files\Git\bin` to `PATH`.** Rejected as
  the primary fix: it makes correct operation depend on a machine setting no
  file in the repository can assert, and it fails silently again on the next
  machine. It remains a fine thing to do, but it cannot be the mechanism.
- **Keep exec form with an absolute `command` path to `bash.exe`.** Rejected:
  correct on exactly one machine, broken on every other and on POSIX entirely.
- **Ship both and let one win.** Rejected: matching hooks are deduplicated by
  command string, not by intent, so both would run — two gates per turn, and
  two `Stop` hooks racing to block.

### Decision

Shell form, with `"shell": "bash"` set explicitly and every path placeholder
wrapped in double quotes. This applies to both `plugins/governed-dev/hooks/`
`hooks.json` and devseed's own `.claude/settings.json` (ADR-0011).

The quoting recovers what exec form was wanted for: a project path containing
spaces still cannot split. `"shell": "bash"` keeps the harness from falling back
to PowerShell on Windows, where these bash scripts would not run.

**Verified live, unintentionally and conclusively.** Immediately after
`.claude/settings.json` was written in shell form, the `PreToolUse` boundary
hook fired on the very next `Edit` and blocked it — proving the wiring resolves
Git Bash without `PATH`, and that the boundary enforces.

### Consequences

- **SG-0006 is resolved by this entry.** The gap asked whether exec form's
  narrowing of ADR-0006 was acceptable. It was not; the narrowing is gone.
- A project path containing a `$`, a backtick or an apostrophe can still break
  shell form where exec form would not have. That is a far rarer condition than
  "Git Bash is not on `PATH`", and unlike it, it fails visibly.
- `preflight.sh` lost its bash-on-`PATH` check. Under shell form the condition
  cannot arise — if the script is running, bash was found — and a check that
  cannot fail reads as coverage while providing none.
- `hooks.json` carries this reasoning in `_CONVENTION_SHELL_FORM`, because the
  next reader's instinct will be to "fix" it back to the documented default.

---

## ADR-0011 — devseed mirrors the hook wiring in its own `.claude/settings.json`

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

devseed is governed by the tool it produces (ADR-0001). That dogfooding is the
only ongoing test that the discipline is usable — and for hooks it did not work
at all.

The hooks ship inside the plugin. devseed gets them only by installing the
plugin into itself, and **that install is pinned**: `plugin.json` deliberately
omits `version` (ADR-0001), so an install resolves to a commit SHA and stays
there. The copy on this machine is pinned at `70542ef38e36`, eleven commits
behind `HEAD`, with an **empty `gates/` directory** and the zero-hook
`hooks.json` placeholder. Nothing written under T-004 or T-005 was reachable
from it.

So the acceptance test for T-005 — break a check, confirm the `Stop` hook blocks
— could not be run in devseed at all. Neither could any subsequent change to a
hook be observed without committing, pushing, and explicitly updating first.

This consequence of omitting `version` was not recorded anywhere. ADR-0001 chose
the omission deliberately and for good reasons, and this entry does not reverse
it; it records the cost, which is that **an installed plugin is stale by
default**.

**Alternatives considered:**

- **Publish and update on every change.** Rejected: it reinstates the
  copy-and-drift loop ADR-0001 removed, one round trip per edit, and makes the
  fastest feedback in the system the slowest. It also means devseed can only
  dogfood code it has already published.
- **Install the plugin from a local path instead of the marketplace.** Not
  rejected on merit — it may well be the better answer — but it was not
  reachable from the documented `marketplace add` / `install` flow that
  `CLAUDE.md` records as the verified loop, and inventing an install mode to
  suit one repository is a larger change than a settings file.
- **Give up on dogfooding the hooks and test them only in a scratch project.**
  Rejected: it is exactly the "we will test it elsewhere" that leaves the
  primary repository ungoverned, and ADR-0001 kept dogfooding at the cost of a
  more complicated layout precisely to avoid this.

### Decision

devseed carries its own `/.claude/settings.json` registering the same eight
events against `${CLAUDE_PROJECT_DIR}/plugins/governed-dev/hooks/` — the working
tree. A hook edit takes effect on save, with no publish-and-update cycle.

The **scripts are not duplicated**. There is one copy of each, under
`plugins/governed-dev/hooks/`, and both wirings point at it. Duplication is
confined to the event set, the matchers and the async flags.

`hook_gate()` in `hooks/lib.sh` resolves the gate **relative to the running
script** rather than from `${CLAUDE_PLUGIN_ROOT}`, precisely because a stale
plugin may also be installed: taking the environment variable first would run
the working tree's hook against the installed copy's gate — two definitions of
done in one invocation.

### Consequences

- **A mirror that can drift.** `hooks.json` is the source of truth and
  `settings.json` follows it. Nothing notices divergence today, so **T-006's
  acceptance criteria are extended** to assert the two agree on events and
  matchers. Until T-006 lands, this is an unguarded seam and is named as one in
  both files.
- The consumer-facing path is unchanged. Consumers get the hooks from the
  plugin; only devseed carries the mirror, and `settings.json` says so in its
  own `_README`.
- Recorded here so it is findable: **omitting `version` from `plugin.json` means
  every install is pinned to a SHA and goes stale silently.** Any project
  depending on the plugin needs an explicit update step. That is a cost of
  ADR-0001, not a defect in it.
- `.claude/settings.json` is committed and shared, unlike
  `.claude/settings.local.json`, which `.gitignore` excludes as per-machine.

---

## Spec gaps observed

Assumptions made where the spec was silent, per
[`.claude/rules/ambiguity.md`](.claude/rules/ambiguity.md). Each is a guess
until confirmed.

**Convention:** a gap that gets settled is marked `(resolved in <ref>)` in its
heading and its Status updated — it is **not** removed. The record of what was
once ambiguous is the useful part: it shows where the spec was thin, which is
where it is likely to be thin again.

### SG-0001 — Root `CLAUDE.md` and `TASKS.md` do not exist *(resolved in ADR-0002)*

- **Date:** 2026-07-31
- **Status:** Resolved — both files created under T-003; the assumption below
  held, and the two files were Prompt 2's work as guessed.

The instruction for this change refers to "this repo's own
DESIGN.md/CLAUDE.md/DECISIONS.md/TASKS.md (from Prompt 1)" as an existing
permanent set. Prompt 1 created only `DESIGN.md`. `CLAUDE.md` and `TASKS.md`
were never created; `DECISIONS.md` was created by this change because ADR-0001
had to be recorded somewhere.

**Assumed:** the two missing files are Prompt 2's work, and creating them now
with invented content would install unsanctioned structure into the root
governance set. Left absent rather than guessed at.

**Depends on this:** if Prompt 2 does not create them, devseed has no
current-state record and no task ledger, and `precedence.md` has no `CLAUDE.md`
to grant current-state authority to.

### SG-0002 — The repository is public, deliberately and temporarily

- **Date:** 2026-07-31 (updated same day)
- **Status:** Open — deliberate, temporary, end condition not yet recorded

**Superseding the original entry**, which read that private was required and
public was an unresolved gap. That is no longer the situation and the entry now
contradicted reality — drift sitting in the file that catalogs drift.

`github.com/ajf42/devseed` is public. Confirmed by an unauthenticated API
request returning `"private": false`. This is **deliberate and temporary**, not
an oversight and not a reversal of the original reasoning.

The original requirement was private, on the grounds of IP-entanglement risk.
That concern has not been withdrawn — public is a window, not a new position.

**Verified benefit while public:** `claude plugin marketplace add ajf42/devseed`
clones over HTTPS unauthenticated, so the install loop can be tested from any
directory or machine with no credential setup. Once private it needs `gh auth`
or a credential helper.

**Assumed:** nothing about the specific driver. The human confirmed "temporary"
but has not recorded *what the window is for* or *what closes it*. Those are the
two facts that make "temporary" meaningful rather than indefinite, and they are
outstanding.

**Depends on this:** T-011 stays open. Every push while this is open publishes
to a public repository — currently governance documents and shell scripts with
no secrets, but that holds only as long as the content stays that way. If the
end condition is never recorded, "temporary" decays into "public", which is the
same drift this entry was rewritten to remove.

### SG-0003 — Whether consumer projects vendor their own `gate.sh`

- **Date:** 2026-07-31
- **Status:** Open — needs human confirmation

ADR-0001 established that `plugins/governed-dev/templates/` holds seed content
copied into consumer projects, and listed `gate.sh` among it. But the hook
convention in `hooks/hooks.json` invokes the gate from
`${CLAUDE_PLUGIN_ROOT}/gates/gate.sh` — the plugin's own copy — which means a
consumer needs no local copy at all. The two models are not obviously
compatible, and the spec does not say which is intended.

The question is forced by CI: T-009 runs "this exact script" from CI, where the
plugin is not installed and `${CLAUDE_PLUGIN_ROOT}` does not resolve. Either the
consumer vendors a copy, or CI installs the plugin first.

**Assumed:** nothing. `templates/gate.sh` is left as a placeholder rather than
filled with a copy, because vendoring a second copy of a 200-line multi-file
gate creates exactly the drift ADR-0002 already flagged as this layout's
sharpest cost — and doing it speculatively, before CI exists to say what it
needs, would bake in the answer before the question is asked.

**Depends on this:** T-009 (CI) cannot be built until it is settled, and T-008
(bootstrap) needs to know whether to copy a gate into the target project.

### SG-0004 — T-006 and T-009 criteria were reconstructed, not transcribed

- **Date:** 2026-07-31
- **Status:** Open — needs human confirmation against the source prompts

The instruction to fill in T-006 and T-009 said their criteria "are fully
specified in the source document" and "were simply not transcribed." That source
document — the full prompt series — is not available in this session. What was
available was the titles ("drift guards", "CI parity") and the surrounding
context in this repository.

**Assumed:** criteria were *derived* from those titles plus what the repo already
establishes — for drift guards, the structural-disagreement class named in
`precedence.md` and demonstrated by the §3 platform defect (ADR-0006); for CI
parity, the no-side-effects rule and the unresolved `${CLAUDE_PLUGIN_ROOT}`
question in SG-0003. They are plausible and specific, but they are not the
source text.

**Depends on this:** if the real Prompt 5 and Prompt 8 specify different
criteria, these tasks will have been written to the wrong target — and the
convention that criteria are written before work starts will have been satisfied
in form only. Check them against the source before starting either task.

### SG-0005 — Nothing says what boundary governs the main session thread

- **Date:** 2026-07-31
- **Status:** Open — needs human confirmation

T-007 and ADR-0007 define a write boundary per agent: spec-guardian, reviewer
and auditor read-only; implementer denied the three root ledger documents;
scribe scoped to `DECISIONS.md`, `TASKS.md`, `CLAUDE.md`. `boundary.sh` enforces
those at `PreToolUse`.

The hook event carries `agent_type` **only inside a subagent**. Work done by the
top-level session — which is most work — arrives with the field absent, and
neither `DESIGN.md` nor T-007 says what governs it.

**Assumed:** absent `agent_type` means the main thread, which has no declared
boundary, and is allowed. Recorded at the point of contact in
`plugins/governed-dev/hooks/boundary.sh`.

The alternative — deny by default — was not taken because it makes the project
unwritable outside a subagent, and every consumer of the plugin would find their
first edit blocked with no route through. But this assumption is the one that
decides whether the roster is enforcement or theatre: **the implementer boundary
only binds an agent that actually runs as the implementer subagent.** A session
doing implementer work on the main thread can still write `DECISIONS.md`, and
that is precisely the act ADR-0007 exists to prevent.

**Depends on this:** T-007's acceptance criterion is an observed denial, which
this satisfies for a real subagent. It does not close the main-thread route.
Settling this needs a human decision: either the main thread is trusted (state
it), or the top-level session must adopt a declared role and the boundary
applies to it too — which is a larger change than a hook.

### SG-0006 — Exec form narrows the Windows prerequisite from installed to on-PATH *(resolved in ADR-0010)*

- **Date:** 2026-07-31
- **Status:** Resolved — the assumption below was **wrong**, and was caught by
  testing rather than by reasoning. Exec form was not worth the narrowing: on
  the development machine it meant no hook would run at all. ADR-0010 moved both
  wirings to shell form with quoted placeholders, which needs no `PATH` entry
  and still cannot split a path containing spaces. The `TODO(spec)` marker in
  `hooks.json` is gone with the exec-form entries it annotated.

Every entry in `hooks/hooks.json` uses exec form — `"command": "bash"` with the
script path in `args` — because exec form passes each argument verbatim with no
shell tokenization, so a project path containing spaces cannot split.

Exec form has no shell, so `bash` must resolve **on `PATH`**. ADR-0006 made Git
Bash a prerequisite on Windows but said nothing about `PATH`, and the two are
not the same: on the development machine Git Bash is installed at
`C:\Program Files\Git\bin\bash.exe` and `bash` does **not** resolve on `PATH`.

The failure mode is the bad one. A gate that cannot run fails loudly by design;
a hook whose command cannot be spawned does not run, and a hook that does not
run enforces nothing and announces nothing.

**Assumed:** exec form is worth the narrowing, and the narrowing is a
documentation and preflight problem rather than a design change. `preflight.sh`
warns when `bash` is missing from `PATH` on Windows. Shell form with
`"shell": "bash"` would avoid it — the harness finds Git Bash itself in shell
form — at the cost of quoting every path placeholder by hand.

**Depends on this:** whether the plugin works at all on a Windows machine where
Git Bash is installed but not on `PATH`. If the answer is that it must, this
should flip to shell form with quoted placeholders and ADR-0006 should gain the
`PATH` requirement explicitly.
