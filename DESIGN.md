# DESIGN.md — devseed

> This document is the project constitution. It is authoritative for **what this
> system should be**. `CLAUDE.md` is authoritative for **what currently exists**.
> See [`.claude/rules/precedence.md`](.claude/rules/precedence.md) for how the two
> interact, and [`.claude/rules/ambiguity.md`](.claude/rules/ambiguity.md) for what
> to do when this document is silent.
>
> Changes to this file go through the amendment procedure in §6. Nothing else.

---

## 1. What this is

devseed is a seed repository: a governance scaffold you copy into a new project
so that the rules of the build exist before the first line of application code
does. It ships a constitution (`DESIGN.md`), a decision log (`DECISIONS.md`), and
a `.claude/` directory of agents, skills, gates, hooks, and rules that constrain
how an AI coding agent is allowed to work in the repo. The premise is that the
expensive failures in agent-assisted development are not bad code — bad code is
cheap to find and cheap to fix — but unsanctioned constraints: assumptions an
agent invented under ambiguity, which nothing marks as guesses, and which become
load-bearing before anyone notices. devseed's job is to make those guesses
either impossible or visible, and to do it through mechanism rather than through
paragraphs of instruction that fall out of working memory as a session gets long.

## 2. Problem context and who this is for

**The problem.** An AI agent working in a repo hits ambiguity constantly. The
spec does not say whether errors bubble or get swallowed; it does not say
whether this module may reach into that one. The agent must do *something*, so
it picks. The pick is reasonable, undocumented, and indistinguishable within a
week from a decision a human actually made. The next change matches the existing
pattern — correctly, by every convention of good engineering — and the invented
constraint is now load-bearing. Unwinding it later means unwinding everything
built on top.

Conventional mitigations degrade. Instructions in `CLAUDE.md` compete for
attention with everything else in context and lose reliability exactly when a
session is long enough to need them. Code review catches wrong code, but an
invented constraint produces *correct* code — there is nothing to flag. Tests
encode the assumption rather than questioning it.

**The approach.** Promote the rules that matter from prose into mechanism:
separate rule files that load independently of working memory, gates that block
rather than advise, and a decision log where an assumption made under ambiguity
gets recorded twice — at the point of contact in the code and in `DECISIONS.md` —
so it is findable from either direction and can be revisited before it hardens.

**Who this is for.** A solo developer or small team building with AI coding
agents, who has already been bitten by drift and wants the guardrails installed
at project start rather than retrofitted at the point of pain. It assumes a
single human is accountable for the spec and available to answer questions — the
whole design leans on "ask the human" being cheap. It is not built for large
teams with contested ownership of the spec, where "stop and ask" has no single
addressee.

**What success looks like.** Copying devseed into a fresh repo costs minutes.
Every constraint an agent operates under is traceable to either DESIGN.md or a
dated entry in DECISIONS.md. There is no third category.

## 3. Architecture and stack

devseed is documents plus configuration. There is no runtime, no build step, no
dependency tree, and no application layer — the scaffold *is* the artifact.

