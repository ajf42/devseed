# ADR-0030 — Autopilot replaces the human transport layer with routing on the gate's verdict

- **Date:** 2026-08-11
- **Status:** Accepted

## Context

Between sessions the human is the transport layer. Work happens in one session,
and an account of it — what got done, what is next, what broke — is
hand-carried into the next one. The repository already holds all of it.

**Twice the carried account disagreed with the repository.** A todo list was
carried forward stale, and a fix was reported done that was not on `main`.
Neither was a lie and neither was caught by anything: DESIGN.md §5's Known
limits already names the seam — *the gate cannot see the conversation about the
repository*, and a session's self-report reaches the human through a channel
with no verification step in it. The TMPDIR incident (ADR-0028) is the same
failure in its most expensive form, where the *correction* to a self-report was
itself an unverified self-report in the other direction.

Transport is the defect. The information does not need carrying; it needs
**routing**. Work that agrees with the spec does not need human attention at
all, and work that disagrees needs nothing else.

**And the router already exists.** The gate is the single definition of
agreement (DESIGN.md §5). Nothing new has to decide what "agrees" means — the
question is only what to *do* with a verdict that already exists.

**Alternatives considered:**

- **A better handoff document.** A structured session summary, richer than
  prose. Rejected: it is transport with better packaging, and both failures
  were well-formed summaries. Nothing in a document format makes a claim about
  the repository true.
- **A second checker that verifies the worker's claims.** Rejected outright,
  and this is the important rejection. It would be a *second opinion on the
  gate*, which means two definitions of done and an inevitable session spent
  deciding which one to believe — the exact failure §5's CI-parity rule exists
  to prevent, reproduced inside the repository.
- **Let the worker decide whether to continue.** Rejected: it asks the agent
  that did the work to rule on whether the work agreed with the spec, which is
  the decides-and-records collapse `delegation.md` is built to prevent, with
  the gate's verdict as the thing being adjusted.
- **Full autonomy — keep going until the queue is empty.** Rejected: an
  unbounded run is unattended spending with no upper bound and no natural point
  at which a human looks. The cap is not a safety valve on a good idea; it is
  what makes the idea reviewable.

## Decision

`scripts/autopilot.sh` runs `/task` headless over the `todo` queue and routes
on the **gate's** verdict. Four routes, in order: agreement continues and lands
one line in a digest; a new `SG` entry, anything `/amend`-shaped, a question
for the human, or any edit to `DESIGN.md` stops the loop as a spec
disagreement; gate exit 2 retries **once** with the gate's findings appended,
then stops; anything else stops. `/autopilot` wraps it.

Six choices inside that are load-bearing:

**1. Autopilot runs the gate itself, after the worker.** It never reads the
worker's account of its own correctness. A driver that believed its worker
would be transport again with one more hop — and the two incidents that
motivated this were exactly that hop, performed by a human. Every routing
clause is evaluated against the repository: the gate's exit code, the SG ids in
`DECISIONS.md`, the commits in `git log`.

**2. "The task's hash recorded" means a commit trailered `Task-Id: T-NNN`,**
or `TASKS.md` marking the task `done` with a hash that resolves. It cannot mean
only the second: `/task` deliberately leaves a task `in-progress`, because a
commit cannot contain its own hash and recording it is the *next* commit's job.
Requiring `done` + hash would mean autopilot could never observe agreement at
all. The trailer (T-027, ADR-0022) is where the repository records a task's
commit before `TASKS.md` catches up, so that is what is read. **No commit
carrying the task is never agreement**, however cleanly the worker reported —
that clause is the direct mechanisation of "a fix reported done that was not on
main."

**3. Autopilot commits its own report, and nothing else.** This narrows a
statement the task skill makes ("the only thing in this system that commits"),
so it is recorded here rather than left to be noticed. `/task` remains the only
thing that commits **work**; autopilot commits exactly one artifact, its own
account of the run, by pathspec so a stop that left the worker's changes in the
tree cannot sweep them into a commit nobody reviewed. The alternative — leaving
the report uncommitted — puts the decision queue in the one place this whole
feature exists to get things out of: an artifact whose existence depends on
someone remembering to carry it.

**4. Being on the default branch is a refusal, not a branch switch.** The
instruction that prompted this feature said "create `autopilot/DATE` if
needed", and the remedy is implemented — behind `--create-branch`. Moving
someone's `HEAD` unasked is improvised state, and the repository has already
paid once for a script improvising against a live tree (ADR-0028). The refusal
names the flag, so the remedy costs one re-run and is a decision someone made.

