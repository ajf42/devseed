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
- **Status:** Accepted — **superseded in part by ADR-0026** (2026-08-11), which
  reverses only the `version`-omission paragraph under "Decision". The plugin/
  governance split, the directory layout, and everything else here stand.

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

## ADR-0012 — The drift guard measures copying, and is one script, not six checks

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

T-006 asks for guards against the documents and the repository disagreeing.
The obvious reading is "check the documents are *correct*," which no script can
do — correctness is a judgement about meaning.

What is mechanically decidable is the *mechanism* by which they stop being
correct. A summary that references its source stays right when the source
changes. A summary that copied its source is a second copy with no maintainer,
and diverges the moment either side is edited. So the guard measures **copying,
not agreement**: a long verbatim run between a rules section and `CLAUDE.md` is
evidence of a future divergence, detectable today. The same logic covers the
rest — a path that resolves to nothing, an id with no entry, an ADR git
remembers and the file does not.

The prior art is `check_design_sync.py` in the utility-bill-pipeline, which
slid a 12-word window over one hardcoded DESIGN.md section. Two things about it
generalised badly: it named `§8` explicitly, so renumbering the spec silently
disarmed it, and it was Python in a project that had Python.

**Alternatives considered:**

- **Six more `check-NN-*.sh` files, one per drift class.** Rejected. The gate's
  checks stop at the first failure, which is right for "is this done?" — you fix
  it and re-run. It is wrong for a drift report: drift findings are independent,
  and being shown one of six means five more re-runs to see the list. T-006 also
  requires standalone execution for CI (T-009), which a sourced fragment cannot
  do. One script that accumulates findings and exits at the end satisfies both;
  `check-07-drift.sh` is a four-line adapter.
- **Port the Python directly.** Rejected. DESIGN.md §3 gives devseed no runtime
  and no dependencies, and `lib.sh` already carries a `python_bin()` workaround
  for a Windows shim that resolves but does not execute. A guard that silently
  skips where Python is absent is the silent degradation §5 exists to prevent.
  `awk` is present wherever `bash` is, which is already a hard requirement
  (ADR-0006).
- **Hardcode `§5`, as the original hardcoded `§8`.** Rejected — that is the
  defect, not the design. Check 7 finds rules sections by *title* matching
  rules/conventions/constraints/contract/standards, so the guard re-reads the
  spec at runtime and renumbering cannot disarm it.
- **Compare full hook command strings for parity.** Rejected: the two wirings
  point at different roots deliberately (ADR-0011), so the strings *must*
  differ. Only the event set, matchers, script basenames and async flags are
  compared — precisely the surface that can drift, since the scripts themselves
  are shared.
- **A stricter or looser window than 12 words.** 12 is inherited from the prior
  art and confirmed empirically here: at 12 devseed is clean, at 8 the only hit
  is the phrase "and the script disagree the script wins and", and at 6 a bare
  file path. The threshold sits above what legitimately co-occurs and below a
  copied bullet.

### Decision

Check 7 is `gates/drift.sh`: one bash script, six drift classes, every finding
reported, exit 2 at the end, runnable standalone. Canaries are derived from
`DESIGN.md` at runtime by section title. Text work is `awk`. `jq` is required
only for hook parity, and only where the mirrored pair exists.

### Consequences

- **Editing the spec never requires editing the guard.** This is the property
  worth the most and the one most easily lost.
- **A wrong-but-not-copied summary passes.** The guard catches the mechanism,
  not the meaning. Stated as a known limit in §5 so it is not mistaken for
  coverage.
- **`find_jq()` duplicates `_jq_dir()` in `hooks/lib.sh`.** Accepted
  deliberately: the two libs are separately-sourced deliverables — one by the
  gate, one by the hooks — and making either depend on the other to save nine
  lines would couple the gate's availability to the hooks'.
- **The reverse staleness test only covers top-level directories.** Going
  deeper would demand every file appear in the structure block, which fights
  the line budget the same file is held to.
- **Check 7 runs on the full gate, not `--fast`.** It walks git history for
  `DECISIONS.md`, which is too slow for a per-edit hook.
- **`CLAUDE.md`'s structure block is now load-bearing syntax**, not just prose.
  Its indentation and two-space comment column are parsed. The convention is
  recorded in §5 so it is not reformatted by accident.

---

## ADR-0013 — The shell is a write vector; the boundary inspects commands, not just paths

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

`boundary.sh` was wired at `PreToolUse` with the matcher
`Edit|Write|NotebookEdit`. The implementer's `tools:` allowlist includes `Bash`.

Those two facts do not compose. The hook reads `.tool_input.file_path`, which a
`Bash` call does not carry, so the boundary evaluated an empty path, matched
none of its ledger patterns, and **allowed**. `echo x >> DECISIONS.md` was never
a tool it watched. The load-bearing denial in ADR-0007 — the implementer cannot
write `DECISIONS.md` — held for three tools and was absent for a fourth that
reaches the same files.

This was not a bug in the sense of a mistake in logic. It is what happens when a
`tools:` list and a hook matcher are written at different times by different
reasoning, and nothing forces them to be checked against each other. Recorded
here rather than fixed quietly because the class matters more than the instance.

**Alternatives considered:**

- **Drop `Bash` from the implementer and grant a narrower `Bash(pytest:*)`.**
  **Not available.** This was the preferred option on inspection, and it does
  not exist. The `tools:` frontmatter field accepts exact tool names,
  `mcp__<server>` patterns, and `Agent(<type>)`; the parenthesised scoping
  syntax is documented only for `Agent`, and only for an agent running as the
  main thread. `Bash(pytest:*)` is `permissions.allow` syntax from
  `settings.json`, which is session-scoped rather than agent-scoped. There is no
  per-agent `permissions` field. `permissionMode` exists but is a mode, not a
  rule list, and is **ignored for plugin subagents** — which these are, along
  with the per-agent `hooks` and `mcpServers` fields. Verified against the
  subagent reference on 2026-08-05.
- **Drop `Bash` from the implementer entirely.** Rejected: the implementer's
  defining discipline is writing a failing test and *confirming it fails for the
  right reason*, which requires running it. An implementer that cannot execute
  anything cannot do test-first work, and would have to report results it never
  observed — trading a governance hole for a much worse honesty hole.
- **Parse the command and deny only writes into ledger paths.** Rejected as the
  primary test, in favour of the broader one below. Deciding which token in a
  shell command is a redirect target means reasoning about quoting, `eval`,
  heredocs, and command substitution. Every way of getting that wrong fails
  *open*, and a boundary that fails open is not a boundary.
- **Accept the hole and document it.** Rejected. ADR-0007 states that until the
  hook exists the boundary is documentation and `CLAUDE.md` must not describe it
  as enforced. A boundary enforced for three tools out of four is worse than a
  known-absent one: it reads as complete.

### Decision

`boundary.sh` inspects `.tool_input.command` and the `PreToolUse` matcher gains
`Bash|PowerShell`, in both `hooks.json` and the `.claude/settings.json` mirror.

Two predicates, deliberately blunt:

- **The implementer** is denied any shell command that *names* `DESIGN.md`,
  `DECISIONS.md` or `TASKS.md` — not merely one that writes to them. It holds
  `Read` and `Grep` for looking at those files, so over-blocking the shell costs
  it nothing it needs, and "names it" is a predicate that can be evaluated
  correctly where "writes to it" cannot.
- **The read-only agents** (spec-guardian, reviewer, auditor) are denied any
  command containing a shell-level write construct: a redirect other than to
  `/dev/null`, the usual file-mutating commands, or a state-changing `git`
  subcommand.

`PowerShell` is matched although no agent is granted it, because it is in the
built-in set a background subagent retains and a future roster change could
grant it without anyone revisiting this hook.

### Consequences

- **The shell check is syntactic and stops the expedient route, not a determined
  one.** `D=DECI; echo x >> ${D}SIONS.md` defeats it, as does any indirection
  through a variable, a glob, or a program's own file handling. This is stated
  in the hook, in `delegation.md`, and here, because a partial mitigation
  presented as complete is the failure mode this repository exists to prevent.
  The threat model ADR-0007 names is the agent that takes the cheap way out of a
  spec wall, not an adversary.
- **The capability boundary carries the weight the syntactic one cannot.** The
  scribe and spec-guardian hold no shell at all. That is not a matcher and
  cannot be outwitted, and it is why their `tools:` lists matter more than any
  hook.
- **Read-only agents lose benign shell writes.** An auditor cannot write a
  report to a file, and a reviewer cannot `git stash` to test a revert. Accepted:
  both return prose, and the alternative is a carve-out that has to be right
  about which writes are benign.
- **False positives are possible and are denials, not silent passes.** A `>` in
  a quoted string or a filename containing `TASKS.md` will block. Erring closed
  at an enforcement point is the correct direction, and the deny message names
  the command so the agent can rephrase.
- **The `PreToolUse` matcher now differs from `PostToolUse`'s**, which stays
  `Edit|Write|NotebookEdit` — the fast gate should not run on every shell
  command. Drift check 6 compares the two wirings against each other, not the
  two events, so this asymmetry is intentional and unguarded.
- **This coupling has no guard.** Nothing checks that an agent's `tools:` list
  and `boundary.sh` agree about which tools can write. The next tool granted to
  an agent could reopen exactly this hole, and the only thing standing in the
  way is the `*)` branch denying agents the hook does not recognise — which does
  not help when the agent *is* recognised and the tool is not. Recorded as a
  known gap rather than solved here.

---

## ADR-0014 — devseed mirrors the agent roster into `.claude/agents/`, and the guard enforces byte equality

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