| Choice | What it is | Why |
|---|---|---|
| **Markdown + shell only** | No runtime language. Documents are Markdown; hooks and gates are scripts. | A seed repo must impose zero setup cost on the project that adopts it. Any runtime dependency means the consumer inherits a version, a package manager, and a lockfile before writing a line of their own code. Nothing here needs more than text and a shell. |
| **`DESIGN.md` as constitution** | Single file, spec authority, amended only via §6. | One file to read to know what the system should be. Splitting intent across many files means no one can answer "is this sanctioned?" without a search, and unsearchable intent is functionally absent. |
| **`CLAUDE.md` as state, kept separate** | Describes what exists today; expected to go stale. | Merging spec and state into one file makes drift invisible — the document silently rewrites intent to match code. Separation makes disagreement between the two detectable, which is what `precedence.md` acts on. |
| **`docs/adr/`, indexed by `DECISIONS.md`** | One append-only file per decision; the index is generated. `DECISIONS.md` also carries the hand-written "Spec gaps observed" section inline. | Gives assumptions made under ambiguity a home. Without a destination, `ambiguity.md`'s "record it" instruction has nowhere to land and degrades into "proceed quietly". Per-file so reading one decision does not cost the whole history (ADR-0029). |
| **`.claude/rules/`** | Discrete rule files, one concern each, loaded independently. | The core mechanism. A rule embedded in a long `CLAUDE.md` competes for attention and loses it as context fills. A standalone file is addressable, citable in review, and diffable when it changes. |
| **`.claude/gates/`** | Checks that block on failure. | Advice is optional; a gate is not. Anything that must hold on every change belongs here, not in prose. Definition of what gates exist and what they enforce is §5's job. |
| **`.claude/hooks/`** | Scripts the harness runs at lifecycle points. | Hooks are executed by the harness, not by the agent's goodwill — the only category of rule that cannot be forgotten mid-session. |
| **`.claude/agents/`, `.claude/skills/`** | Scoped subagents and named procedures. | Narrow, single-purpose definitions beat a general agent re-deriving the task each time. Empty at scaffold time; populated as real repeated procedures emerge rather than speculatively. |
| **Bash, with Git Bash a stated prerequisite on Windows** | Gates and hook scripts are bash. On Windows they require Git Bash; `gate.ps1` is a shim that locates it or fails with install instructions. | A gate that only runs on one platform is a gate that silently does not run — so the platform requirement is stated and enforced rather than assumed. One implementation, one behaviour: a parallel PowerShell reimplementation would be a second gate to keep in step, and the two drifting apart is worse than requiring a dependency that ships with Git. See ADR-0006. |
| **Git, no CI assumed** | Version control only; no pipeline dependency. | Enforcement must work locally on a solo developer's machine at the moment of change. CI is an optional second layer, not the foundation — a gate that only fires on push has already let the drift into the branch. |

## 4. Scope

### In scope

- `DESIGN.md` as the constitution, with a defined amendment procedure.
- `.claude/rules/` — the rule files, starting with `precedence.md` and
  `ambiguity.md`.
- `.claude/gates/` — blocking checks, and the definition of what they enforce.
- `.claude/hooks/` — harness-invoked lifecycle scripts.
- `.claude/agents/` and `.claude/skills/` — scoped agent and procedure
  definitions, added as genuine need appears.
- The decision log — `docs/adr/` plus the `DECISIONS.md` index, including the
  "Spec gaps observed" section.
- `CLAUDE.md` describing current repo state.
- Whatever it takes to copy this scaffold into a new repo and have it work.

### Out of scope

- **Application code of any kind.** devseed is the scaffold. If it grows a
  feature, it is no longer a seed.
- **A runtime, package manifest, or dependency tree.** Contradicts §3's zero
  setup cost.
- **Harness-agnostic support.** This targets Claude Code's `.claude/` layout.
  Abstracting over other agent harnesses would mean designing for tools not in
  use here.
- **Team workflow policy** — branch naming, PR templates, review assignment.
  Adjacent, but about people rather than about constraining an agent.
- **Enforcing the *content* of a consumer project's DESIGN.md.** devseed
  supplies the shape and the procedure. What a given project's constraints
  should be is that project's business.

### Explicitly deferred

Each item names where it gets treated instead. An item with no venue is not
deferred — it is out of scope.

