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

### SG-0002 — Repository visibility contradicts the stated requirement

- **Date:** 2026-07-31
- **Status:** Open — blocked on human action

Acceptance requires a **private** GitHub repository. `github.com/ajf42/devseed`
already existed at the time of this change and is **public** — confirmed by an
unauthenticated API request returning `"private": false`. The `gh` CLI is not
installed on this machine, so visibility could not be changed here.

**Assumed:** the existing repository is the intended one and should be flipped
to private rather than replaced. Not acted on unilaterally, because changing a
repository's visibility is outward-facing and reversing it re-publishes history.

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