The roster is built under `plugins/governed-dev/agents/` per ADR-0001's path
rule, so it ships. But Claude Code discovers project subagents in
`.claude/agents/`, and reaches a plugin's agents only through an *installed*
plugin — which, per ADR-0011, is pinned to a commit SHA and stale by default.
The copy on this machine sits at `70542ef`, long before any agent existed.

So devseed could ship a roster it could never run. T-007's acceptance is an
**observed denial**, which cannot be observed against agents that do not load.
This is ADR-0011's problem exactly, one artifact later.

**Alternatives considered:**

- **Symlink `.claude/agents` at `plugins/governed-dev/agents`.** Rejected: one
  copy and no drift, which is the appealing part, but git symlinks on Windows
  require `core.symlinks` and developer mode or admin rights, and check out as
  plain text files containing a path when they are unavailable. That failure is
  silent — the roster would simply not load, which is the same invisible
  non-enforcement this ADR exists to prevent.
- **Install the plugin from a local path so the agents load from it.**
  Rejected for the reason ADR-0011 gives: it was not reachable from the
  documented `marketplace add` / `install` flow, and inventing an install mode
  to suit one repository is a larger change than a copy.
- **Skip the live test and rely on the synthetic harness.**
  `scripts/boundary-regression.sh` already proves the hook's logic across 73
  cases without an agent running. Rejected as *sufficient*: it proves
  `boundary.sh` decides correctly given an event, not that the harness delivers
  the event — the matcher, the `agent_type` field, and the plugin namespacing
  are all untested by it. T-005 found three defects of exactly that kind, none
  visible to inspection.
- **Copy without a guard.** Rejected: an unguarded copy is the drift devseed
  exists to eliminate, and it would diverge the first time an agent was edited
  in one place.

### Decision

Mirror the five agent files into `.claude/agents/`, and extend the drift guard's
check 6 to compare the two directories. The test is **exact byte equality** in
both directions: every shipped agent present in the mirror and identical, and no
agent in the mirror that does not ship.

Byte equality, rather than the field-level comparison used for the hook wiring,
because these files carry no legitimate difference. The hook mirror compares
only events, matchers and flags precisely because its command paths *must*
differ; agent definitions have no such axis, so any difference at all is drift.

### Consequences

- **`plugins/governed-dev/agents/` is the source of truth.** Edit there, then
  re-copy. Editing the mirror and letting the guard complain also works, but
  gets the direction backwards and the fix text says so.
- **Two more copies of five files exist in the repository.** Accepted because
  the guard makes the duplication self-correcting: it fails the gate rather
  than drifting quietly, which is the standard this repository holds every other
  duplication to.
- **A consumer is unaffected.** The check is self-disabling — no
  `plugins/governed-dev/agents/` means nothing to compare — and consumers get
  the roster through the plugin, which is the path that works for them.
- **This is the second artifact to need the ADR-0011 workaround**, after the
  hook wiring. A third would be evidence the pinned-install problem needs
  solving at its root rather than mirrored again per artifact.

---

## ADR-0015 — Normalize `*.sh` to LF via `.gitattributes`, regardless of local `core.autocrlf`

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

On Windows, `core.autocrlf=true` lands every tracked script CRLF at checkout.
Git for Windows patches its own `bash` to ignore a trailing CR, so a CRLF
script still runs there — confirmed directly: `drift.sh` running CRLF under
gate check 7 passed with the gate exiting 0. That tolerance is specific to
Git Bash. WSL bash, `dash`/`sh`, and Linux CI reading a Windows-authored tree
do not ignore the trailing CR, and the repository currently ships CRLF to all
of them the moment a Windows contributor without `core.autocrlf=input` clones
and commits.

The change was sanctioned under DESIGN.md §4 ("whatever it takes to copy this
scaffold into a new repo and have it work") and §3's platform row (bash / Git
Bash as a stated Windows prerequisite), on the premise that a CRLF script is a
form Git Bash itself cannot execute. That premise was tested directly and
**disproved** — Git Bash tolerates it fine. The defect is real but narrower
than first stated: it is a cross-platform and CI problem, not a Windows-shell
problem. The sanction still holds under the same two clauses, for the
corrected reason.

**Alternatives considered:**

- **`core.autocrlf=input` as local git config.** Rejected: config is
  per-clone and not versioned. It protects only a contributor who remembers to
  set it and does not travel with a fresh clone, which is the exact failure
  this change exists to close.
- **A broader `.gitattributes` covering more filetypes.** Rejected as out of
  scope for this change: spec-guardian's sanction covered `*.sh` specifically
  and did not pre-clear a general normalization policy. Extending coverage to
  other extensions would need its own ruling.
- **Do nothing.** Rejected: it is the status quo that produced the defect —
  a Windows checkout can silently commit CRLF scripts that fail wherever the
  tolerance Git Bash grants does not extend, with no signal until something
  else reads the tree.

### Decision

Add root `.gitattributes` with one rule: `*.sh text eol=lf`. All 20 tracked
shebang-bearing scripts in the repository are `*.sh`, so the single rule has
full coverage with no gap.

### Consequences

- Every clone, regardless of local `core.autocrlf`, checks out `*.sh` as LF.
  What this closes is specifically WSL bash, `dash`/`sh`, and Linux CI reading
  a Windows-authored tree — not Git Bash on Windows, which already tolerated
  CRLF and was never actually broken by it.
- The index was already LF and none of the 20 tracked blobs contained a CR, so
  landing the rule required no `git add --renormalize` and changed no file
  content.
- Coverage is scoped to `*.sh` only, matching the sanction that was actually
  granted. `plugins/governed-dev/templates/` — which seeds a consumer's own
  repository, including its `gate.sh` — has no equivalent protection yet.
  Recorded as its own open question rather than folded into this decision,
  since extending scope to what ships to consumers needs its own ruling. See
  SG-0008.

---

## ADR-0016 — Local-path plugin install was tested and does not retire the mirrors; skills are a third, deliberate mirror

- **Date:** 2026-08-06
- **Status:** Accepted

### Context

ADR-0011 mirrored the hook wiring, ADR-0014 the agent roster, both because an
installed plugin pins to a commit SHA. ADR-0014 said "a third would be
evidence the pinned-install problem needs solving at its root rather than
mirrored again per artifact." Both ADRs listed "install the plugin from a
local path" as an alternative and rejected it as not reachable from the
documented flow. That premise was tested directly rather than reasoned about.

**What the test found.** `claude plugin marketplace add <path>` **is**
supported — the CLI documents "URL, path, or GitHub repo" and stores source
type `directory`. But `claude plugin install` still copies the plugin into
`~/.claude/plugins/cache/<marketplace>/<plugin>/<sha>` keyed by commit SHA,
exactly as for a GitHub source. An uncommitted working-tree edit is invisible;
`plugin update` reports "already at the latest version". A local commit — no
push, no remote at all — plus `marketplace update`, `plugin update` and a
restart does move the pin. A **non-git** source directory instead gets version
`unknown` and refreshes from the working tree on `plugin update`, but devseed
is a git repository so that branch is unavailable without deleting `.git`.

So the alternative is now reachable but does not solve the problem: it removes
the push/GitHub round trip and nothing else. The working tree is still not the
installed copy.

**Alternatives considered:**

- **Local-path install.** Reachable, but per the evidence above still
  SHA-pinned and still a copy, so it retires nothing.
- **Delete `.git` to get the non-git refresh behaviour.** Rejected: absurd for
  the repository under governance, and it would end version control on the
  thing being governed.
- **Symlink the mirrors.** Already rejected in ADR-0014 because git symlinks
  on Windows need `core.symlinks` plus developer mode and check out as plain
  text files containing a path when unavailable, failing silently.
- **Skip the mirror and accept devseed cannot run its own skills.** Rejected:
  it is the same non-dogfooding ADR-0011 and ADR-0014 both refused, and an
  unrun skill is an unverified one.

### Decision

Add `.claude/skills/` as a third mirror, and extend drift check 6 to
byte-equality it in both directions as it already does for agents. The
threshold ADR-0014 named has been crossed and the root cause was investigated
as that sentence asked; the finding is that the root fix is not available at
this layer.

### Consequences

- Three mirrored artifacts now, guarded but real.
- The pinned-install cost of omitting `version` from `plugin.json` (ADR-0001)
  is now confirmed structural rather than incidental.
- If a future CLI release makes an install track a working tree, all three
  mirrors and their guards should be retired and this entry superseded.
- Byte-equality parity on `.md` files is fragile under `core.autocrlf=true` —
  see SG-0009.

---

## ADR-0017 — The rule files ship to consumer projects

- **Date:** 2026-08-06
- **Status:** Accepted

*This resolves SG-0007.*

### Context

The five shipped agents cite `.claude/rules/precedence.md` and
`.claude/rules/ambiguity.md` by path, and `hooks/boundary.sh` cites
`.claude/rules/ambiguity.md` in its deny messages, but `.claude/rules/` did
not ship — so in a consumer project those references dangled while still
reading as authoritative. SG-0007 named three options and said T-008 forces
the answer. The human directed that one be picked and recorded, and that
leaving it undecided was the one thing not permitted.

**Alternatives considered:**

- **Inline each rule's substance into the agent prompts and drop the
  citations.** Rejected: it duplicates text into five files that will drift,
  which is exactly what drift check 1 exists to catch, and the rules are
  longer than an agent prompt should carry.
- **Ship the roster and document the dangling references in the plugin
  README.** Rejected: a reference that reads as authoritative and resolves to
  nothing is the worst of the three, and a README note does not reach the
  agent at the moment it cites the path.
- **Ship the rules.** Chosen.

### Decision

`plugins/governed-dev/templates/rules/` now holds consumer-facing
`precedence.md`, `ambiguity.md`, `delegation.md` and `ledger.md`, and the
bootstrap skill installs them into the consumer's `.claude/rules/`. The
shipped copies are the same substance with devseed's own ADR/SG ids and
repo-specific paths stripped.