| Deferred | Treated instead in |
|---|---|
| Build rules — what gates exist, what blocks, what merely warns | **§5 of this document** — filled in by Prompt 3. |
| Amendment procedure — how DESIGN.md changes | **§6 of this document** — filled in by Prompt 9. |
| `CLAUDE.md` contents | Written once there is state worth describing. Currently the only state is this scaffold. |
| `DECISIONS.md` structure beyond "Spec gaps observed" | `DECISIONS.md` itself, at first real entry. `ambiguity.md` already fixes the one section that must exist. |
| **Speculative** agents and skills | Added when a repeated procedure actually recurs. Speculative agents are unsanctioned constraints wearing a different hat. This does **not** defer the boundary-enforced roster in T-007 — tool boundaries are mechanism, not personas. See ADR-0007. |
| Distribution mechanism — how a consumer obtains devseed | `DECISIONS.md` at first adoption. Copy-the-directory works and needs no decision until it does not. |
| Whether rules generalize beyond `precedence` and `ambiguity` | New file in `.claude/rules/`, one concern per file, once a third distinct concern is identified. |

## 5. Build rules

**`plugins/governed-dev/gates/gate.sh` is the authority.** This section
describes what the gate enforces; it does not define it. If the prose here and
the script disagree, **the script wins and this prose gets fixed** — a rule that
lives only in prose is advice, and advice is optional in practice. Correcting §5
to match the script is a correction, not an amendment, and does not go through
§6.

### The contract

- **Exit 0 = pass. Exit 2 = fail. Never exit 1.** Claude Code treats exit 1 as a
  non-blocking error and proceeds anyway; only exit 2 blocks. A gate that
  returns 1 is a gate that does nothing.
- **Verification only — no side effects.** The gate never stages, commits,
  pushes, or writes any file. It emits an exit code and stderr. CI runs the same
  script (T-009), so a gate that mutated git state would behave differently
  depending on who invoked it. Commit-and-push belongs to the caller, *after*
  the gate passes.
- **Failure messages are instructions, not complaints.** They name the file and
  what to do about it, because an agent reads and acts on that text.
- **A check that cannot run is a failed check.** If a project declares tests and
  the runner is absent, that is exit 2, not a skip. Silent degradation is the
  failure mode being engineered against.

### CI parity

The gate is the single contract between a local run and a CI run. CI invokes
`plugins/governed-dev/gates/gate.sh` itself — the identical script, not a
second implementation of these checks. If local and CI ever disagree about a
change, that disagreement is a defect in the gate, to be fixed in the gate, not
a reason to keep two definitions of "done" or to trust whichever one currently
says pass.

### What it enforces

Checks run cheapest-first; `--fast` runs 1–3 only, for the per-edit hook.

| # | Check | Fails when |
|---|---|---|
| 1 | Code builds | A declared build (npm `build`, Makefile `build`, Python `src/`) errors, or its toolchain is missing |
| 2 | Tests pass | A declared or discovered suite fails, or its runner is missing |
| 3 | Lint and format clean | A configured linter/formatter reports problems, or is missing |
| 4 | Working memory current | Files under `src/` changed but `CLAUDE.md` did not |
| 5 | Task ledger honest | A `## T-NNN` task is marked `done` with no commit hash |
| 6 | Spec gaps answered | A `TODO(spec)` marker in a changed file cites no `SG-NNNN` id, or cites one absent from `DECISIONS.md` |
| 7 | Documents match the repository | `CLAUDE.md` names a path that is gone or that is not committed, omits a directory that exists, or breaks its line budget; a cited `ADR-NNNN`/`SG-NNNN` has no entry; ADR numbering has a hole; a done task's hash fails to resolve (re-checked here so standalone CI runs catch it); a generated ADR index disagrees with `docs/adr/`; a mirrored hook wiring, agent, or skill differs from its shipped copy |

### Conventions the gate depends on

- A spec-gap marker is written `TODO(spec): SG-NNNN — <what the spec omits>`,
  with a matching entry under "Spec gaps observed" in `DECISIONS.md`. The id is
  the link; without it a marker is untraceable and therefore indistinguishable
  from a decision that was actually made.
