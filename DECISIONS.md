# DECISIONS.md — devseed

<!-- GENERATED FILE. Do not edit above the "Spec gaps observed" heading.
     Regenerate with: bash scripts/rebuild-adr-index.sh
     Each ADR is its own file under docs/adr/; this is only the index.
     Editing a row here changes nothing -- edit the ADR file it points at. -->

Index of architectural decisions for **devseed's own development**. The
entries live in [`docs/adr/`](docs/adr/); retired ones move to
[`docs/adr/archive/`](docs/adr/archive/) and keep resolving forever (ADR-0029).
Numbering is permanent and never reused. The format each entry follows, and the
lifecycle that moves it, are in
[`.claude/rules/ledger.md`](.claude/rules/ledger.md).

This is not the template that ships to consumer projects — that one lives at
[`plugins/governed-dev/templates/DECISIONS.md`](plugins/governed-dev/templates/DECISIONS.md)
and is a skeleton by design.

## Decisions

| id | status | title |
|---|---|---|
| [ADR-0001](docs/adr/0001-split-plugin-content.md) | active | Split plugin content from the repo's own governance |
| [ADR-0002](docs/adr/0002-two-parallel-ledger-sets.md) | active | Ledger documents exist as two parallel sets |
| [ADR-0003](docs/adr/0003-activity-log-committed.md) | active | `.claude/activity.jsonl` is committed, not ignored |
| [ADR-0004](docs/adr/0004-declared-tooling-trigger.md) | active | The gate triggers on declared tooling, not on its absence |
| [ADR-0005](docs/adr/0005-exclude-generated-artifacts.md) | active | The gate excludes generated artifacts unconditionally |
| [ADR-0006](docs/adr/0006-bash-is-the-platform.md) | active | Bash is the gate's platform; Git Bash is a Windows prerequisite |
| [ADR-0007](docs/adr/0007-tool-boundaries-are-mechanism.md) | active | Tool boundaries are mechanism, not speculative agents |
| [ADR-0008](docs/adr/0008-stop-gate-circuit-breaker.md) | active | The Stop gate releases after three consecutive blocks |
| [ADR-0009](docs/adr/0009-compaction-flush-in-flight.md) | active | The compaction flush writes `.claude/in-flight.md`, not `CLAUDE.md` |
| [ADR-0010](docs/adr/0010-hooks-shell-form.md) | active | Hooks are registered in shell form, not exec form |
| [ADR-0011](docs/adr/0011-mirror-hook-wiring.md) | active | devseed mirrors the hook wiring in its own `.claude/settings.json` |
| [ADR-0012](docs/adr/0012-drift-guard-one-script.md) | active | The drift guard measures copying, and is one script, not six checks |
| [ADR-0013](docs/adr/0013-shell-is-a-write-vector.md) | active | The shell is a write vector; the boundary inspects commands, not just paths |
| [ADR-0014](docs/adr/0014-mirror-agent-roster.md) | active | devseed mirrors the agent roster into `.claude/agents/`, and the guard enforces byte equality |
| [ADR-0015](docs/adr/0015-normalize-sh-to-lf.md) | active | Normalize `*.sh` to LF via `.gitattributes`, regardless of local `core.autocrlf` |
| [ADR-0016](docs/adr/0016-local-install-third-mirror.md) | active | Local-path plugin install was tested and does not retire the mirrors; skills are a third, deliberate mirror |
| [ADR-0017](docs/adr/0017-ship-the-rule-files.md) | active | The rule files ship to consumer projects |
| [ADR-0018](docs/adr/0018-defer-amend.md) | active | `/amend` is deferred to Prompt 9 rather than built now |
| [ADR-0019](docs/adr/0019-preflight-installs-under-ci.md) | active | `preflight.sh` installs under CI, still only reports on a |
| [ADR-0020](docs/adr/0020-ci-needs-no-vendored-gate.md) | active | devseed's own CI needs neither a vendored `gate.sh` nor `${CLAUDE_PLUGIN_ROOT}` |
| [ADR-0021](docs/adr/archive/0021-headless-auditor-action.md) | archived | Headless auditor runs via `anthropics/claude-code-action`, prompted rather than flagged into identity |
| [ADR-0022](docs/adr/0022-agent-type-is-main.md) | active | Commit trailer's `Agent-Type` is always `main` |
| [ADR-0023](docs/adr/0023-amendment-procedure-shape.md) | active | §6's shape: tightening fully exempt, `/amend` the chokepoint, bypass as two trailers |
| [ADR-0024](docs/adr/0024-reviewer-auditor-keep-bash.md) | active | reviewer and auditor keep `Bash`; their write-boundary is best-effort by acceptance, not by accident |
| [ADR-0025](docs/adr/0025-shallow-checkout-matrix-red.md) | active | First matrix run red on all three legs: shallow checkout was the cause; the offered awk-dialect diagnosis was a different, latent defect |
| [ADR-0026](docs/adr/0026-declare-plugin-version.md) | active | `plugin.json` declares `version`, superseding ADR-0001 on the distribution question only |
| [ADR-0027](docs/adr/0027-complexity-audit.md) | active | Complexity audit before 0.1 |
| [ADR-0028](docs/adr/0028-three-removals.md) | active | Three removals from the subtraction audit; and the TMPDIR incident, corrected |
| [ADR-0029](docs/adr/0029-one-file-per-adr.md) | active | One file per ADR, with DECISIONS.md generated as the index |
| [ADR-0030](docs/adr/0030-autopilot-routes-not-transports.md) | active | Autopilot replaces the human transport layer with routing on the gate's verdict |
| [ADR-0031](docs/adr/0031-spawn-count-is-the-cost-model.md) | active | Process spawns are the gate's unit of cost; checks are written batch-first |

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