### Consequences

- Consumers adopt more.
- Two copies of each rule now exist with one maintainer and **no guard
  compares them**, because byte equality would be wrong — the difference is
  deliberate (see SG-0011).
- `.claude/rules/ledger.md` said the shipping question was undecided and has
  been corrected in place.
- **Related defect surfaced:** nothing shipped from `templates/` may cite a
  devseed ADR/SG id, because the drift guard scans every tracked file and
  such a citation fails the *consumer's* gate on their first commit in a repo
  they have not touched. `templates/gate.sh`, `templates/.gitignore` and
  `templates/README.md` were rewritten to remove four such citations, and
  `scripts/bootstrap-regression.sh` now enforces the rule.

---

## ADR-0018 — `/amend` is deferred to Prompt 9 rather than built now

- **Date:** 2026-08-06
- **Status:** Accepted

### Context

Prompt 7 asked for an `/amend` skill implementing a four-part amendment
procedure. spec-guardian ruled **CONFLICT**: `DESIGN.md` §4 defers the
amendment procedure to §6 "filled in by Prompt 9", §6 says "until it is
written, there is no sanctioned path for editing this document," and the
four-part shape appears nowhere in `DESIGN.md`. T-021 already pairs the
executor with T-010 and states "the procedure and its executor are separate
tasks".

**Alternatives considered:**

- **Build it against the prompt's four-part procedure, treating the human as
  supplying §6's content.** Rejected: it makes the tool the source and §6 the
  transcription, which is the direction `precedence.md` forbids, and a
  working tool would then shape what T-010 writes.
- **Build it inert, refusing until §6 exists.** Rejected on the narrower
  ground that the artifact built to detect and refuse would still encode the
  deferred procedure, which is what §4 reserves for §6.
- **Defer.** Chosen by the human when the conflict was put to them.

### Decision

`/amend` is not built. It stays T-021, Prompt 9, paired with T-010.

### Consequences

- Prompt 7's deliverable is four skills, not five, and that is stated rather
  than quietly absorbed.
- `DESIGN.md` §6 stays a placeholder, so the repository currently has no
  sanctioned route to amend its own constitution — which is a real hole with
  a scheduled fix.

---

## ADR-0019 — `preflight.sh` installs under CI, still only reports on a
developer machine

- **Date:** 2026-08-11
- **Status:** Proposed — built, not yet run in anger; revisit if this is wrong

### Context

Prompt 8 (T-025) asks the `Setup` hook to *install* dependencies, not merely
detect them, "so a fresh clone or a CI container becomes gate-ready in one
command." The existing `preflight.sh` only ever reported and advised. The
prompt does not say whether install-on-detect should also apply to an
interactive developer session, and that is not a neutral gap: a Setup hook
that silently runs a package manager on someone's own machine is a materially
different act than the same behaviour inside a disposable CI container nobody
is sitting at.

**Alternatives considered:**

- **Install everywhere, CI or not.** Rejected: `Setup` fires on `claude
  --init-only` and `-p --init`, both explicit developer-invoked actions, but
  "explicit" is not the same as "consented to a package manager write." A
  human running `--init-only` to prepare a project has not necessarily agreed
  to `sudo apt-get install`, and the existing report-and-advise behaviour
  already works and is tested.
- **Never auto-install; require a human to run the printed command.**
  Rejected: it satisfies safety but not the prompt's actual ask — "a CI
  container becomes gate-ready in one command" specifically names the
  unattended case Prompt 8 wants solved.
- **Install only under `$CI`.** Chosen. `$CI` is a convention GitHub Actions,
  GitLab CI, and most other CI systems already set, so no new signal needed
  inventing, and it draws the line exactly where "disposable, unattended
  container" stops being true.

### Decision

`preflight.sh` installs `jq` via `apt-get` when `$CI` is set and `apt-get` is
on `PATH`; otherwise it reports and advises, unchanged from before. Verifying
the test runner and linter are present is delegated to `gate.sh --fast`
rather than re-implemented, so "what counts as declared tooling" has exactly
one definition (checks 1–3), not two drifting copies.

### Consequences

- Non-Linux CI runners (or ones without `apt-get`) fall back to report-only,
  silently — `have apt-get` is the only gate on the install path. Untested
  against anything but a GitHub Actions `ubuntu-latest` runner.
- `preflight.sh` now runs the full declared build/test/lint on every `Setup`
  event, not just a presence probe. Heavier than "present," but avoids a
  second, narrower detection implementation. Revisit if this makes `--init`
  noticeably slow on a real project with a real suite.
- `git` and bash-on-PATH stay report-only in every environment; Prompt 8 named
  installation for "jq, the test runner, and the linter," not for `git`
  itself.

---

## ADR-0020 — devseed's own CI needs neither a vendored `gate.sh` nor
`${CLAUDE_PLUGIN_ROOT}`

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

T-009 required resolving SG-0003's CI half: `hooks.json` locates the gate via
`${CLAUDE_PLUGIN_ROOT}`, which does not resolve outside a Claude Code session,
so CI needs a different way to find `gate.sh`.

**Alternatives considered:**

- **Vendor a copy of `gate.sh` for CI to call.** Rejected: a second copy of a
  multi-file gate is exactly the drift ADR-0002 already named as this layout's
  sharpest cost, and devseed already refuses to do this for consumer projects
  (SG-0003's bootstrap half).
- **Install the plugin in the CI container before running it**, e.g. `claude
  plugin marketplace add` + `install`. Rejected as unnecessary complexity and
  circularity for devseed's own CI specifically: this repository already *is*
  `plugins/governed-dev/`'s source. Installing devseed's plugin into a
  checkout of devseed to find a script that already sits at a known
  repo-relative path solves a problem devseed's own CI does not have.
- **Call `plugins/governed-dev/gates/gate.sh` by its repo-relative path.**
  Chosen. Matches `hooks/lib.sh`'s own `hook_gate()`, which already prefers
  the sibling path over `${CLAUDE_PLUGIN_ROOT}` for the same reason (see its
  comment: devseed dogfoods against the working tree, not the installed,
  possibly-stale copy).

### Decision

`.github/workflows/gate.yml` checks out devseed and runs `bash
plugins/governed-dev/gates/gate.sh` directly. No vendoring, no plugin install
step, no `${CLAUDE_PLUGIN_ROOT}`.

### Consequences

- Settles SG-0003 **for devseed's own CI only**. A consumer project's CI truly
  does not have the plugin's source checked out, so this reasoning does not
  transfer, and that half of SG-0003 is explicitly left open in its own entry
  rather than closed by implication.
- CI platform is GitHub Actions, unstated by any prompt but an obvious
  consequence of `github.com/ajf42/devseed` already being where this repo
  lives (`CLAUDE.md`).

---

## ADR-0021 — Headless auditor runs via `anthropics/claude-code-action`,
prompted rather than flagged into identity

- **Date:** 2026-08-11
- **Status:** Proposed — unverified in three specific ways, named below;
  revisit before trusting this workflow to actually run

### Context

T-026 asks for a scheduled, unattended run of the auditor agent. Research
(via the `claude-code-guide` subagent) found an official
`anthropics/claude-code-action`, and confirmed **no CLI or Action flag exists
to make a headless run assume a specific pre-defined subagent's identity** —
the only mechanism is prompting normally and trusting Claude to delegate via
its own Task tool, exactly what an interactive session already does when
`task/SKILL.md` says "invoke [the auditor] directly."

**Alternatives considered:**

- **Wait until subagent-identity invocation is confirmed possible**, rather
  than ship something resting on an unverified mechanism. Rejected for this
  pass: Prompt 8 asked for the workflow, and the same trust-the-prompt
  mechanism already underlies every other headless/interactive invocation of
  the auditor in this repository — this is not a weaker guarantee than what
  already exists, just a newly *unattended* instance of the same one.
- **Raw `claude -p` CLI instead of the official Action**, for direct control
  over output capture. Rejected for this pass: the exact flags (`-p` output
  format, permission-skip mechanism, npm package name) were not confirmed
  before this work paused, and fabricating exact CLI syntax into a CI file
  that will not be exercised until the next scheduled run is worse than using
  the confirmed, documented Action entrypoint.

### Decision

`.github/workflows/audit.yml` uses `anthropics/claude-code-action@v1` with a
prompt that restates the auditor's own brief and a `claude_args` tool
allowlist (`Read,Grep,Glob,Bash`) as defense in depth alongside the prompt
itself — belt and suspenders, not a hard boundary, since no hard boundary is
available headlessly.

### Consequences — three things to verify before trusting this workflow

1. **No `ANTHROPIC_API_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`) secret exists yet.**
   The workflow references `secrets.ANTHROPIC_API_KEY` and will fail closed
   until one is added — not silently invented here.
2. **`steps.auditor.outputs.result` is a guess** at the Action's output field
   name, not confirmed against its actual documented outputs. If wrong, the
   job summary posts empty rather than failing loudly — worth an explicit
   check the first time this runs.
3. **Whether `$GITHUB_STEP_SUMMARY` is reachable from inside the Action's own
   sandboxed tool calls is unconfirmed.** Written to avoid depending on the
   answer — the Action's result becomes a step output, and a separate plain
   shell step does the appending — but if the Action's actual output shape
   differs from (2), both problems compound.

Also open, structurally rather than as a bug: GitHub disables scheduled
workflows after 60 days of repository inactivity. `workflow_dispatch` is
wired as a manual fallback; nothing in this file prevents the schedule itself
from going quiet.

---

## ADR-0022 — Commit trailer's `Agent-Type` is always `main`

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