- A task heading is `## T-NNN`. A commit hash is 7+ hex characters in backticks
  and must **resolve to a commit in this repository** — check 5 runs
  `git cat-file -t`, so a well-formed but fabricated hash fails. `pending`
  deliberately does not satisfy it either.
- `CLAUDE.md`'s structure block is an indented tree inside a fenced code block,
  under a heading naming *structure*. Indentation picks the parent; the first
  run of two or more spaces ends the path column and begins commentary, which
  check 7 ignores. A path the block names must be **tracked**, not merely
  present on disk: existence is a fact about one machine, and an untracked,
  un-ignored file passes locally while failing in every clone — the CI-parity
  defect above, arriving in the direction that shows the author a green gate.
  A `.gitignore`d path is exempt from having to exist at all, since ignored
  paths are runtime state rather than structure.

### Known limits

These are deliberate, and stated so they are not mistaken for coverage:

- **"Declared" is the trigger for checks 1–3.** A project that declares no
  build, tests, or linter passes them vacuously, and says so on stderr. This is
  what makes the gate runnable in devseed itself, which by §3 has no runtime.
  The protection against silent degradation is narrower than it looks: it
  catches *declared-but-unrunnable*, not *never-declared*.
- **Check 6 skips `.md` files**, since the documents defining the convention
  would otherwise match it. A marker parked in prose is not caught.
- **Check 4 keys on `src/`.** Projects that put code elsewhere are not covered
  until the path is made configurable.
- **Generated artifacts are invisible to the gate**, filtered unconditionally
  rather than via the consumer's `.gitignore` (ADR-0005). A project that
  legitimately tracks a directory named `build/` or `dist/` will not have
  changes there seen by checks 4 or 6.
- **Nothing checks whether `CLAUDE.md` copies `DESIGN.md`.** The duplication
  sub-check was removed as a dead rule (ADR-0028), so a summary that restates
  a rule verbatim — the mechanism by which two documents silently diverge, per
  ADR-0012 — is caught only by review. Divergence itself was never checkable;
  now neither is its most common cause.
- **ADR deletion is guarded only by numbering contiguity.** The git-history
  walk was removed for being silently inert under a default shallow checkout
  (ADR-0028). Deleting a middle ADR is caught; deleting the highest-numbered
  one, or deleting one and renumbering the rest, is not.
- **Check 7's reverse staleness test covers top-level directories only.** A
  file or a nested directory absent from the structure block is not reported;
  only paths the block *names* are checked in the forward direction.
- **Check 7's hook-parity test is self-disabling.** It runs only where a
  project both ships `hooks.json` and mirrors it into `.claude/settings.json`,
  which is devseed's arrangement (ADR-0011) and not a consumer's.
- **The gate cannot see the conversation about the repository.** Every check
  here inspects the repository. None inspects what a session *says* about it,
  and a session's self-report reaches the human through a channel with no
  verification step in it. This has already cost: a session reported that its
  scratch probe had truncated the ledgers and been recovered by hard reset —
  true, and evidenced by dangling commit `8782c53` and the reflog entry
  resetting to `f1ad979`, but relayed onward and used as the cited
  justification in two later prompts before anyone checked it against the
  repository. The reply denying it was the same failure inverted: it searched
  committed history, found nothing, and reported "no such incident is in the
  record" without checking the reflog, which held the proof (ADR-0028).
  This is the Layer 0 principle — *do not trust a system's self-report about
  its own correctness* — failing at the one seam the gate structurally cannot
  reach: the conversation is not the repository, and only the repository is
  checkable. **No mechanism is proposed, because there is none.** A check
  would have to read the transcript and rule on whether a claim about the
  repository is true, which is the judgement the whole system exists to avoid
  asking a script to make. What is left is the habit: a claim about the
  repository is worth exactly the command that verifies it, in either
  direction, including when it confirms what you already believe.