**5. Detection of "a question for the human" and "`/amend`-shaped" is
heuristic, over the worker's prose, and is the weakest part of the mechanism.**
It is tuned to over-stop. A false stop costs a human a minute of reading; a
false continue costs whatever the next tasks build on an unnoticed spec
question. This is named here rather than presented as detection, because
someone will eventually widen the patterns to reduce noise and should know
which direction the error budget was deliberately spent in.

**6. Reports cite documents and sections, never `ADR-NNNN` ids.** A report is
committed into the repository it describes, and every citation-resolving check
reads every tracked file: an id meaning something in devseed and nothing in the
project being driven would fail that project's own orphan check. Sections and
filenames travel; numbers do not.

### Boundaries, stated as boundaries

Autopilot **never** edits `DESIGN.md`, **never** runs `/amend`, **never**
resolves an `SG` entry, **never** pushes, **never** merges. Disagreement
handling is proposal-only. §6's human-approval requirement is the load-bearing
wall this feature is built *against*, not an obstacle to it: the feature's
entire value is that it makes the wall cheaper to respect, by removing the
attended-supervision cost of the work that never goes near it.

Autopilot **adds no enforcement mechanism and relaxes none.** It is a consumer
of the gate's verdict. If autopilot and the gate ever disagree about a task's
status, the gate is right and that is a bug in autopilot.

Autopilot **does not widen a permission allowlist.** The worker gets exactly
what the interactive `/task` flow grants — no `--dangerously-skip-permissions`,
no `--permission-mode`, no `--allowedTools`. A permission prompt that blocks
headless execution is a finding to report, not a setting to loosen;
`assert_no_widening()` fails the run against the future edit that would do it,
because that edit will look like a convenience when someone makes it.

**Autonomy is bounded by design** — at most three tasks per invocation, a
`--max-turns` bound and a per-task cost ceiling on the worker, a wall clock,
and three strikes per task reusing the Stop hook's circuit-breaker pattern
(ADR-0008) rather than a second implementation of it. The bounds are config
defaults in the script and flags to override, deliberately not a config file: a
new file format nothing else in this repository reads would be invented
structure.

### The digest is the mitigation, and it is not a claim of correctness

The gate's limits are unchanged and are stated in the report's own header:
**structural agreement is not semantic agreement**, and checks 1–3 pass
vacuously where no tooling is declared (ADR-0004, and §5's Known limits). A
digest line means *nothing disagreed*. It does not mean the work is right.

That is precisely why agreed work is still listed. The digest keeps unattended
work **visible without being blocking** — one line, one hash, one cost. Suppress
it and autopilot becomes a machine for making unreviewed commits arrive
silently, which is a worse version of the problem it was built for.

## Consequences

- **A second committer exists**, where before there was exactly one. Narrow —
  one path, `reports/`, pathspec-limited, never on the default branch — but the
  sentence "only `/task` commits" is no longer true unqualified, and anyone
  auditing commit provenance now has two producers to know about. The report
  commits carry `Agent-Type: autopilot` so they are separable in one `git log`
  query.
- **`reports/` is a new top-level directory, and a project that runs autopilot
  must name it in `CLAUDE.md`'s structure block** or the next gate run fails on
  drift check 1. That is the drift guard working, and it is a real setup step
  rather than a free addition. The regression suite's fixture documents it,
  which is how the requirement stays tested rather than remembered.
- **A skill ships whose driver does not** (SG-0012). Drift check 6 compares the
  shipped skills against the mirror in both directions, so a devseed-only skill
  fails the gate; `scripts/` ships nothing. The skill self-disables where the
  script is absent. This is the second instance of the coupling ADR-0029
  recorded, and the first where the missing half is the thing the human
  invoked.
- **`todo` is now load-bearing in a way it was not** (SG-0013). It used to mean
  "someone could pick this up"; it now means "an unattended run may build
  this". `TASKS.md` has no vocabulary for the difference, and T-022 — `todo —
  **optional**, may never be built` — is what a no-argument run picks first
  today.
- **Cost is now spent by a script rather than by a person at a keyboard.** The
  ceiling is checked *after* each attempt, because nothing bounds spend
  mid-turn; a single runaway turn can exceed it before autopilot can react, and
  the ceiling stops the *next* attempt rather than the one that blew it.
  `--max-turns` is the actual in-turn bound and is the one worth tuning.
- **The routing heuristics will produce false stops**, and the report will
  occasionally contain a decision that needed no deciding. Accepted, in that
  direction, per Decision 5.
- **Nothing tests autopilot against a real worker.** `claude` is not installed
  on the machine devseed is developed on, so the suite pins the worker and runs
  the real gate. What is verified is the router; what is not verified is that
  `claude -p "/task T-NNN" --output-format json` behaves as assumed. The first
  real run is the test of that assumption, and it should be given explicit task
  ids and `--max-tasks 1`.