T-027 (closing SG-0010) asks every `/task`-made commit to carry a trailer
naming, among other fields, the agent type. But four agents genuinely
contribute to one task — spec-guardian, implementer, reviewer, scribe — and
none of them holds the tool that runs `git commit`; `/task` itself does, on
the main thread, which SG-0005 already notes carries no `agent_type` of its
own within this repository's boundary model.

**Alternatives considered:**

- **Attribute to whichever agent wrote the most lines**, e.g. `implementer`
  for ordinary tasks. Rejected: arbitrary (what counts as "most"?), and wrong
  for a task that is mostly a scribe or reviewer action.
- **List all four agents that ran**, e.g.
  `Agent-Type: spec-guardian,implementer,reviewer,scribe`. Rejected: true but
  low-signal — it would read the same on nearly every commit, telling a
  reader nothing they could not already assume from "this repo uses the
  four-agent loop."
- **`main`.** Chosen: it is simply the honest answer to "what made this git
  commit call" — matching `activity.sh`'s own existing default
  (`${AGENT:-main}`) for events with no subagent context — and it does not
  discard per-agent attribution, because `Session-Id` already joins the
  commit to every `SubagentStop` line in `.claude/activity.jsonl` for that
  session, each carrying its own real `agent_type`.

### Decision

Every `/task` commit trailer reads `Agent-Type: main`. Per-agent attribution
for a given task is recovered by joining `.claude/activity.jsonl` on the
commit's `Session-Id`, not by varying this field.

### Consequences

- The field is low-variance by design — expect to see `main` on every commit
  `/task` makes. Its value is ruling out *other* processes (a human commit, a
  future non-`/task` automation), not distinguishing among the four agents.
- This makes `.claude/activity.jsonl` load-bearing for the very question the
  trailer's introduction was meant to answer ("which agent wrote this"). If
  `activity.jsonl` is ever pruned or goes missing for a session, that
  session's commits keep their `Session-Id` but lose what it would have
  joined to.

---

## ADR-0023 — §6's shape: tightening fully exempt, `/amend` the chokepoint, bypass as two trailers

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

Prompt 9 supplied §6's substance — ADR-before-edit with a named-incident
evidence bar, the tightening/loosening asymmetry, sanctioned emergency
bypass with reconciliation, the quarterly self-audit. Writing it into
DESIGN.md still forced choices the prompt did not make.

**Alternatives considered:**

- **Require a lightweight record even for tightenings** (a one-line log
  entry, short of an ADR). Rejected: the prompt's asymmetry is the design —
  "tightening a gate needs no ADR" — and a mistaken tightening is
  self-announcing (the gate blocks, someone notices, the fix carries its own
  incident). Ceremony on the safe direction prices safety.
- **Have `/amend` also handle emergency bypasses** — one tool for every
  gate-related exception. Rejected: a bypass is by definition done under
  pressure, outside procedure; wiring it into the procedural tool invites
  running the amendment machinery at the worst possible moment, and §6's
  trailer-plus-task obligations need no tool.
- **Have `/amend` commit its own amendment.** Rejected: `/task` is the only
  committer by design (Prompt 7), and an amendment commit is exactly the
  commit that most deserves the full loop.
- **Build the §6 enforcement checks now** (bypass reconciliation, CI-parity
  invocation guard, check-inventory parity). Rejected for this pass:
  T-028's findings become tasks (T-029, T-030) rather than unsanctioned
  same-commit mechanism — the audit's own discipline, applied to itself.

### Decision

§6 as written: correction vs. amendment defined by whether a constraint
changes; ADR → explicit human approval → edit, in that order, with `/amend`
the executor and sole sanctioned route; ratchet with tightening fully
exempt; bypass via `Gate-Bypassed:` / `Bypass-Reason:` trailers plus an
opened reconciliation task; quarterly self-audit with the first run dated
(T-028) and the next due 2026-11-11.

### Consequences

- §6's obligations are born unenforced — the bypass-reconciliation rule and
  the quarterly cadence hold by review until T-029 lands. Stated in §6
  itself rather than left to be discovered.
- `/amend` reads §6 at each run and defers to it, so an amendment to §6
  does not require re-editing the skill — but a §6 change that contradicts
  the skill's hard refusals (drift-to-spec, committing) would need the
  skill updated by ordinary means; the two are deliberately redundant on
  those two refusals.
- The chokepoint is honest but soft: nothing mechanical prevents a main-
  thread edit to DESIGN.md outside `/amend` (SG-0005's known scope limit).
  The procedure's authority rests on the same footing as the rest of the
  rule layer for main-thread work — convention plus review.

---

## ADR-0024 — reviewer and auditor keep `Bash`; their write-boundary is best-effort by acceptance, not by accident

- **Date:** 2026-08-11
- **Status:** Accepted (human decision, 2026-08 audit closure)

### Context

The T-028 self-audit confirmed what ADR-0013 had already admitted: reviewer
and auditor hold `Bash` while `delegation.md`'s table said they "write
nothing," and the gap between those two statements is bridged only by the
syntactic `PreToolUse` hook, which stops the expedient redirect and not a
determined evasion. The audit filed it as a confirmed tension awaiting a
human ruling.

**Alternatives considered:**

- **Strip `Bash` from both agents.** Rejected: their job *is* running
  things — the reviewer runs tests, the gate, and `git diff`; the auditor
  runs the drift guards. Removing the shell cripples the function the
  agents exist for, leaving a boundary pure and a roster useless.
- **A stricter syntactic hook** (broader command patterns, deny-by-default
  on unrecognized shapes). Rejected: it raises the false-positive surface
  on exactly the two agents running the most varied commands — and a gate
  that cries wolf gets bypassed, which defeats the system more thoroughly
  than the narrow evasion it was meant to close.

### Decision

Reviewer and auditor keep `Bash`, permanently. The write-boundary for these
two agents is syntactic and best-effort — ADR-0013's existing admission,
now accepted as the design rather than tolerated as a gap. The backstop is
structural: their outputs are themselves gated. A reviewer or auditor that
somehow wrote its way past the hook still changes nothing durable without
passing the same gate, ledger checks, and drift guards as everything else.

`delegation.md`'s table (both the root copy and the shipped consumer copy)
now says what is true — "holds `Bash`; write-boundary best-effort, outputs
gated" — prose catching up to reality, per §5's own sanction.

### Consequences

- The audit's confirmed-tension item is closed. Future audits should cite
  this ADR rather than re-reporting the tension as a finding.
- The system accepts that its two watchdog agents are held by convention
  plus a syntactic net rather than by capability absence. Anyone extending
  the roster should copy the *pattern* knowingly: agents whose function
  needs a shell get one, and their outputs get gated instead.

---

## ADR-0025 — First matrix run red on all three legs: shallow checkout was the cause; the offered awk-dialect diagnosis was a different, latent defect

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

The first CI run in this repository's history (the three-leg matrix,
T-009/T-030) failed at check 5 on every leg:

> GATE FAIL [5/7 task ledger]: ## T-001 — Governance scaffold cites commit
> aa53aef, which does not resolve to a commit in this repository.

The diagnosis offered alongside the failure blamed ERE interval expressions
(`{7,}` / `{7}`) inside awk programs — unsupported by some awks, notably
older mawk — at three sites: `drift.sh`'s done-task scan and two in
`orient.sh`. Verification showed that cannot be what happened:

- The failing message is check 5's **resolution** branch, not its
  no-hash branch. Check 5's awk already used the portable longhand
  (`[0-9a-f][0-9a-f]…`), extracted `aa53aef` correctly on whatever awk the
  runner has, and `git cat-file -t` then failed to find the commit.
- `gate.sh` stops at the first failing check, so `drift.sh` — where the
  interval regex lives — never ran at all.

The actual cause: `gate.yml` used `actions/checkout@v4` with its default
`fetch-depth: 1`. A depth-1 clone contains only HEAD; `aa53aef` is the
second commit in history, so every historical hash the ledger cites
resolves to nothing — on every leg, deterministically, starting with the
first done task checked. The same shallow clone also silently guts drift's
superseded check, which walks `DECISIONS.md`'s git history: one commit of
history means nothing to compare and a pass that proves nothing —
degradation without failure, the exact mode §5 is written against.

Two predictions were wrong in instructive ways. `gate.yml`'s own comment
named macOS the risky leg; the first red was platform-independent. And the
defect was invisible locally for the project's entire life not because of
awk dialects but because a developer clone is never shallow — no local run
could ever have seen it.

The interval-regex finding, though not the cause, was real and is the
second half of this record. `drift.sh` duplicated check 5's done-task
logic **deliberately** (it also runs standalone, where the rest of the
gate may not have), and the copies had already drifted: check 5 portable
longhand, `drift.sh` `{7,}`, `orient.sh` `{7}` and `{7,}`. On an awk
without interval support the interval form never matches, the extracted
hash stays empty, and every done task reads as hashless. Awks on the
current runner images appear to support intervals, so the divergence was
latent rather than live — but copy-drift inside the drift guard, with no
guard comparing the copies, is the exact failure class this repository
exists to catch, occurring in the component whose job is catching it.

The portability audit prompted by the diagnosis found two more genuine
platform breaks the diagnosis missed: GNU-only `sed -i` (one use also
carrying `\n` in the replacement, another GNU-ism) at two sites in
`scripts/gate-regression.sh`. BSD sed treats `-i`'s next argument as the
backup suffix, so the suite would have failed on the macOS leg — the
risky-leg prediction come true, one file over from where it was predicted.

**Alternatives considered:**

- **Deepen the clone just enough** (`fetch-depth: N`). Rejected: any
  finite N re-breaks the day history outgrows it, and the superseded walk
  needs full history regardless.