- **Session-end ledger hygiene is a human habit, not a check.** The gate
  detects done-without-hash; it cannot detect done-in-fact-but-unrecorded —
  a task whose completing commit exists while its status still reads
  in-progress passes every check. Four tasks sat that way across a session
  boundary (`eb489bd`, recorded a session late). Recording hashes before a
  session ends is a habit the system depends on and cannot enforce — the
  same category as "failure messages are instructions."

## 6. Amendment procedure

Any rule in this document may be amended, including this procedure. Nothing
here is sacred. What is forbidden is not change — it is *silent* change: an
edit that alters what is permitted without leaving a record of who decided,
on what evidence, and what the edit gave up.

### Amendment vs. correction

- A **correction** changes no constraint: prose catching up to the script it
  describes (§5's own rule — the script wins and the prose gets fixed), a
  typo, a broken link, a renumbered reference. Corrections need no ADR and do
  not go through this procedure.
- An **amendment** changes what is permitted, required, or forbidden. Every
  amendment goes through the procedure below. When in doubt, it is an
  amendment — misfiling an amendment as a correction is the silent change
  this section exists to prevent, in miniature.
- Never amend this document to match drifted code
  ([`precedence.md`](.claude/rules/precedence.md)). That inverts the
  direction of authority. An amendment is prompted by evidence a rule is
  wrong, not by the existence of code that violates it.

### The procedure

1. **The ADR comes first** — written and recorded as its own file under
   `docs/adr/` (ADR-0029) before the edit, naming:
   - **the rule**, quoted as currently written;
   - **the specific incident** that showed it wrong. The bar: the rule
     *failed to catch what it existed to catch*, or *caught things it should
     not have* — with an example of each failure claimed (a commit, a task,
     a session). "It was slowing us down" is not sufficient; every gate slows
     you down — that is what a gate is;
   - **the replacement**, as exact text;
   - **what the replacement makes harder.** An amendment whose consequences
     are all upside is advocacy, not a record.
2. **A human approves the ADR, explicitly**, before anything is edited.
   Agents draft and propose; the human decides. This is the same allocation
   the delegation loop already makes for CONFLICT verdicts.
3. **Then the edit**, citing the ADR by number. The `/amend` skill executes
   this procedure end to end and refuses to run it out of order. It does not
   commit — `/task` owns commits.

### The ratchet

**Tightening a gate needs no ADR. Loosening one always does.** Narrowing what
passes, adding a check, extending coverage — proceed, and record it as a
correction to §5's table if the table changed. Weakening a check, widening an
exemption, deleting a rule — that is an amendment, evidence bar and all.

The asymmetry is deliberate. A mistaken tightening announces itself: the gate
blocks something it should not, someone notices within a commit, and the fix
carries its own incident report. A mistaken loosening is silent forever — the
defect it would have caught arrives unannounced, and nothing connects the
arrival to the loosening. Symmetric ceremony would mean either blocking cheap
safety or making dangerous edits cheap; this trades the first for never the
second.

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
   this procedure. One of the two — a bypass is a claim that the gate was
   wrong *here*, and the claim gets tested.

A bypass that is never reconciled is the failure mode this whole system
exists to prevent: it is how a governance layer becomes something everyone
routes around. (This obligation holds by review — mechanical enforcement was
considered and declined when the 2026-08 audit closed; see T-029's closure
note. The deliverable of closing an audit cannot be more audit.)

### The quarterly self-audit

Every quarter, re-run the governance self-audit (first run: T-028,
2026-08-11; next due 2026-11-11): §5 rules with no check in `gate.sh`;
checks in `gate.sh` with no rule in §5; agent allowlists against
`delegation.md`'s stated boundaries; and — the question only time can ask —
**rules that have never fired**. A rule that never fires is either perfect or
dead, and the audit's job is to determine which: a perfect rule's failure
mode is found in the activity log as attempts it deflected; a dead rule
deflects nothing because nothing reaches it, and a dead rule kept on the
books teaches readers that rules here are decorative.
