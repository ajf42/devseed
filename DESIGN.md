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
| **`DECISIONS.md`** | Append-only log; includes the "Spec gaps observed" section. | Gives assumptions made under ambiguity a home. Without a destination, `ambiguity.md`'s "record it" instruction has nowhere to land and degrades into "proceed quietly". |
| **`.claude/rules/`** | Discrete rule files, one concern each, loaded independently. | The core mechanism. A rule embedded in a long `CLAUDE.md` competes for attention and loses it as context fills. A standalone file is addressable, citable in review, and diffable when it changes. |
| **`.claude/gates/`** | Checks that block on failure. | Advice is optional; a gate is not. Anything that must hold on every change belongs here, not in prose. Definition of what gates exist and what they enforce is §5's job. |
| **`.claude/hooks/`** | Scripts the harness runs at lifecycle points. | Hooks are executed by the harness, not by the agent's goodwill — the only category of rule that cannot be forgotten mid-session. |
| **`.claude/agents/`, `.claude/skills/`** | Scoped subagents and named procedures. | Narrow, single-purpose definitions beat a general agent re-deriving the task each time. Empty at scaffold time; populated as real repeated procedures emerge rather than speculatively. |
| **Cross-platform scripts** | Hooks and gates must run on Windows/PowerShell and POSIX shells. | Primary development happens on Windows 11 with PowerShell; the Bash tool is also available, and consumer repos will not all be Windows. A gate that only runs on one platform is a gate that silently does not run. |
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
- `DECISIONS.md`, including the "Spec gaps observed" section.
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
| Build rules — what gates exist, what blocks, what merely warns | **§5 of this document**, filled in by Prompt 3. Placeholder until then. |
| Amendment procedure — how DESIGN.md changes | **§6 of this document**, filled in by Prompt 9. Placeholder until then. |
| `CLAUDE.md` contents | Written once there is state worth describing. Currently the only state is this scaffold. |
| `DECISIONS.md` structure beyond "Spec gaps observed" | `DECISIONS.md` itself, at first real entry. `ambiguity.md` already fixes the one section that must exist. |
| Contents of `agents/` and `skills/` | Added when a repeated procedure actually recurs. Speculative agents are unsanctioned constraints wearing a different hat. |
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

### Conventions the gate depends on

- A spec-gap marker is written `TODO(spec): SG-NNNN — <what the spec omits>`,
  with a matching entry under "Spec gaps observed" in `DECISIONS.md`. The id is
  the link; without it a marker is untraceable and therefore indistinguishable
  from a decision that was actually made.
- A task heading is `## T-NNN`. A commit hash is a backticked hex string;
  `pending` deliberately does not satisfy check 5.

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

## 6. Amendment procedure

> **Placeholder — filled in by Prompt 9.**
>
> This section defines how DESIGN.md itself changes: what constitutes an
> amendment, who may make one, what must be recorded, and how an amendment is
> distinguished from a correction. Until it is written, there is no sanctioned
> path for editing this document — so do not edit it. Per
> [`precedence.md`](.claude/rules/precedence.md), never amend it to match drifted
> code.