- **Extract the duplicated done-task scan into `gates/lib.sh`.** Feasible —
  `drift.sh` already sources `lib.sh`, so "standalone" does not preclude
  sharing. Rejected on minimum-size grounds (T-029's precedent): the two
  callers differ in reporting semantics — check 5 dies at the first
  finding, drift accumulates all of them with line numbers — so the truly
  shared piece is one awk program. Making the copies textually identical
  and asserting they agree is smaller than the refactor. If they drift a
  second time despite the guard, that incident is the evidence for
  extraction.
- **Install gawk on all legs.** Rejected: the gate promises to run on the
  platforms CI tests as they ship (DESIGN.md §3); installing around a
  dialect difference narrows that promise instead of keeping it.

### Decision

1. `gate.yml` checks out with `fetch-depth: 0`. Full history is a
   prerequisite of two checks' evidence: hash resolution (check 5, and
   drift's copy of it) and the superseded history walk.
2. Every ERE interval expression inside an awk program is normalized to
   the longhand check 5 already used — `drift.sh` one site, `orient.sh`
   two — and the two `sed -i` uses in `gate-regression.sh` are rewritten
   portably. Correction, not amendment: no constraint changes; scripts
   catch up to the existing promise that the gate and its suites run on
   the platforms CI tests. The §6 ratchet does not apply.
3. The check-5/drift duplication stays and gains a guard: assertions in
   `scripts/gate-regression.sh` that both copies rule the same `TASKS.md`
   fixtures the same way — a done task with a resolving hash passes both,
   a hashless done task fails both, a fabricated hash fails both.

### Consequences

- The dev machine (Git Bash: gawk, GNU sed, full clone) structurally
  cannot surface shallow-clone or BSD/mawk dialect defects. The matrix is
  the only detector for this class, and this incident — found on the
  first matrix run ever — is the matrix earning its keep.
- The longhand regex is uglier than `{7,}` and will tempt
  re-simplification; each site now carries a comment saying why it is
  written that way.
- Residual, noted and deliberately not changed: `flush.sh` sets a
  multi-character `RS`, undefined under POSIX but supported by gawk,
  current mawk, and macOS's awk. It runs only in local hooks, never in
  CI. If a platform ever joins where it differs, it is the next edge of
  this same class.

---

## ADR-0026 — `plugin.json` declares `version`, superseding ADR-0001 on the distribution question only

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

devseed is being prepared for people other than its author to install. Three
things blocked that; this ADR covers the second. ADR-0001 decided:

> `plugin.json` deliberately **omits `version`**. For a solo,
> actively-iterated tool, every commit being the current version is the right
> default. A version string gets pinned only once another project depends on
> stability across a specific release — at which point the need is real
> rather than anticipated.

That condition has now been met, on ADR-0001's own terms: the need is real
rather than anticipated. Nothing about the reasoning was wrong; the
circumstance it was conditioned on changed.

**The mechanics, checked against the plugin documentation rather than
assumed** — because the premise this change was requested under is partly
inverted, and recording an inverted premise as rationale would install a
false belief in the log that later work would reason from. Claude Code
resolves a plugin's version from the first of: `plugin.json`'s `version`,
the marketplace entry's `version`, then **the git commit SHA of the plugin's
source** — which covers devseed, whose marketplace entry uses a relative-path
source in a git-hosted marketplace. From there:

| | Update behaviour | Documented as best for |
|---|---|---|
| **Omit `version`** (state before this ADR) | users get updates whenever the source's resolved commit changes | internal/team plugins under active development |
| **Set `version`** (this ADR) | users get updates **only when the field is bumped**; pushing commits without bumping has no effect and `/plugin update` reports "already at the latest version" | published plugins with stable release cycles |

So the widely-held reading in this repository — that omitting `version` is
what makes an install "go stale silently", and that declaring one fixes it —
is backwards about the fix. Under SHA versioning a user who runs
`/plugin update` converges on the current commit. Under an explicit version,
a user who runs `/plugin update` gets **nothing** until the maintainer bumps
the field. What the repository actually observed (ADR-0011: an install pinned
eleven commits behind, `gates/` empty) is real, but its cause is that nobody
ran the update — third-party marketplaces have auto-update **off** by
default — not that the SHA scheme freezes anything permanently.

The change is still right, for the reason ADR-0001 named rather than the one
in circulation: a published tool needs a version that is a **claim**, not a
moving target. "0.1.0" names what a given install contains, survives a force-
push, gives release notes and a tag something to hang off, and lets someone
else say which devseed they are running. Auto-tracking `main` is the correct
default for a solo tool and the wrong one for a shared one — a colleague
whose gate silently changes behaviour mid-week has no way to attribute the
change.

**Alternatives considered:**

- **Keep omitting `version`.** Rejected: it optimizes for the author, who
  can read git log, at the expense of every other installer, who cannot
  distinguish "the plugin changed" from "my project changed".
- **Put the version in the marketplace entry instead** of `plugin.json`.
  Rejected: `plugin.json` wins where both are set, so the marketplace entry
  would be a second copy with no maintainer — the failure mode
  [`ledger.md`](.claude/rules/ledger.md) exists to prevent, in a manifest.
- **Start at `1.0.0`.** Rejected: `0.x` communicates that the interface may
  still move, which is true — the consumer half of SG-0003 is open and
  `templates/gate.sh` is still a placeholder.
- **Adopt an explicit version *and* keep publishing from `main`.** Not
  rejected so much as named as the residual duty: see the first consequence.

### Decision

`plugins/governed-dev/.claude-plugin/plugin.json` declares
`"version": "0.1.0"`. The marketplace entry stays versionless so there is one
copy of the fact. ADR-0001 is superseded **only** on the version-omission
paragraph; its plugin/governance split, directory layout, and the reasoning
behind them are untouched and remain in force.

This is a distribution decision, not a constraint change. `DESIGN.md` states
no rule about the manifest's version field, and no gate check reads it —
verified by grep across `gates/`, `hooks/` and `scripts/` — so §6's
amendment procedure does not apply and no ratchet is engaged. The prose
passages in `README.md`, `CLAUDE.md` and `.claude/settings.json` that
describe the omission as deliberate become false on this commit and are
corrected in the same commit, per §5's rule that prose catches up to reality.

### Consequences

- **A duty is created that did not exist before: an unbumped commit reaches
  nobody.** Every release now requires bumping the field, and forgetting is
  silent in the direction that matters — users stay on 0.1.0 indefinitely
  while `main` moves. This is strictly more maintainer obligation than the
  scheme it replaces, and it is the price of a version that means something.
- The three mirrors (ADR-0011, ADR-0014, ADR-0016) become **more** necessary,
  not less: the installed copy now moves only on version bumps, so devseed
  dogfooding through the installed plugin would be staler than before. Their
  rationale is unchanged and their retirement condition (ADR-0016: a CLI
  release that makes an install track a working tree) is unaffected.
- `claude plugin validate --strict` **has not been run.** The `claude` CLI is
  not installed on the machine this change was made on, so the claim that
  `--strict` becomes usable once a version is declared is *unverified* and is
  recorded as such rather than asserted. `CLAUDE.md` says so; T-035 carries
  the verification as an open follow-up. A claim about a check that nobody
  ran is exactly what check 5 exists to reject in the ledger, and it does not
  become acceptable in prose.
- No `CHANGELOG.md` yet. The documentation recommends one alongside explicit
  versions; it is deliberately not created here, since an empty changelog is
  a maintenance obligation with no content. It becomes worth adding at the
  first bump — the first moment it would have something to say.

---

## ADR-0027 — Complexity audit before 0.1

- **Date:** 2026-08-11
- **Status:** Accepted as a record. **Superseded in part by [ADR-0028]** —
  the line below reading "Nothing is removed by this entry" was accurate when
  written and is no longer the state of the repository: the human decided all
  three removals the same day, and ADR-0028 records them. Left standing rather
  than edited, per this file's append-only convention.
- **Correction (ADR-0028):** this entry's claim that the TMPDIR incident has
  no evidence in the record is **wrong**. The incident is real — dangling
  commit `8782c53` truncated all three ledgers and was recovered by a hard
  reset to `f1ad979`. The check behind the claim searched committed history
  and the working tree but not the reflog, and stated a conclusion wider than
  it had tested. ADR-0028 carries the evidence.

### Context

The complement of T-028/ADR-0023. That audit asked *which rules lack checks*
and found enforcement **gaps**. This one asks *which checks lack
justification* and looks for enforcement **excess**. Where the two overlap —
the reviewer/auditor `Bash` tension — this audit cites ADR-0024 and does not
re-open it.

Every mechanism was scored on three questions answered from the record
(`TASKS.md`, `DECISIONS.md`, the regression suites, `git log`, and the GitHub
Actions API), not from memory:

1. **What real, actually-occurred failure does it exist to catch?** No
   citation means speculative, which by this project's own rule is an
   unsanctioned constraint wearing a different hat.
2. **Has it fired correctly in actual work** — not in its own regression
   suite? Never-fired is not disqualifying; it is recorded.
3. **What is its false-positive surface** — how plausibly does it block a
   *correct* change? A gate that cries wolf gets bypassed, and a bypassed
   gate is worse than none, because it still looks like enforcement.

**Two of the three premises motivating this audit did not survive the
record, and are corrected here rather than repeated:**

- **"drift.sh produced the repository's only production bug (the mawk
  regression)."** It did not. Per ADR-0025, verified this session, the
  interval-regex defect in `drift.sh` was **latent and never fired** — the
  awks on all three runner images support intervals, and `gate.sh` stops at
  the first failing check, so `drift.sh` never even ran during the red CI
  run. What actually bricked CI was `gate.yml`'s default depth-1 checkout.
  The repository's real defect history sits elsewhere: the Windows
  drive-letter path mismatch that silently disarmed the implementer
  boundary, `grep -c` returning `"00"` and silently disabling a
  disagreement check, exec form meaning no hook ran at all (all T-005),
  four dangling devseed ids in the shipped templates and an invisible CRLF
  drift in `auditor.md` (T-008, SG-0009), and the four T-012..T-015
  defects. `drift.sh` is nonetheless the largest single component at 672
  lines, which is the premise's true half and reason enough to audit it
  sub-check by sub-check.
