# DESIGN.md — {{PROJECT_NAME}}

> This document is the project constitution. It is authoritative for **what this
> system should be**. `CLAUDE.md` is authoritative for **what currently
> exists**. On a spec question DESIGN.md wins; on a current-state question
> CLAUDE.md wins. If the two describe incompatible systems rather than the same
> system at two points in time, stop and surface it — do not reconcile silently.
>
> Changes to this file go through the amendment procedure in §6. Nothing else.

<!-- SKELETON. Replace the guidance in sections 1-4 with this project's real
     content. Delete the HTML comments as you go. Sections 5 and 6 arrive
     FILLED IN, because they are mechanism rather than opinion — see the notes
     at the top of each. -->

## 1. What this is

<!-- One paragraph, plain language. What the system does and for whom. No
     architecture, no justification. If it cannot be said in a paragraph, the
     scope in §4 is probably wrong. -->

## 2. Problem context and who this is for

<!-- The problem that exists whether or not this system is built, who has it,
     and what they do today instead. Then who this is for — and, as sharply,
     who it is not for. A system with no non-users has no scope.

     Also: what success looks like, stated so it could be observed rather than
     asserted. -->

## 3. Architecture and stack

<!-- A table. The "why" column is the point: it records the reasoning that a
     future reader would otherwise have to reconstruct, and makes it possible
     to tell whether a choice still holds when its context changes. A why that
     reads "industry standard" or "well supported" is not a reason — it is a
     reason to look for the reason. -->

| Choice | What it is | Why |
|---|---|---|
|  |  |  |

## 4. Scope

### In scope

<!-- What this system commits to doing. -->

### Out of scope

<!-- What it will not do, and why not. This section prevents more work than
     §4.1 creates. -->

### Explicitly deferred

<!-- Every deferred item names where it gets treated instead. An item with no
     venue is not deferred — it is out of scope, and belongs in the section
     above. This distinction is the whole value of the section: "later" without
     an address is how work disappears. -->

| Deferred | Treated instead in |
|---|---|
|  |  |

## 5. Build rules

**This section has two halves, and only one of them is yours to write.**

The first half is the **gate's contract**, seeded below rather than left blank.
It is not an opinion about how you should build software: it is the behaviour
the `gate.sh` that ships with this plugin already has, and which the task loop,
the agents and the lifecycle hooks all assume. Left empty, this section would
describe nothing while the gate went on enforcing it — which is exactly the
drift this document exists to prevent. Rewrite it and you take on keeping the
gate and the prose in step by hand.

The second half is **this project's own build rules**, which nothing but this
project can supply. That half is prompted, not filled in.

**The script is the authority.** This section describes what the gate enforces;
it does not define it. Where the prose and the script disagree, the script wins
and the prose gets fixed — a correction, not an amendment, so it does not go
through §6.

### The contract

- **Exit 0 = pass. Exit 2 = fail. Never exit 1.** Claude Code treats exit 1 as
  a non-blocking error and proceeds anyway; only exit 2 blocks. A gate that
  returns 1 is a gate that does nothing.
- **Verification only — no side effects.** The gate never stages, commits,
  pushes, or writes any file. It emits an exit code and stderr. Everything that
  runs it — a hook, a human, a CI job — must get identical behaviour, so
  commit-and-push belongs to the caller, *after* the gate passes.
- **Failure messages are instructions, not complaints.** They name the file and
  what to do about it, because an agent reads and acts on that text.
- **A check that cannot run is a failed check.** If this project declares tests
  and the runner is absent, that is exit 2, not a skip. Silent degradation is
  the failure mode being engineered against.

### CI parity

The gate is the single contract between a local run and a CI run. CI invokes
the same script, never a second implementation of these checks. If local and CI
ever disagree about a change, that disagreement is a defect in the gate, to be
fixed in the gate — not a reason to keep two definitions of "done", or to trust
whichever one currently says pass. The plugin's README shows how to reach the
gate from CI without copying it.

### What it enforces

Checks run cheapest-first; `--fast` runs 1-3 only, for the per-edit hook.

| # | Check | Fails when |
|---|---|---|
| 1 | Code builds | A declared build errors, or its toolchain is missing |
| 2 | Tests pass | A declared or discovered suite fails, or its runner is missing |
| 3 | Lint and format clean | A configured linter or formatter reports problems, or is missing |
| 4 | Working memory current | Files under `src/` changed but `CLAUDE.md` did not |
| 5 | Task ledger honest | A `## T-NNN` task is marked `done` with no commit hash |
| 6 | Spec gaps answered | A spec-gap marker in a changed file cites no `SG-NNNN` id, or cites one absent from `DECISIONS.md` |
| 7 | Documents match the repository | `CLAUDE.md` names a path that is gone or is not committed, omits a directory that exists, or breaks its line budget; a cited decision or spec-gap id has no entry; decision numbering has a hole; a done task's hash fails to resolve |

**Checks 1-3 trigger on *declared* tooling.** A project that declares no build,
tests or linter passes them vacuously and says so on stderr. What they catch is
declared-but-unrunnable, not never-declared — worth knowing before reading a
green gate as coverage.

### Conventions the gate depends on