### SG-0012 — The `/autopilot` skill ships; its driver script does not

- **Date:** 2026-08-11
- **Status:** Open — needs human decision

`scripts/autopilot.sh` is devseed's own dev tooling, alongside the three
regression suites, and nothing under `scripts/` ships in the plugin. The
skill that wraps it cannot be devseed-local: drift check 6 compares
`plugins/governed-dev/skills/` against `.claude/skills/` in **both**
directions, so a mirror-only skill fails the gate. The skill therefore ships
while the script it drives does not, and a consumer who installs the plugin
gets `/governed-dev:autopilot` with nothing behind it. DESIGN.md §4 puts
skills in scope "as genuine need appears" and is silent on whether a driver
that spawns headless sessions is a consumer-facing capability at all.

**Assumed:** the skill self-disables — it looks for `scripts/autopilot.sh`,
and where the file is absent it says so and stops, in the same style as
drift's own self-disabling sub-checks. This is the second instance of the
coupling ADR-0029 recorded (the shipped gate calling a script that does not
ship), and the first where the missing half is what the human invoked.

**Depends on this:** if the answer is that consumers should have autopilot,
the script moves into the plugin and `bootstrap` seeds it, which also makes
the `claude` CLI a consumer prerequisite the scaffold currently does not
assume. If the answer is that they should not, the skill should not ship
either, and the parity guard needs a sanctioned way to say "devseed-only" —
which today it has none.

### SG-0013 — `TASKS.md` cannot mark a task ineligible for unattended work

- **Date:** 2026-08-11
- **Status:** Open — needs human decision

Autopilot picks the first task whose status is `todo`, top to bottom. The
status vocabulary is `todo` / `in-progress` / `done` / `blocked` / `dropped`,
and none of it distinguishes *ready to be built by anyone* from *ready, but
this one is a judgement call*. The live instance is **T-022 (ticket sync)**,
whose status reads `todo — **optional**, may never be built (Prompt 7a)`:
its first word is `todo`, so it is what an unattended run picks first, and
"may never be built" is exactly the decision autopilot exists not to make.

**Assumed:** first-`todo` top-to-bottom as specified, with the free-text
qualifier ignored — parsing prose after the status word would invent a
convention the ledger never declared, which is the failure `ambiguity.md`
names. The mitigation is operational, not mechanical: give autopilot explicit
task ids until this is settled.

**Depends on this:** an unattended run started with no arguments today builds
an optional task. If the answer is a new status (`deferred`, or a `todo` that
autopilot skips), `TASKS.md`'s conventions block, the template's, and the
picker in `autopilot.sh` all change together.