- **"This session's TMPDIR incident — a hand-rolled scratch probe
  truncating the real ledgers."** **No such incident is in the record.** No
  commit in this repository's history has ever deleted more than fifty
  lines from `DECISIONS.md`, `TASKS.md` or `CLAUDE.md`; both ledgers grew
  monotonically across this session (`TASKS.md` 664 → 749,
  `DECISIONS.md` 1,907 → 2,129); and the string `TMPDIR` appears in no
  document. This session ran the three sanctioned suites, the gate,
  `drift.sh` and `orient.sh`, and nothing else that writes. A finding built
  on it would fail §6's own evidence bar, which demands a named commit,
  task or session — so no finding is built on it. If it happened in a
  session outside this record, it needs recording before it can be cited.
- **"DECISIONS.md is 1,907 lines, +23% over two sessions."** Directionally
  right, one session stale, and worse than stated: it is now **2,129**.
  Note the authorship — 222 of those lines are ADR-0025 and ADR-0026, both
  written by this session. The trend this audit exists to arrest includes
  the audit's own recent output, and this entry adds to it again.

### The inventory

**Legend.** *Cited* = a real failure in the record that the mechanism exists
to catch. *Fired* = has done its job in actual work, outside its own suite.

**Gate checks 1–7**

| # | Cited incident | Fired for real | False-positive surface | Verdict |
|---|---|---|---|---|
| 1 build | none specific; §5's contract | never (devseed declares no build) | missing toolchain fails a correct change, by design | keep |
| 2 tests | none specific | never here; exercised only in scratch projects | same | keep |
| 3 lint | none specific | never here | same | keep |
| 4 working memory | ADR-0005/T-012 (its own bug, not a catch) | **never — devseed has no `src/` at all**, so it is structurally inert here | keys on `src/` only; forces a CLAUDE.md edit for any `src/` change including pure refactors | keep, never-fired |
| 5 task ledger | **T-015** — a fabricated well-formed hash passed the old format-only check | **yes** — and it is the one check with a *demonstrated* false positive: the red CI run (ADR-0025), where a correct ledger failed on all three legs because the clone was shallow | highest, now fixed at source (`fetch-depth: 0`) | keep |
| 6 spec gaps | the ambiguity rule | **never.** The whole repository contains exactly **one** live `TODO(spec)` marker (`boundary.sh`, SG-0005), and the one real marker-staleness incident (SG-0010) was in a `.md` file, which this check skips by design | negligible | keep, thinnest coverage in the system |
| 7 drift | composite — audited separately below | — | — | — |

**drift.sh, sub-check by sub-check** (672 lines total; sub-checks are not
grandfathered by the script containing them)

| Sub-check | Cited incident | Fired for real | FP surface | Verdict |
|---|---|---|---|---|
| duplication (≥12-word run) | **none.** ADR-0012 argues it from design, not from an incident; no T-012..T-015 defect was a copied-text defect | **never** | **high** — ~90 lines of awk, the largest sub-check; measures copying, not agreement (Known limit), so a legitimate long quotation trips it | **remove** |
| staleness, forward (named paths exist) | T-006's explicit criterion; CLAUDE.md describing files that no longer exist | plausibly (auditor caught CLAUDE.md staleness during T-007) | low — gitignored paths already exempted after a real FP | keep |
| staleness, reverse (dirs on disk are named) | none cited | never | moderate — any new top-level directory blocks until CLAUDE.md is edited | keep |
| budget (≤300, warn 250) | CLAUDE.md's own budget rule | **yes, currently firing** — `CLAUDE.md:257` warns on every run today | very low | keep |
| orphans, ADR/SG ids | **T-008** — four dangling devseed ids in the shipped templates, found before release | **yes** | moderate — every id in prose must resolve; `gate-regression.sh` assembles fixture ids at runtime specifically to dodge it, which is evidence of the pressure | keep |
| orphans, done-task hashes | ADR-0025 (the copies drifted) | duplicate of check 5 | same as check 5 | keep-but-simplify |
| superseded, ADR contiguity | none cited | never | low | keep |
| superseded, git-history deletion walk | **none** — no ADR has ever been deleted | **never** | moderate, and it *degrades silently*: it runs `git show <rev>:DECISIONS.md` once per revision, so cost grows with history, and in a shallow clone it passes while proving nothing | **keep-but-simplify** (drop the walk, keep contiguity) |
| hook parity (jq) | ADR-0011 — the mirror is real and its drift is invisible | never | moderate — requires `jq`; a missing `jq` fails a correct change | keep |
| agent + skill byte-parity | **SG-0009** — CRLF drift in `auditor.md` during T-008 | found by the reviewer, not by the check | **demonstrated FP mechanism**: a plain `git checkout` of a mirrored `.md` on Windows rewrites it CRLF and fails the gate while `git status` shows the tree clean. SG-0009 is still open | keep |

**Hooks, boundary, breaker, CI**

| Mechanism | Cited | Fired for real | FP surface | Verdict |
|---|---|---|---|---|
| `preflight` (Setup) | ADR-0019, T-025 | yes — installs `jq` on the ubuntu leg every run | low | keep |
| `orient` (SessionStart) | its own `grep -c` defect (T-005) | yes, every session | none — cannot block | keep |
| `boundary` (PreToolUse), path half | ADR-0007 | **yes** — blocked a real `Edit` the moment `.claude/settings.json` landed (ADR-0010) | moderate | keep |
| `boundary`, **shell-command inspection** | ADR-0013 — `tools:` cannot express "may not write this file" | **never recorded**; the one live block was an `Edit`, not a command | **high** — syntactic matching over arbitrary shell inside a 315-line script, already needing a `templates/` special-case to avoid false hits | keep, top FP risk |
| `fast-gate` (PostToolUse) | none cited | unrecorded | low — `asyncRewake`, does not block the turn | keep |
| `stop-gate` (Stop) | the load-bearing mechanism | yes, routinely | inherits every check's FP | keep |
| circuit breaker (3 blocks, then release) | ADR-0008 — today's API has no `stop_hook_active`, so an unfixable failure loops forever | never recorded | **inverted** — it exists to stop a wedged session, i.e. to prevent the bypass this audit fears | keep |
| `flush` (PreCompact) | ADR-0009 | unrecorded | none — cannot block | keep |
| `activity` (SessionEnd, SubagentStop) | ADR-0003 | yes, appends | none | keep |
| **`audit.yml`** | T-026 / ADR-0021 | **never — verified against the API: five workflow runs exist in this repository's entire history, all of them `gate`.** It cannot run: no `ANTHROPIC_API_KEY` secret, and ADR-0021 stands at *Proposed — unverified in three specific ways* | n/a — it never executes | **remove** |

### The mirrors, justified from scratch

Three mirrors exist (`.claude/agents/`, `.claude/skills/`, and the hook
wiring in `.claude/settings.json`) because an installed plugin is a copy that
does not track the working tree (ADR-0011, ADR-0014, ADR-0016). The audit
asked whether v0.1.0 and a green matrix retire that reason. They do not — and
the honest answer runs opposite to the question's expectation:

- **Declaring a version made the case stronger, not weaker.** Per ADR-0026,
  verified against the documentation, an install now moves **only when the
  version field is bumped**; before, the version was the commit SHA and an
  install moved whenever `/plugin update` was run. Dogfooding through the
  installed copy is therefore *more* stale after v0.1.0, not less.
- **The green matrix is orthogonal.** CI checks out the working tree and runs
  `gate.sh` from it. It exercises no install at all, so it says nothing about
  whether an installed copy matches this repository.
- ADR-0016's stated retirement condition — a CLI release that makes an
  install track a working tree — has not occurred.

The mirrors survive on a current reason. Their parity checks survive with
them, with the caveat ranked below.

### False-positive ranking

Most plausible blocker of a **correct** change, first:

1. **check 5 / drift's hash re-check** — the only *demonstrated* false
   positive in the repository's history: it failed a correct ledger on all
   three legs (ADR-0025). Root cause fixed; the mechanism was right.
2. **agent/skill byte-parity** — a documented FP *mechanism* that has already
   occurred once: `git checkout` on Windows silently produces CRLF and fails
   the gate against a clean-looking tree (SG-0009, open).
3. **drift duplication** — ~90 lines of awk that cannot distinguish a
   copied rule from a legitimate quotation, protecting against an incident
   that has never happened.
4. **boundary shell inspection** — syntactic matching over arbitrary shell;
   its `templates/` special-case is evidence the surface is real.
5. **superseded git-history walk** — no FP, but silent degradation in a
   shallow clone, which is the CI case.
6. **checks 1–3** — "a missing runner is a failed check" blocks a correct
   change on any machine lacking the toolchain. Deliberate (§5), and the
   most likely source of a consumer's first bad experience.
7. **staleness reverse** and **hook parity (needs jq)** — minor.

### Decision

Recorded as an inventory; the verdicts above stand as this audit's
recommendation. **Nothing is removed by this entry.** Three removals go to
the human, listed in the session summary with one-line reasons: `audit.yml`
(never ran, cannot run, looks like enforcement), drift's duplication
sub-check (no incident, never fired, highest latent FP), and drift's
git-history deletion walk (no incident, never fired, silently inert where it
matters most). Removing either drift sub-check changes §5's documented check
table and therefore requires `/amend` under §6 after approval; `audit.yml` is
not a §5 constraint and needs only approval.