- A spec-gap marker is written `TODO(spec): SG-NNNN — <what the spec omits>`,
  with a matching entry under "Spec gaps observed" in `DECISIONS.md`. The id is
  the link; without it a marker is untraceable and therefore indistinguishable
  from a decision that was actually made. Check 6 skips `.md` files, so a
  marker parked in prose is not caught.
- A task heading is `## T-NNN`. A commit hash is seven or more hex characters
  in backticks and must **resolve to a commit in this repository** — a
  well-formed but fabricated hash fails, and so does `pending`.
- `CLAUDE.md`'s structure block is an indented tree in a fenced code block,
  under a heading naming *structure*. Indentation picks the parent; the first
  run of two or more spaces ends the path column and begins commentary. A path
  the block names must be **tracked**, not merely present on disk: existence is
  a fact about one machine, and an untracked, un-ignored file passes locally
  while failing in every clone. A `.gitignore`d path is exempt from having to
  exist at all.

### This project's build rules

<!-- Yours to write. What must hold for a change in THIS project to be done,
     beyond the contract above: what the build command is, what the test bar
     is, which linter runs and whether it blocks, and anything else a change
     must satisfy before it counts as finished.

     Anything written here that no check enforces is advice, and advice is
     optional in practice. Prefer a rule the gate can run. Where a rule cannot
     be mechanised, say so explicitly, so nobody mistakes it for coverage. -->

## 6. Amendment procedure

**Seeded, deliberately.** This is the procedure the `/amend` skill executes, in
this order, and it refuses to run it in any other. Left as a comment, this
section would deadlock the project: the header above says changes to this file
go through §6 and nothing else, `/amend` needs a §6 to execute, and writing one
would itself be a change to this file. Hand-writing a replacement produces a
second procedure with no maintainer, diverging from the skill that actually
runs — so it arrives filled in, and a project that rewrites it takes on keeping
`/amend` in step with it.

Any rule in this document may be amended, including this procedure. Nothing
here is sacred. What is forbidden is not change — it is *silent* change: an
edit that alters what is permitted without leaving a record of who decided, on
what evidence, and what the edit gave up.

### Amendment vs. correction

- A **correction** changes no constraint: prose catching up to the script it
  describes (§5's own rule), a typo, a broken link, a renumbered reference.
  Corrections need no decision entry and do not go through this procedure.
- An **amendment** changes what is permitted, required, or forbidden. Every
  amendment goes through the procedure below. When in doubt, it is an
  amendment — misfiling an amendment as a correction is the silent change this
  section exists to prevent, in miniature.
- **Never amend this document to match drifted code.** That inverts the
  direction of authority. An amendment is prompted by evidence a rule is wrong,
  never by the existence of code that violates it.

### The procedure

1. **The decision entry comes first**, recorded in `DECISIONS.md` before the
   edit, naming:
   - **the rule**, quoted as currently written;
   - **the specific incident** that showed it wrong. The bar: the rule *failed
     to catch what it existed to catch*, or *caught things it should not
     have* — with an example of each failure claimed, such as a commit, a task,
     or a session. "It was slowing us down" is not sufficient; every gate slows
     you down, and that is what a gate is;
   - **the replacement**, as exact text;
   - **what the replacement makes harder.** An amendment whose consequences are
     all upside is advocacy, not a record.
2. **A human approves the entry, explicitly**, before anything is edited.
   Agents draft and propose; the human decides.
3. **Then the edit**, citing the entry by its id at the change. `/amend`
   executes this end to end and refuses to run it out of order. It does not
   commit — the task skill owns commits.

### The ratchet

**Tightening a gate needs no decision entry. Loosening one always does.**
Narrowing what passes, adding a check, extending coverage — proceed, and record
it as a correction to §5's table if the table changed. Weakening a check,
widening an exemption, deleting a rule — that is an amendment, evidence bar and
all.

The asymmetry is deliberate. A mistaken tightening announces itself: the gate
blocks something it should not, someone notices within a commit, and the fix
carries its own incident report. A mistaken loosening is silent forever — the
defect it would have caught arrives unannounced, and nothing connects the
arrival to the loosening. Symmetric ceremony would mean either blocking cheap
safety or making dangerous edits cheap.

### Emergency bypass

Bypassing a gate in an emergency is allowed and expected — a gate that cannot
be bypassed under pressure gets deleted under pressure instead. A bypass
carries two obligations:

1. The commit that bypasses names it in trailers:

   ```
   Gate-Bypassed: <check name or number>
   Bypass-Reason: <one line — why waiting was worse>
   ```

2. The same commit, or the next, **opens a task in `TASKS.md`** to either
   restore the gate's authority over what was bypassed, or amend the gate via
   this procedure. One of the two — a bypass is a claim that the gate was wrong
   *here*, and the claim gets tested.

A bypass that is never reconciled is how a governance layer becomes something
everyone routes around.

### The periodic self-audit

<!-- Yours to set: a cadence, and the date of the first run recorded here.

     The audit asks four questions. Which rules in §5 have no check behind
     them; which checks have no rule; whether each agent's tool allowlist
     still matches the boundary the delegation rule states; and — the question
     only time can ask — which rules have never fired. A rule that never fires
     is either perfect or dead, and the audit's job is to determine which. A
     dead rule left on the books teaches every reader that the rules here are
     decorative. -->