Per this audit's own hard rule, **no new mechanism, check, or file was
created to resolve any finding here** — every finding resolves by deletion,
simplification, or an entry in §5's Known limits.

### Consequences

- Three mechanisms are now on record as **never having fired in real work**
  (check 4, check 6, and every drift sub-check except budget and ADR/SG
  orphans). That is not an argument for removing them — a boundary that has
  never been tested is not thereby useless — but it is the honest baseline
  for the next audit, which should ask whether the number moved.
- **This entry is itself 190 lines of the growth it measures.** The audit
  cannot resolve that; it can only decline to hide it. If the next audit
  finds DECISIONS.md past 2,500 lines, the mechanism to question is the ADR
  format itself, not any check in the inventory.
- The one *demonstrated* false positive and the one *demonstrated* FP
  mechanism (ranks 1 and 2) both come from mechanisms this audit keeps. The
  removal candidates are, in every case, mechanisms that have never fired at
  all — which is the correct shape for a subtraction audit and worth stating,
  because the temptation is to cut what recently hurt.

---

## ADR-0028 — Three removals from the subtraction audit; and the TMPDIR incident, corrected

- **Date:** 2026-08-11
- **Status:** Accepted — human decision, given explicitly and marked final in
  the session of 2026-08-11 ("All three removals: REMOVE… Answers are final —
  implement them, don't re-litigate"), with per-item reasoning quoted below.
  Note on §6 step 2: the human approved the *decisions and their reasons*
  before this ADR existed, and forbade a further round trip. This entry
  records what was approved rather than seeking approval of itself.

### Context

ADR-0027 inventoried every enforcement mechanism and sent three to the human.
All three come back **remove**. This entry records what was removed, what each
was watching for, and what is now unguarded.

**On the evidence bar.** §6 demands "the specific incident that showed it
wrong… the rule *failed to catch what it existed to catch*, or *caught things
it should not have*." Two of these removals rest on an **absence** of
incidents, which that clause does not cover. They are sanctioned by a
different clause of the same section — §6's quarterly self-audit, which names
as its own question:

> **rules that have never fired**. A rule that never fires is either perfect
> or dead, and the audit's job is to determine which: a perfect rule's failure
> mode is found in the activity log as attempts it deflected; a dead rule
> deflects nothing because nothing reaches it, and a dead rule kept on the
> books teaches readers that rules here are decorative.

T-038/ADR-0027 is that audit, run early. It found no deflections for either
mechanism, so §6's own test returns *dead* rather than *perfect*. Recorded
because the route matters: these are not amendments made in spite of the
evidence bar, they are the subtraction §6 already provides for.

### What was removed, and what each was watching for

**1. `check_duplication` — drift.sh's duplication sub-check (~90 lines).**

It watched for `CLAUDE.md` copying a run of **12 or more contiguous words**
(`DRIFT_WINDOW`, default 12) out of any `DESIGN.md` section whose heading
names rules, conventions, constraints, a contract or standards. It normalised
both files first — Markdown links reduced to their label text, everything
non-alphanumeric folded to a separator, so smart quotes, em dashes, backticks
and list bullets could not disguise a copy — indexed the spec's token stream,
tested each window against a flattened `CLAUDE.md`, coalesced overlapping hits
into the largest contiguous span, and reported the `CLAUDE.md` line number
alongside the copied run. Its rationale (ADR-0012): a summary should reference
a rule, not restate it, because copied text is text that will silently diverge
from its source with no maintainer.

Removed because it never fired in real work across 27 ADRs, no incident in
the record is a copied-text defect, it is the largest single sub-check in the
largest component, and — by its own Known limit — it measured *copying*
rather than *agreement*, so a summary that was simply wrong always passed it.

**2. The deletion walk in `check_superseded`.**

It watched for an ADR or spec gap being deleted from `DECISIONS.md` rather
than marked superseded. Since a deleted entry leaves no trace in the file it
was deleted from, git history was the only witness: the walk read every
revision of `DECISIONS.md`, collected every `ADR-NNNN`/`SG-NNNN` heading that
ever existed, and required each to still be present.

Removed for the reason the human made decisive: **it is silently inert in a
shallow clone.** `actions/checkout` defaults to `fetch-depth: 1`, so in any
consumer CI using defaults the walk sees one revision, finds nothing to
compare, and passes — reading as coverage while providing none. This
repository's own CI ran that way until `8cd379f` (ADR-0025), and every
consumer inherits the default. Cost also grows with history: one
`git show <rev>:DECISIONS.md` per revision of the file.

**ADR-number contiguity is kept.** It retains the real protection — an ADR
number cannot silently vanish — at a fraction of the cost and with no
dependence on clone depth.

**3. `.github/workflows/audit.yml`.**

Removed. Verified against the GitHub API: six workflow runs exist in this
repository's entire history and all six are `gate`. It has never executed and
cannot, lacking an `ANTHROPIC_API_KEY` secret, and ADR-0021 still stands at
*Proposed — unverified in three specific ways*. A scheduled auditor that
cannot run is the failure this audit exists to find: it reads as continuous
verification and performs none. T-026 is reopened as unbuilt rather than
left looking done.

### The TMPDIR incident — correcting ADR-0027

**ADR-0027 states "No such incident is in the record." That is wrong, and
this entry corrects it.** The incident is real. Evidence, from the reflog and
a dangling object:

- Dangling commit `8782c53`, parent `f1ad979`, author `r <r@l>`, dated
  2026-08-11 13:46:00 −0400, subject `init`.
- Its diff: `CLAUDE.md` −251, `DECISIONS.md` −1856, `TASKS.md` −571 — 3
  insertions against 2,675 deletions. The three ledgers were replaced with
  `# CLAUDE.md`, `# TASKS.md`, and a three-line `# DECISIONS.md` carrying only
  a `## Spec gaps observed` heading: the exact fixture content
  `gate-regression.sh`'s `scaffold()` writes.
- Reflog: `f1ad979 HEAD@{2026-08-11 14:00:46}: reset: moving to f1ad979` —
  recovery by hard reset, fifteen minutes later, precisely as reported.
- `git branch -r --contains 8782c53` is empty: it never reached the remote.
  `DESIGN.md` and the rest of the tree were untouched.

The author signature is the tell. `gate-regression.sh` commits as
`regression <regression@local>` and `bootstrap-regression.sh` as `b <b@b>`;
**`r <r@l>` belongs to no sanctioned suite.** So the mechanism was an
improvised probe reproducing the scaffold's fixture strings while running in
the repository root instead of a scratch directory — which is exactly the
"improvised outside the sanctioned suites" characterisation, now evidenced.

**Why the earlier check missed it.** It searched the committed history of the
ledger files and the working tree. The truncation never entered committed
history *because it was reset away*; it survived only in the reflog and as a
dangling object, neither of which was examined. The conclusion drawn —
"no such incident is in the record" — was broader than the evidence
supported, and it was stated as settled fact rather than as the narrower
"nothing in main's committed history shows this."

That error is the same failure it was describing, one turn later and pointing
the other way: a self-report about the repository's correctness, asserted
without checking the part of the repository that would have falsified it. It
propagated no further only because the human asked for the reflog.

### Decision

`DESIGN.md` §5 changes, as exact replacement text.

Check-table row 7 — **before**:

> `CLAUDE.md` copies a run of a rules section, names a path that is gone,
> omits a directory that exists, or breaks its line budget; a cited
> `ADR-NNNN`/`SG-NNNN` has no entry; an ADR was deleted or its numbering has
> a hole; a done task's hash fails to resolve (re-checked here so standalone
> CI runs catch it); a mirrored hook wiring, agent, or skill differs from its
> shipped copy

**after**:

> `CLAUDE.md` names a path that is gone, omits a directory that exists, or
> breaks its line budget; a cited `ADR-NNNN`/`SG-NNNN` has no entry; ADR
> numbering has a hole; a done task's hash fails to resolve (re-checked here
> so standalone CI runs catch it); a mirrored hook wiring, agent, or skill
> differs from its shipped copy

Two supporting passages are deleted with the mechanisms they describe: the
"Conventions the gate depends on" bullet explaining that check 7 finds rules
sections by title, and the Known limit "Check 7 measures copying, not
agreement."

**Routes used, per §6's distinction.** The row-7 edit and those two deletions
are a **loosening** and went through `/amend` citing this ADR. The Known-limits
additions below are **corrections** — they document existing reality and
change no constraint — and went through the correction path.

### Consequences

- **Nothing now prevents `CLAUDE.md` from copying `DESIGN.md`'s rules text
  verbatim.** The divergence mechanism ADR-0012 identified is real and is now
  unguarded; only review catches it. Recorded in §5's Known limits.
- **ADR deletion is guarded only by contiguity.** Deleting `ADR-0019` is
  caught; deleting the highest-numbered ADR, or deleting one and renumbering
  the rest, is not. That is a narrower guarantee than the walk gave in a full
  clone, and a wider one than it gave in a shallow one.
- **T-026 is unbuilt again.** Headless verification is a real want; what
  existed was a file, not a capability.
- `drift.sh` drops from 672 lines to 555. Set against this entry's own cost
  in `DECISIONS.md`, the subtraction is a net loss of lines in scripts and a
  net gain in the ledger — which is the ledger-migration task's argument,
  not a counter-argument to removal.

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

### SG-0003 — Whether consumer projects vendor their own `gate.sh` *(bootstrap and devseed's own CI both settled; consumer CI still open)*

- **Date:** 2026-07-31 (narrowed 2026-08-06, CI half narrowed 2026-08-11)
- **Status:** Open, narrowed further — bootstrap half and devseed's own CI
  settled; whether a *consumer* project's CI needs a vendored copy is still
  open

**Update, 2026-08-11 (T-009/Prompt 8).** Devseed's own CI does not need
`${CLAUDE_PLUGIN_ROOT}` at all: `.github/workflows/gate.yml` checks out
devseed itself — the plugin's source — and calls `plugins/governed-dev/gates/
gate.sh` by its repo-relative path, the same way `hook_gate()` prefers the
sibling path over the env var (`hooks/lib.sh`). Neither vendoring nor
installing the plugin is needed here. This settles the question **for
devseed's own CI only**. A consumer project's CI is a different situation —
the plugin genuinely is not checked out there — and this task never exercises
that case, so the general question stands.

**Update, 2026-08-06.** The bootstrap half is settled: bootstrap copies
`templates/gate.sh` verbatim as a documented no-op and does not vendor a
working gate. The CI half — whether CI needs a vendored copy, since
`${CLAUDE_PLUGIN_ROOT}` does not resolve outside a session — remains open and
is T-009/Prompt 8's question.

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

### SG-0004 — T-006 and T-009 criteria were reconstructed, not transcribed *(both halves resolved)*

- **Date:** 2026-07-31
- **Status:** **Closed** — T-006 half closed 2026-08-05; T-009 half closed
  2026-08-11, the real Prompt 8 arrived and TASKS.md was rewritten against it.

**Outcome for T-009.** The reconstruction's guess — "the no-side-effects rule
and the unresolved `${CLAUDE_PLUGIN_ROOT}` question" — covered only the first
of Prompt 8's five deliverables (the CI workflow itself, T-009). The other
four were invisible to a title-only guess: the `Setup` hook gaining install
behaviour (T-025), a scheduled headless auditor run (T-026), the commit
provenance trailer (T-027, closing SG-0010), and a `DESIGN.md` §5 subsection.
TASKS.md is rewritten to carry all five; nothing here was dropped on review
the way T-006's invented criterion was — the reconstruction was simply
incomplete, not wrong where it went.

**Outcome for T-006.** The reconstruction was *partly* wrong, which is the
result this entry existed to make visible. Three criteria the source specifies
were absent from it — the `CLAUDE.md` line budget, orphaned `ADR`/`SG` id
references, and append-only integrity against git history. One criterion the
reconstruction invented was absent from the source: "a `DESIGN.md` claim with no
implementation behind it," generalised from the §3 platform defect (ADR-0006).

That invented criterion was **dropped**, on the human's decision, and the
narrowing is recorded here rather than left implicit. It is not obviously
mechanizable — prose claims do not map onto filesystem facts the way a structure
block does — but it was never rejected on merit, and if the class matters it
needs its own task rather than a quiet reappearance inside T-006's.

The "Also required (added by T-005)" clause — hook wiring parity between
`hooks.json` and `.claude/settings.json` — was **kept**. It came from observed
fact rather than reconstruction, and is check 7's sixth drift class.

**What this cost:** nothing this time, because the entry was read before the
work started and the criteria were checked against the source, which is exactly
the sequence it prescribed. Had it not been, T-006 would have shipped three
checks short and one check wide, with the ledger claiming criteria were written
before the work began.

---

*Original entry follows, unedited.*

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

### SG-0007 — The shipped agents cite rule files that do not ship *(resolved in ADR-0017)*

- **Date:** 2026-08-05
- **Status:** Resolved — ADR-0017 chose "ship the rules". They now ship at
  `plugins/governed-dev/templates/rules/` and the bootstrap skill installs
  them into a consumer's `.claude/rules/`, so the citations resolve.

The five agents under `plugins/governed-dev/agents/` ship to consumer projects.
Their system prompts cite `.claude/rules/ambiguity.md`, `.claude/rules/precedence.md`
and `.claude/rules/delegation.md` by path. Those files **do not ship** —
`CLAUDE.md` records that `.claude/rules/` governs devseed and is deliberately
excluded from the plugin, and the path rule keeps `delegation.md` at the repo
root alongside them.

So in a consumer project the agents will reference documents that are not there.
The instructions still read as sensible prose, which is the problem: nothing
fails, and the reader is pointed at a file they cannot open.

`ledger.md` already noticed the general form of this — "Whether a ledger rule
should ship to consumers is undecided — it is not a gap this rule may close on
its own" — but T-007 is the first work that makes it bite, because the agents
are the first shipped artifact that cites the rules.

**Assumed:** `delegation.md` goes to `.claude/rules/` as the prompt specifies
and the path rule requires, and the dangling references ship with it. Chosen
over the alternatives because both of those close the gap by fiat: copying the
rules into `templates/` decides that rules ship, and rewriting the agent prompts
to drop the citations decides that they do not. Either may be right; neither is
this task's to settle.

**Depends on this:** whether the shipped roster is usable as delivered. Three
options, all real:

- Ship the rules — copy `ambiguity.md`, `precedence.md` and `delegation.md` into
  `plugins/governed-dev/templates/rules/`, and have the bootstrap skill (T-008)
  install them. Makes the citations resolve; grows what a consumer must adopt.
- Inline the substance into each agent's prompt and drop the citations. Makes
  the agents self-contained; duplicates text that will drift, which is exactly
  what drift check 1 exists to catch.
- Ship the roster knowing the references dangle, and say so in the plugin README.

T-008 (bootstrap) forces the answer, since it decides what a consumer receives.

### SG-0008 — Whether `plugins/governed-dev/templates/` should ship a `.gitattributes` *(resolved)*

- **Date:** 2026-08-05
- **Status:** Resolved — the shipped `templates/.gitattributes` carries
  `*.sh text eol=lf`, seeded by bootstrap.

ADR-0015 added root `.gitattributes` normalizing `*.sh` to LF, scoped to
devseed's own repository under DESIGN.md §4's "whatever it takes to copy this
scaffold into a new repo and have it work." `plugins/governed-dev/templates/`
already ships `.gitignore` for the equivalent repo-hygiene reason (ADR-0005),
but ships no `.gitattributes`. The bootstrap skill (T-008) seeds a consumer
project from `templates/`, including `gate.sh`. A consumer bootstrapping on
Windows with `core.autocrlf=true` commits `gate.sh` at LF; their next checkout
lands it CRLF with nothing to stop it — the same defect ADR-0015 closed in
devseed, reproduced one repository over.

This was deliberately not fixed alongside ADR-0015: spec-guardian's sanction
covered devseed's own root, and extending a normalization policy to what ships
to every consumer is a separate decision that was never asked.

**Assumed:** nothing. Left unresolved rather than either adding
`templates/.gitattributes` (which decides consumers get it) or declaring the
gap out of scope (which decides they don't).

**Depends on this:** T-008 (bootstrap) needs to know whether to copy a
`.gitattributes` into the target project. It also interacts with **SG-0003** —
whether consumers vendor their own `gate.sh` at all — since if they do not,
the same CRLF-on-checkout question may not arise the same way.

### SG-0009 — Mirrored `.md` files have no line-ending protection, and byte-equality parity is fragile under `core.autocrlf=true`

- **Date:** 2026-08-06
- **Status:** Open — needs human decision

`.gitattributes` scopes `text eol=lf` to `*.sh` only (that was the sanction
ADR-0015 was granted). The agent and skill mirrors are compared with `cmp`,
so a `git checkout` of a mirrored `.md` on Windows rewrites it CRLF and fails
the gate while `git status` and `git diff` both show the tree clean. This
happened during T-008: `plugins/governed-dev/agents/auditor.md` was restored
by `git checkout` and silently became CRLF. It was fixed by normalising the
file.

**Assumed:** nothing — extending `.gitattributes` to `*.md` was not
sanctioned and is not closed here.

**Depends on this:** whether the mirror parity checks are reliable on Windows
at all.

### SG-0010 — The commit trailer was specified as "per Prompt 8 §4", which does not exist

- **Date:** 2026-08-06
- **Status:** **Closed** 2026-08-11 (T-027) — Prompt 8 arrived and specified
  the trailer directly: agent type, session id, task id, model.

**Outcome.** `/task`'s commit step (`task/SKILL.md`, both copies) now appends
`Agent-Type`, `Session-Id`, `Task-Id`, `Model` alongside the existing
`Co-Authored-By` line, rather than the "read `git log` and match it"
placeholder this entry recorded. See ADR-0022 for why `Agent-Type` is always
`main`. Every commit `/task` made **before** this — everything up to and
including `eb489bd` — used the placeholder convention (`Co-Authored-By` only)
and is not retroactively relabeled; the assumption below was live and correct
for its time.

**Assumed (original, kept for the record):** `/task` instructs reading `git
log` and matching the convention the repository already uses, rather than
inventing a format Prompt 8 would then have to match. Recorded at the point
of contact in `plugins/governed-dev/skills/task/SKILL.md`.

**Depended on this:** if Prompt 8 §4 specified a different trailer, every
commit `/task` made before then used the wrong one. It did — the real Prompt 8
adds three fields the placeholder never had — but "wrong" here means
"superseded," not "in violation of a spec that existed at the time." Note the
marker was in a `.md` file, which gate check 6 skips by design, so the gate
never would have caught it going stale on its own.

### SG-0011 — `templates/rules/` duplicates `.claude/rules/` with no guard

- **Date:** 2026-08-06
- **Status:** Open — needs human decision

ADR-0017 ships four rule files whose consumer-facing copies say the same
thing as devseed's own with ids and paths stripped. The agents and skills
mirrors are guarded by byte equality; these cannot be, because the
difference is deliberate.

**Assumed:** hand-maintenance, with a note in `.claude/rules/ledger.md`
telling an editor to check the shipped copy.

**Depends on this:** an edit to a root rule leaves consumers on the old text
indefinitely with nothing reporting it.
