# TASKS.md — devseed

Backlog for **devseed's own development**. Not the template shipped to consumers
— that is [`plugins/governed-dev/templates/TASKS.md`](plugins/governed-dev/templates/TASKS.md).

## Conventions

- **One task per commit.** A commit that closes two tasks means one of them was
  not a task. Split it.
- **Status:** `todo` → `in-progress` → `done`, or `blocked` (name the blocker)
  or `dropped` (name why; never delete the row).
- **Acceptance criteria are written before the work starts**, not after. A task
  whose criteria are written afterward is a description of what happened, and
  cannot fail.
- **Commit hash** is recorded when the task is done, and `gate.sh` check 5
  enforces it: a task marked `done` without a hash fails the gate. Because a
  commit cannot contain its own hash, a task finished in the current commit
  stays `in-progress` until the *next* commit records both its status and its
  hash. Do not park `pending` in the Commit field — the gate rejects it, which
  is the intended behaviour.
- Tasks that turn out to be spec gaps move to `DECISIONS.md` under "Spec gaps
  observed" and are marked `blocked` here with a pointer.

---

## T-001 — Governance scaffold

- **Description:** Create `DESIGN.md` as the project constitution, plus
  `.claude/` with `agents/`, `skills/`, `gates/`, `hooks/`, `rules/`, and the
  `precedence.md` and `ambiguity.md` rule files.
- **Acceptance:** DESIGN.md §§1–4 substantive and specific to this repo; both
  rule files exist; no application code touched.
- **Status:** done
- **Commit:** `aa53aef`

## T-002 — Split plugin content from the repo's own governance

- **Description:** Restructure so devseed can be both a governed project and a
  plugin source. Move `agents/`, `skills/`, `gates/`, `hooks/` into
  `plugins/governed-dev/`; add marketplace and plugin manifests; add
  `templates/`; leave `.claude/rules/` at root.
- **Acceptance:** `claude plugin validate .` passes; repo pushed to GitHub;
  `marketplace add` + `install` succeed from a directory outside this repo;
  DECISIONS.md records the split.
- **Status:** done
- **Commit:** `70542ef`
- **Note:** Passed except repository visibility — see SG-0002.

## T-003 — Ledger documents and activity log

- **Description:** Create `CLAUDE.md`, `TASKS.md`, and `.claude/activity.jsonl`;
  extend `DECISIONS.md` with ADR format and the superseded convention; add
  `.claude/rules/ledger.md`; fill in the four `templates/` skeletons.
- **Acceptance:** All four ledger documents exist; CLAUDE.md states its own line
  budget; DECISIONS.md documents the superseded convention; a fresh session
  reading only these four files can tell what exists and what is next.
- **Status:** done
- **Commit:** `5a84fef`

## T-004 — Build rules and `gate.sh`

- **Description:** Fill in `DESIGN.md` §5 and build the gate at
  `plugins/governed-dev/gates/gate.sh`, plus the `templates/gate.sh` seed.
- **Acceptance:** §5 defines what blocks vs. what warns and what "done" means;
  the gate runs on both POSIX and Windows shells; it operates on
  `${CLAUDE_PROJECT_DIR}`, not the plugin's own directory; exits 0 on a clean
  tree and 2 with an actionable message on failure, never 1.
- **Status:** done
- **Commit:** `ae9bf3d`
- **Note:** `templates/gate.sh` deliberately left as a placeholder; see SG-0003.

## T-005 — Hooks

- **Description:** Define real hooks in `plugins/governed-dev/hooks/hooks.json`
  wiring the gate into lifecycle events.
- **Acceptance:** Scripts located via `${CLAUDE_PLUGIN_ROOT}`; gate targets
  `${CLAUDE_PROJECT_DIR}`; the existing `_CONVENTION_*` notes survive the edit;
  `claude plugin validate .` still passes; `plugin details` reports a nonzero
  hook count.
- **Status:** done
- **Commit:** `a2c0cb8`
- **Note:** Eight hooks registered across `Setup`, `SessionStart`, `PreToolUse`,
  `PostToolUse`, `Stop`, `PreCompact`, `SessionEnd`, `SubagentStop`, with eight
  scripts in `plugins/governed-dev/hooks/` and a devseed-only mirror at
  `.claude/settings.json`. Four decisions departed from the instruction and are
  recorded: ADR-0008 (the Stop gate releases after three blocks — today's API
  has no `stop_hook_active`), ADR-0009 (the compaction flush writes
  `.claude/in-flight.md`, because appending to `CLAUDE.md` would defeat gate
  check 4), ADR-0010 (shell form, not exec form) and ADR-0011 (the mirror).
  SG-0005 is open; SG-0006 was opened and resolved by ADR-0010.
- **Verified:** 45 behavioural assertions pass against synthetic events —
  every boundary case including all three Windows path spellings, the Stop
  block JSON with the gate's stderr inside `reason`, the three-block breaker
  and its reset, the disagreement detector on all four classes, the snapshot
  cap, and JSONL validity. `gate.sh` exits 0 and `gate-regression.sh` reports
  6/6. **Live:** the `PreToolUse` boundary blocked a real `Edit` the moment
  `.claude/settings.json` landed — ADR-0010 records it.
- **Three defects found by that testing, all invisible to inspection:** the
  Windows drive-letter path mismatch silently disarmed the implementer boundary;
  `grep -c` exiting 1 on zero matches yielded `"00"` and silently disabled one
  disagreement check; exec form would have meant no hook ran at all.

## T-006 — Drift guards

- **Description:** Guards that detect divergence between what the documents
  claim and what the repository contains — the failure class `precedence.md`
  names as *structural* disagreement, which must be surfaced rather than
  reconciled silently. The review that produced T-012..T-015 found exactly this
  class by hand; these guards are the mechanical version.
- **Acceptance:** Detects at least: a `DESIGN.md` claim with no implementation
  behind it (§3 claimed Windows/PowerShell support the bash-only gate never
  had — that specific case must be caught); `CLAUDE.md` describing files or
  components that no longer exist; a `TASKS.md` entry referencing a task id or
  spec-gap id that appears nowhere else. Reports drift; changes nothing. Exits
  non-zero on detection so it can be wired into the gate or CI.
- **Also required (added by T-005):** the hook wiring exists in two places —
  `plugins/governed-dev/hooks/hooks.json`, which ships, and
  `.claude/settings.json`, which is devseed's own mirror against the working
  tree (ADR-0011). The scripts are shared, so the drift surface is the event
  set, the matchers and the async flags. Assert the two agree. Nothing else
  will notice, and a mirror that has silently stopped matching is the same
  class of defect as a `CLAUDE.md` describing files that no longer exist.
- **Status:** done
- **Commit:** `803df4d`
- **Built:** `plugins/governed-dev/gates/drift.sh`, wired as gate check 7 via
  `check-07-drift.sh`. Six drift classes: duplication (no ≥12-word run of a
  DESIGN.md rules section in CLAUDE.md), staleness (both directions), budget
  (≤300 lines, warn at 250), orphans (ADR/SG ids, done-task hashes),
  superseded integrity (contiguous ADR numbers, nothing deleted that git
  history remembers), hook parity. Reports every finding, not the first.
  Runs standalone for T-009. Design in ADR-0012.
- **Criteria corrected:** the source prompt arrived and the reconstruction was
  checked against it before work started, per SG-0004. Three criteria were
  missing from it and one was invented; SG-0004 records the diff and the
  human's decision to drop the invented one. The T-005 hook-parity clause was
  kept.
- **Verified:** 23 assertions in `scripts/gate-regression.sh`, including both
  acceptance cases — a rules sentence pasted into CLAUDE.md fails naming the
  duplicated text, and a deleted documented directory is caught. Each check was
  also proved to bite individually against the real tree; a window sweep
  (4→12 words) confirms check 1 is live rather than passing vacuously.

## T-007 — Agent roster with enforced tool boundaries

- **Description:** Build all five agents under `plugins/governed-dev/agents/`:
  **spec-guardian**, **implementer**, **reviewer**, **scribe**, **auditor**.
  The roster is not the point — the tool boundaries are. An agent that hits a
  spec wall must not be able to write itself permission. See ADR-0007.
- **Boundaries** (each agent declares an explicit `tools:` allowlist):
  - `spec-guardian` — read-only (`Read`, `Grep`, `Glob`). Judges whether a
    change is sanctioned by DESIGN.md. No write tools at all.
  - `implementer` — `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob`, but
    **denied write access to `DESIGN.md`, `DECISIONS.md`, and `TASKS.md`**.
    This is the load-bearing boundary.
  - `reviewer` — read-only plus `Bash` to run the gate. No write tools.
  - `scribe` — `Read`, `Edit`, `Write` scoped to `DECISIONS.md`, `TASKS.md`,
    `CLAUDE.md`. No code, no `Bash`.
  - `auditor` — read-only plus `Bash`. Reports drift; fixes nothing.
- **Acceptance:** Each agent file declares its `tools:` allowlist explicitly.
  The implementer boundary is demonstrated by **observed denial** — an
  implementer run that attempts to write `DECISIONS.md` is blocked — not by a
  declared intention in its prompt. `claude plugin details governed-dev`
  reports five agents.
- **Blocked on:** T-005, now partially cleared. The `PreToolUse` deny hook
  exists (`hooks/boundary.sh`) and encodes all five boundaries, so the path
  restriction `tools:` cannot express is in place — but it binds only work
  carrying an `agent_type`, i.e. real subagents. The main session thread is
  unbounded, per **SG-0005**. Until the agents exist the boundaries have nothing
  to bind, and CLAUDE.md must not describe them as enforced.
- **Status:** done
- **Commit:** `3444eff`
- **Built:** five agents at `plugins/governed-dev/agents/`, each declaring
  `tools:` explicitly, plus [`.claude/rules/delegation.md`](.claude/rules/delegation.md)
  describing the loop and naming its one rule — the agent that makes a decision
  never writes the record justifying it. Mirrored to `.claude/agents/` so
  devseed can run its own roster (ADR-0014).
- **Deviation from this task's own text:** `scribe` holds `Read, Edit` — **no
  `Write`**, where the criteria above said "`Read`, `Edit`, `Write` scoped".
  Prompt 6 specified `Read, Edit`, and the narrower list is also better: with no
  `Write` the scribe cannot create files at all, so its boundary is enforced by
  capability rather than only by path.
- **The Bash seam, resolved (ADR-0013).** `boundary.sh` watched
  `Edit|Write|NotebookEdit` while the implementer held `Bash`, so
  `echo x >> DECISIONS.md` was never a tool it inspected — the load-bearing
  denial held for three tools and was absent for a fourth reaching the same
  files. The suggested alternative, a scoped `Bash(pytest:*)` in `tools:`,
  **does not exist**: that syntax is `permissions.allow` in settings.json and is
  session-scoped, and `permissionMode`/`hooks` frontmatter is ignored for plugin
  subagents. So the hook was extended to inspect `.tool_input.command`, and the
  `PreToolUse` matcher gained `Bash|PowerShell` in both wirings.
- **Verified:** 73 assertions in `scripts/boundary-regression.sh`, plus both
  acceptance cases run live against a real session:
  - the implementer was **denied** writing `DECISIONS.md`, with the message
    naming the scribe; the file was byte-identical afterward and the agent
    stopped rather than routing around;
  - the **full loop ran on a real task** (`.gitattributes` for `*.sh`) — all
    five agents, producing ADR-0015 and SG-0008. The loop corrected the premise
    it was given: Git Bash tolerates a trailing CR, so the defect is narrower
    than stated, and the ADR records the corrected reason. The auditor
    independently caught `CLAUDE.md` staleness this task then fixed.
- **Plugin inventory verified** after pushing and running `plugin update`
  (`70542ef38e36` → `f8c9ed95fa11`): `claude plugin details` reports
  `Agents (5)` — auditor, implementer, reviewer, scribe, spec-guardian — and
  `Hooks (8)`. `claude plugin validate .` passes with the one intended
  `version` warning.
- **SG-0007 opened:** the shipped agents cite `.claude/rules/*` files that do
  not ship. T-008 forces the answer.

## T-008 — Bootstrap skill

- **Description:** Build `plugins/governed-dev/skills/bootstrap`, which seeds a
  target project from `plugins/governed-dev/templates/`.
- **Acceptance:** Sources documents from `templates/` rather than generating
  prose; installs namespaced as `/governed-dev:bootstrap`; verified against a
  project outside this repo.
- **Status:** done
- **Commit:** `eb489bd`
- **Note:** whether the seeded project also gets a `.gitattributes` (so a
  Windows-bootstrapped `gate.sh` doesn't reproduce the CRLF defect ADR-0015
  closed in devseed) is resolved — see SG-0008.
- **Built:** four skills at `plugins/governed-dev/skills/` — bootstrap, task,
  adr, resume — mirrored to `.claude/skills/` as a third mirror alongside the
  hook wiring and agent roster (ADR-0016). Also built:
  `plugins/governed-dev/templates/rules/` and `templates/.gitattributes`
  (ADR-0017); `check_skill_parity` added to `drift.sh`; and
  `scripts/bootstrap-regression.sh`.
- **Verified:** 44 bootstrap assertions, 37 gate assertions (now including
  mirror-parity cases for both agents and skills, previously untested), 73
  boundary assertions.
- **A reviewer pass returned BLOCK before this landed**, with two HIGH
  findings — a bootstrapped consumer project failed its own drift gate on
  four dangling devseed ids in the shipped templates, and an invisible CRLF
  drift in `auditor.md` (see SG-0009). Both were fixed; the first is now
  asserted by `scripts/bootstrap-regression.sh`, which seeds a scratch
  project and runs the real drift guard against it.

## T-009 — CI parity

- **Description:** Run the identical gate in CI that runs locally, so "passes
  on my machine" and "passes in CI" cannot diverge. A GitHub Actions workflow
  calls `plugins/governed-dev/gates/gate.sh` on every PR — the same script, not
  a reimplementation. Source: Prompt 8, transcribed in full 2026-08-11,
  resolving SG-0004's T-009 half.
- **Acceptance:** `.github/workflows/gate.yml` invokes the identical
  `gate.sh` — no forked copy, no reimplemented checks; a change that fails
  locally fails CI with the same message and vice versa; the gate's
  no-side-effects rule holds under CI, which is why commit-and-push lives in
  `/task` and never in the gate. `DESIGN.md` §5 gains a short subsection
  stating the gate is the contract between local and CI, and that divergence
  is a defect, not a reason for a second gate.
- **Status:** done
- **Commit:** `00077f8`
- **Note:** Resolves SG-0003's CI half: devseed's own CI checks out devseed
  itself — the plugin's source — so it calls `gate.sh` by its repo-relative
  path directly. Neither a vendored copy nor `${CLAUDE_PLUGIN_ROOT}` is
  needed. This does not answer whether a *consumer* project's CI needs a
  vendored `gate.sh`; that half of SG-0003 stays open, since devseed's own CI
  never exercises it.
- **CI verification (2026-08-11, Prompt 9a item 1):** as of this writing CI
  has **never run** — the GitHub API reports zero workflow runs, because
  `main` was never pushed after `gate.yml` landed (`origin/main` sat at
  `eb489bd`). A push was authorized and attempted this session but blocked
  by the credential dialog on a freshly set-up machine. The workflow has
  since gained the three-leg matrix and the regression suites (T-030), so
  the **first run ever will be the full matrix run**. Verify it green on all
  three legs after pushing, and record run id and date here; until then,
  every gate pass in this repository's history is a Git-Bash-on-Windows
  pass, and ubuntu/macos are unexercised. A red leg is a platform bug found
  by the matrix doing its job, and per Prompt 9a it gets an ADR.
- **First green matrix run (2026-08-11):** run id `31534896418` (run #2,
  push of `5759381`) — ubuntu, macos and windows legs all green: gate,
  gate-regression (46), boundary-regression (73), bootstrap-regression (44).
  Run #1, the first CI run in the repository's history, failed at check 5
  on all three legs; the predicted ADR exists as ADR-0025 (shallow
  checkout, not a platform dialect — plus the latent copy-drift and BSD-sed
  defects the verification and audit surfaced), corrected by T-031–T-033.

## T-025 — Setup hook installs dependencies

- **Description:** `preflight.sh` (the `Setup` hook, firing on `claude
  --init-only` and `-p --init`) currently only *reports* a missing `jq`/`git`/
  bash-on-PATH; it fixes nothing. Prompt 8 asks for installation, so a fresh
  clone or a CI container becomes gate-ready in one command.
- **Acceptance:** In a CI environment (`$CI` truthy), a missing `jq` is
  installed automatically (`apt-get`) rather than merely reported. On an
  interactive developer machine, behaviour is unchanged from today — report
  plus install instructions — since auto-installing on every session start
  mutates a human's system in a way a disposable CI container does not share,
  and Prompt 8 does not say to change that distinction. Verifying the test
  runner and linter are present delegates to `gate.sh --fast` rather than
  reimplementing checks 1–3's detection a second time.
- **Status:** done
- **Commit:** `00077f8`

## T-026 — Headless verification path

- **Description:** A scheduled, unattended run of the auditor agent, posting
  `drift.sh`'s output. Safe unattended because the auditor is read-only —
  `tools: Read, Grep, Glob, Bash`, no write capability — and "proposes nothing
  and fixes nothing" by its own definition (`.claude/agents/auditor.md`).
- **Acceptance:** `.github/workflows/audit.yml` runs on a cron schedule,
  invokes `claude -p` with the auditor agent, and posts its DRIFT REPORT to
  the GitHub Actions job summary. Requires an API credential the workflow does
  not supply — flagged in the workflow file and in DECISIONS.md rather than
  invented, since devseed has no secret to give it.
- **Status:** blocked — needs an `ANTHROPIC_API_KEY` secret this repository
  does not have. `audit.yml` shipped in `00077f8` and was **deleted** in
  ADR-0028: six workflow runs exist in the repository's whole history and all
  six are `gate`, so it never ran once and could not have. The historical
  delivery stands; the capability does not. Re-doing it starts from the
  credential, not from the workflow file.
- **Commit:** `00077f8` (the delivery; since removed)

## T-027 — Commit provenance trailer

- **Description:** Every commit `/task` makes carries a trailer recording
  agent type, session id, task id, and model — resolving **SG-0010**, open
  since T-008: the trailer was specified as "per Prompt 8 §4," which did not
  exist until this prompt arrived.
- **Acceptance:** `/task`'s commit step appends `Agent-Type`, `Session-Id`,
  `Task-Id`, `Model` trailers alongside the existing `Co-Authored-By` line.
  `Session-Id` is machine-sourced (`$CLAUDE_CODE_SESSION_ID`), not invented by
  the agent, and is what makes a commit joinable to `.claude/activity.jsonl`
  by `session_id`.
- **Status:** done
- **Commit:** `00077f8`
- **Deviation from convention:** T-009, T-025, T-026 and T-027 land in one
  commit, not four. Put to the human when all four were built together as one
  coherent diff; the human chose one commit over the convention's default,
  the same kind of explicit choice T-018 recorded for its own deviation. All
  four carry the same commit hash below once recorded.

## T-010 — Amendment procedure

- **Description:** Fill in `DESIGN.md` §6 — how DESIGN.md itself changes, who
  may amend, what is recorded, and how an amendment differs from a correction.
  Source: Prompt 9, transcribed in full 2026-08-11 — the earlier criteria
  below were reconstructed and stand, with the prompt adding four specifics.
- **Acceptance:** §6 is no longer a placeholder; the procedure is executable by
  a fresh session without asking; it forbids amending DESIGN.md to match
  drifted code. From the source prompt: any rule may be amended, including §6
  itself; an amendment requires an ADR **before** the change naming the rule,
  the specific incident that showed it wrong (the rule failed to catch what it
  existed to catch, or caught what it should not — with an example; "it was
  slowing us down" is insufficient), the replacement, and what the replacement
  makes harder; the ratchet — tightening a gate needs no ADR, loosening one
  always does, asymmetry deliberate; emergency bypass is allowed and expected,
  requires a commit trailer naming the gate and the reason, and opens a task
  to restore or amend — an unreconciled bypass is the failure mode the system
  exists to prevent; the self-audit re-runs quarterly, and rules that never
  fire are either perfect or dead.
- **Status:** done
- **Commit:** `f1ad979`
- **Deviation from convention:** T-010, T-021 and T-028 land in one commit,
  matching the human's standing choice for prompt-sized work (T-027's note).

## T-011 — Return the repository to private

- **Description:** `github.com/ajf42/devseed` is public, deliberately and
  temporarily (SG-0002). The original private requirement rested on
  IP-entanglement risk and has not been withdrawn. Needs `gh` installed and
  authenticated, or the GitHub web UI.
- **Acceptance:** An unauthenticated request to the repo API returns 404;
  `marketplace add` still resolves with credentials available.
- **Status:** blocked — deliberate temporary window, see SG-0002. **The end
  condition is not recorded**; until it is, nothing distinguishes this from
  indefinitely public.

## T-012 — Stop the gate poisoning itself with test artifacts

- **Description:** `changed_files()` counted pytest's `__pycache__/` as source
  changes, so check 4 failed on a committed tree — on the first run and every
  run after. Filter generated artifacts unconditionally; ship
  `templates/.gitignore`; add a double-run regression.
- **Acceptance:** `scripts/gate-regression.sh` exits 0, asserting the gate
  exits 0 on two consecutive runs over a committed scratch project with a real
  test suite; `templates/.gitignore` exists; ADR-0005 records the decision.
- **Status:** done
- **Commit:** `af60cd7`

## T-013 — Make §3's platform claim and the implementation agree

- **Description:** §3 required Windows/PowerShell support the bash-only gate
  never had. Narrow §3 to bash with Git Bash a stated Windows prerequisite, add
  a PowerShell shim that finds bash or fails with install instructions, and make
  `gate.sh` refuse to run under a non-bash shell.
- **Acceptance:** `gate.ps1` runs the gate from PowerShell, passes `--fast`
  through, and propagates the exit code; it exits 2 with install instructions
  when no bash is found; §3 and the implementation agree; ADR-0006 records the
  rejected PowerShell-reimplementation alternative.
- **Status:** done
- **Commit:** `64ebd90`

## T-014 — Disarm the `set -e` trap in the gate template

- **Description:** `templates/gate.sh` opened `set -euo pipefail`, contradicting
  the real gate, which deliberately omits `-e` because it surfaces a failed
  check as exit 1 — and exit 1 does not block. Anyone filling in the template
  from that placeholder would inherit the exact bug the build rules warn about.
- **Acceptance:** `templates/gate.sh` uses `set -uo pipefail` and carries the
  one-line reason, while remaining a placeholder per SG-0003.
- **Status:** done
- **Commit:** `a4a723b`

## T-015 — Check 5 must verify the hash resolves, not just its shape

- **Description:** Check 5 matched hash *format*, so a task marked done with a
  fabricated but well-formed hash passed. A ledger that accepts unresolvable
  hashes proves nothing, which defeats the check's stated purpose. Verify with
  `git cat-file -t` and distinguish "no hash" from "hash resolves to nothing".
- **Acceptance:** `scripts/gate-regression.sh` asserts a real hash is accepted,
  `deadbee` is rejected, and a done task with no hash is rejected; devseed's own
  gate still exits 0 with every recorded hash resolving.
- **Status:** done
- **Commit:** `96fab56`

## T-016 — Restore the agent roster and record the §4 tension

- **Description:** T-007 had collapsed from five agents to the scribe alone,
  dropping the tool boundaries that make the roster mean anything. Expand it,
  and record why §4's "no speculative agents" deferral does not cover boundary
  enforcement.
- **Acceptance:** T-007 names all five agents with per-agent `tools:`
  allowlists and an observable-denial acceptance criterion; §4's deferred entry
  is narrowed to speculative agents; ADR-0007 records the rejected alternatives.
- **Status:** done
- **Commit:** `44e56cf`

## T-017 — Transcribe the untranscribed prompt specs into tasks

- **Description:** Three of Prompt 7's four skills, Prompt 7a, and the criteria
  for Prompts 5 and 8 existed in the source series but never reached TASKS.md.
  The convention requires criteria written before work starts; these were simply
  not written down.
- **Acceptance:** No task reads "not yet specified"; tasks exist for `/task`,
  `/adr`, `/resume`, `/amend` and ticket sync; T-006 and T-009 carry real
  criteria; reconstructed criteria are flagged as such.
- **Status:** done
- **Commit:** `1dce0de`

## T-018 — `/task` skill

- **Description:** The skill that runs a task end to end and is the *only* thing
  that commits. `gate.sh` is verification-only precisely so that this can own
  commit-and-push.
- **Acceptance:** The gate must pass **before** anything is committed — a failed
  gate aborts without staging. Refuses to commit directly to `main` or `master`,
  branching first. A push failure is **reported, never swallowed**: the skill
  exits non-zero and says what failed, rather than reporting success on a commit
  that only exists locally. Records the commit hash against the task in
  `TASKS.md`, per the hash convention.
- **Status:** done
- **Commit:** `eb489bd`
- **Deviation from this task's own acceptance text:** it says "refuses to
  commit directly to `main` or `master`, branching first." The skill as built
  commits locally on `main` and withholds the *push*, stating that direct
  pushes to the default branch are not automatic by design. That is what
  Prompt 7 specified and it is a different behaviour from branching first —
  recorded here rather than reconciled.

## T-019 — `/adr` skill

- **Description:** Appends a decision entry to `DECISIONS.md` in the format that
  file defines.
- **Acceptance:** Appends to the bottom; never edits or deletes an existing
  entry; refuses to write an entry whose Context names no rejected alternatives,
  since an ADR without them records a preference rather than a decision; marks
  superseded entries rather than removing them.
- **Status:** done
- **Commit:** `eb489bd`

## T-020 — `/resume` skill

- **Description:** Reconstructs working context for a fresh session from the
  ledger alone — the acceptance criterion T-003 was built against.
- **Acceptance:** Reads `CLAUDE.md`, `TASKS.md`, `DECISIONS.md` and reports what
  exists, what is in progress, and what is next, without exploring the codebase;
  names open spec gaps; does not modify anything.
- **Status:** done
- **Commit:** `eb489bd`

## T-021 — `/amend` skill

- **Description:** Executes the amendment procedure that T-010 writes into
  `DESIGN.md` §6. The procedure and its executor are separate tasks, and the
  procedure alone is advice. Prompt 9 (transcribed 2026-08-11) supplies §6's
  content, resolving the ordering CONFLICT ADR-0018 recorded: §6 is now
  written first, from the prompt, and `/amend` implements §6 — not the other
  way round.
- **Acceptance:** Executes §6's steps; requires the ADR to exist and be
  human-approved **before** any edit to `DESIGN.md`; enforces §6's evidence
  bar (a named incident, not "it was slowing us down"); applies the ratchet —
  refuses to loosen without an ADR while letting a tightening proceed;
  refuses to amend `DESIGN.md` to match drifted code, which `precedence.md`
  forbids and which is the one edit an amendment tool must not make easy;
  distinguishes an amendment from a correction as §6 defines it; does not
  commit (`/task` owns commits).
- **Status:** done
- **Commit:** `f1ad979`

## T-022 — Ticket sync (optional)

- **Description:** Sync tasks against an external ticket system. **Optional and
  dormant by design** — it stays inert unless deliberately enabled.
- **Acceptance:** Absent configuration it does nothing and reports nothing; no
  other task depends on it; enabling it is an explicit, recorded act.
- **Status:** todo — **optional**, may never be built (Prompt 7a)
- **Note:** Recorded so a future session finds it rather than reinventing it.
  "Optional" and "forgotten" are different states, and only one of them is
  written down.

## T-023 — Write the README

- **Description:** `README.md` was one line and the repository is public. Write
  what devseed is, the install two-liner, and the four-filenames-exist-twice
  warning that `CLAUDE.md` already flags as the sharpest edge in the layout.
- **Acceptance:** README states the problem devseed addresses, the two install
  commands, the Windows/Git Bash prerequisite, the namespacing surprise, and the
  root-vs-templates warning with the test for telling them apart.
- **Status:** done
- **Commit:** `25bc1ca`

## T-024 — Resolve the SG-0002 contradiction

- **Description:** SG-0002 recorded private-was-required-and-public-is-a-gap
  while the repository was deliberately public. The record and reality
  disagreed — the drift class this system exists to catch, sitting in the file
  that catalogs drift.
- **Acceptance:** SG-0002 states plainly that public is deliberate and
  temporary, distinguishes that from a reversal of the original reasoning, and
  names what is still missing; T-011 stays open rather than being closed by
  restatement.
- **Status:** done
- **Commit:** `fd3faea`

## T-028 — Governance self-audit (first run)

- **Description:** Audit the governance layer against itself (Prompt 9):
  every `DESIGN.md` §5 rule with no corresponding check in `gate.sh` (rules
  relying on an agent's memory — the failure mode this system exists to
  eliminate), with a proposed check for each; every `gate.sh` check with no
  corresponding §5 rule (undocumented constraints — nobody knows why they are
  failing); every agent whose `tools:` allowlist does not match its stated
  boundary in `.claude/rules/delegation.md`.
- **Acceptance:** The audit produces a real list with real gaps — a clean
  first run means it is not looking hard enough. Findings that are sanctioned
  corrections (§5 prose behind the script) are applied; findings needing new
  mechanism become tasks rather than being built unsanctioned; findings that
  are known, documented tensions are cited to their ADR/SG rather than
  re-reported as new.
- **Status:** done
- **Commit:** `f1ad979`
- **Findings summary** (full report in the Prompt 9 commit message and
  session log): three §5 rules with no mechanical check — the CI-parity rule
  itself, the exit-0/2-never-1 contract, and verification-only/no-side-effects
  (the latter two asserted only by `scripts/gate-regression.sh`, which CI
  never runs); one §5 rule not mechanizable at all — "failure messages are
  instructions" — named as judgment-reliant rather than given a fake check.
  Three enforced constraints undocumented in §5's check table: ADR-number
  contiguity, agent/skill mirror byte-parity, and drift's standalone re-check
  of done-task hashes — corrected in §5 as sanctioned prose-behind-script
  fixes. Two agents (reviewer, auditor) hold `Bash` while delegation.md's
  table says they write nothing — the gap is bridged only by the syntactic
  `PreToolUse` hook, already documented as evadable (ADR-0013); reported as
  confirmation of a known tension, not a new finding. §6's new rules are born
  unenforced (bypass reconciliation, quarterly cadence) — tasked as T-029.

## T-029 — Enforce what the self-audit found unenforced

- **Description:** The mechanizable checks T-028 proposed: a drift check that
  `.github/workflows/gate.yml` still invokes the real `gate.sh` (the CI-parity
  rule currently holds by nobody editing the workflow); a check-inventory
  parity guard (§5's numbered check table vs the `check-NN-*.sh` files on
  disk, so an added or removed check cannot go undocumented); and §6 bypass
  reconciliation — a commit carrying a `Gate-Bypassed:` trailer must open or
  cite a task to restore or amend the bypassed gate.
- **Acceptance:** Each lands as a drift-guard extension with a regression
  assertion; each is self-disabling where the file it inspects does not exist
  (consumer projects have no `.github/workflows/gate.yml`); §5's check table
  documents whatever lands, per the correction rule.
- **Status:** done
- **Commit:** `c0d1db7`
- **Closure note (2026-08-11, human decision — Prompt 9a item 3):** folded
  into T-030 at minimum size rather than built as specified above. What
  landed: one assertion in `scripts/gate-regression.sh` — `gate.yml` carries
  the canonical `bash plugins/governed-dev/gates/gate.sh` invocation,
  self-disabling with a note where the workflow is absent. What was
  **declined, deliberately**: the check-inventory parity guard and the §6
  bypass-reconciliation check — "no new mechanisms; the deliverable of
  closing an audit cannot be more audit." Bypass reconciliation therefore
  holds by review, recorded as such in §6 itself. If a bypass ever goes
  unreconciled in practice, that incident is the evidence a future amendment
  would cite.

## T-030 — Run the gate's own regressions in CI

- **Description:** The §5 contract rules — exit 0/2 never 1, and
  verification-only/no side effects — are asserted only by
  `scripts/gate-regression.sh`, which runs on no schedule and in no pipeline.
  CI currently runs the gate but never the gate's tests, so a defect in the
  gate itself (the single definition of done) has no mechanical detector.
- **Acceptance:** `gate.yml` (or a sibling workflow) runs
  `scripts/gate-regression.sh`, `scripts/boundary-regression.sh` and
  `scripts/bootstrap-regression.sh` on PRs touching `gates/`, `hooks/`,
  `agents/` or `templates/`; a no-side-effects assertion (working tree
  byte-identical before and after a full gate run) is added to the regression
  if not already implied by its double-run case.
- **Status:** done
- **Commit:** `c0d1db7`
- **Built (2026-08-11):** all three suites added to `gate.yml` as
  unconditional steps on every leg — on all PRs and main pushes rather than
  path-filtered, since the suites are cheap and a path filter is one more
  thing to go stale; no `continue-on-error`, no leg exclusions. The workflow
  also gained the ubuntu/macos/windows matrix (`fail-fast: false`) the human
  chose during Prompt 9a, plus setup-python and a pytest install — the
  suites' scratch projects declare a real test suite, and a suite that
  cannot run is a failed run. The no-side-effects assertion rides implicitly
  on the double-run case; an explicit byte-identical assertion was not added
  (minimum-size discipline, same as T-029's fold).

## T-033 — Record the first-matrix-run incident as an ADR

- **Description:** The first CI run in the repository's history failed at
  check 5 on all three legs. Record the incident as ADR-0025 — accurate to
  what verification showed, not to the diagnosis offered with the failure:
  the cause was `gate.yml`'s default depth-1 checkout (no historical hash
  could resolve), while the suspected awk interval regexes were a real but
  latent second defect — the check-5-vs-drift copy-drift. Lands *first*,
  before the fixes: record, then edit.
- **Acceptance:** ADR-0025 exists in DECISIONS.md with the verified causal
  chain, the copy-drift finding, the alternatives (bounded depth, lib.sh
  extraction, installing gawk) and what each rejection trades away; T-031
  and T-032 cite it.
- **Status:** done
- **Commit:** `0a5d908`

## T-031 — First matrix run red: root cause and portability corrections

- **Description:** Fix what made and would next make the matrix red, per
  ADR-0025: check out with `fetch-depth: 0` in `gate.yml` (the actual
  failure — a depth-1 clone resolves no historical hash, and also silently
  guts drift's superseded history walk); normalize the three ERE interval
  expressions inside awk programs (`drift.sh` done-task scan, `orient.sh`
  next-task and disagreement scans) to the longhand check 5 already uses;
  rewrite the two GNU-only `sed -i` uses in `scripts/gate-regression.sh`
  portably for BSD sed. Everything else the awk/sed/grep audit of `gates/`,
  `hooks/` and `scripts/` examined was found portable and left untouched.
- **Acceptance:** gate and all three regression suites pass locally; the
  full matrix goes green on the next push; no behaviour change on any
  input on any platform already working — correction, not amendment, §6
  ratchet n/a.
- **Status:** done
- **Commit:** `8cd379f`

## T-032 — Guard the check 5 / drift.sh duplication

- **Description:** `drift.sh` duplicates check 5's done-task scan
  deliberately (it also runs standalone), and the copies drifted in regex
  dialect with nothing comparing them (ADR-0025). Add assertions to
  `scripts/gate-regression.sh` that the gate (check 5) and standalone
  `drift.sh` rule the same `TASKS.md` fixtures identically: a done task
  with a resolving hash passes both; a hashless done task fails both; a
  fabricated hash fails both. T-029's pattern — an assertion inside the
  existing suite, not a new check.
- **Acceptance:** the assertions run in the suite and fail if either copy
  diverges again on those fixtures; extraction into `gates/lib.sh` stays
  the recorded fallback if they do (ADR-0025's alternatives).
- **Status:** done
- **Commit:** `5759381`

## T-034 — LICENSE

- **Description:** There is no license file, which legally means
  all-rights-reserved and blocks anyone at a company from touching the
  repository. Add MIT at the repo root, copyright Andrew Fitzpatrick. No
  per-file headers — a header in every file is 60 copies of one fact with
  one maintainer.
- **Acceptance:** `LICENSE` exists at the repo root, MIT, correct holder and
  year; named in `CLAUDE.md`'s structure block; no behaviour change and no
  per-file headers added.
- **Status:** done
- **Commit:** `7c955ef`

## T-035 — Declare `version` in `plugin.json`

- **Description:** Per ADR-0026, set `"version": "0.1.0"` in
  `plugins/governed-dev/.claude-plugin/plugin.json`, superseding ADR-0001's
  omission on the distribution question only. Correct every passage that
  documents the omission as deliberate — `README.md`, `CLAUDE.md`, and
  `.claude/settings.json`'s `_WHY_THIS_EXISTS` — since all three become
  false on that commit.
- **Acceptance:** the version is declared in exactly one place (the
  marketplace entry stays versionless); no `DESIGN.md` constraint or gate
  check references the field's absence, verified by grep rather than assumed,
  so this stays a correction plus a scoped supersession and needs no
  `/amend`; gate and all three suites pass.
- **Status:** done
- **Commit:** `929743a`
- **Premise corrected while doing it (ADR-0026):** this was requested on the
  grounds that omitting `version` is what makes installs "go stale
  silently". Checked against the plugin documentation: omitting it makes the
  version the commit SHA, and such an install *does* move on
  `/plugin update`; declaring one makes the freeze absolute until the field
  is bumped. The change is still right — a published tool needs a version
  that is a claim — but for ADR-0001's own stated reason, not that one. Also
  corrected two stale `README.md` claims found in passing: seven gate checks,
  not six, and the agents/skills/hooks are built, not in progress.
- **Open follow-up:** `claude plugin validate --strict` was **not run** — the
  `claude` CLI is not installed on this machine. Whether declaring a version
  makes `--strict` pass is therefore unverified, and is recorded as unverified
  rather than claimed. Run it on a machine that has the CLI and record the
  actual output here.

## T-036 — Tag v0.1.0

- **Description:** After T-034 and T-035 land and the matrix is green **on
  the tagged commit**, tag `v0.1.0` and push the tag. Add one sentence to
  `README.md`'s install section covering tag-pinned installs and what
  updating requires.
- **Acceptance:** the tag points at a commit whose own matrix run is green —
  not at a commit that merely descends from a green one; the README sentence
  states only documented syntax; run id recorded here.
- **Status:** done
- **Commit:** `6b336a6`
- **Tagged (2026-08-11):** annotated tag `v0.1.0` on `b8c1668`, pushed to
  `origin`. That commit's **own** matrix run is `31536948947` — green on
  ubuntu, macos and windows. The README sentence uses the `#<ref>` git-URL
  form, which is the syntax the plugin documentation shows; the
  `owner/repo#ref` shorthand is **not** documented and was deliberately not
  used, since a shorthand that silently resolves to the default branch would
  hand a reader a pinned-looking install that is not pinned.

## T-037 — README: what using devseed actually looks like

- **Description:** `README.md` explained what devseed is, how to install it,
  and the dual-role filename trap, but never showed a working day. A stranger
  who installed it got the hooks, the roster and the gate with no picture of
  the loop. Add one "A working session" section between "What you get" and the
  dual-role warning — bootstrap's interview and outputs, `/task`'s four-agent
  loop to a commit, what happens at a spec gap, and `/resume` the next
  morning — plus a "What this does not do" paragraph drawn from §5's Known
  limits and the open SG entries.
- **Acceptance:** every sketch matches what the skills actually do, read
  first rather than recalled; the section is under 40 lines and the README
  under 180; the limits paragraph names SG-0005's unbounded main thread, the
  declared-tooling trigger on checks 1–3, the syntactic shell boundary, and
  ADR-0024's reviewer/auditor `Bash` acceptance.
- **Status:** in-progress
- **Commit:** —
- **T-023 was already closed** (`25bc1ca`) — it covered the original README:
  what devseed is, the install pair, the Windows prerequisite, namespacing,
  and the root-vs-templates warning. Showing the loop was never in its
  acceptance criteria, so this is new work under a new id rather than a
  reopening. Section measured 39 lines, README 134.

## T-038 — Complexity audit before 0.1 (subtraction audit)

- **Description:** The complement of T-028's self-audit. That one asked which
  DESIGN.md rules lack checks (enforcement gaps); this one asks which checks
  lack justification (enforcement excess). Score every enforcement mechanism —
  each gate check, each hook, each mirror and its parity check, the boundary's
  shell inspection, the circuit breaker, `audit.yml`, and each `drift.sh`
  sub-check separately — on three questions answered from the record: what
  real failure it exists to catch, whether it has ever fired outside its own
  regression suite, and how plausibly it blocks a correct change.
- **Acceptance:** one ADR carrying the inventory with verdicts (keep /
  keep-but-simplify / remove) and a false-positive ranking; the mirrors
  re-justified from scratch rather than defended; ADR-0023's findings cited
  where they overlap rather than re-litigated; **no new mechanism, check or
  file created** to resolve any finding; removals proposed to the human, not
  executed.
- **Status:** done
- **Commit:** `9f8cd3c`
- **Premises corrected from the record (ADR-0027):** two of the three
  motivating claims did not survive checking. `drift.sh` did not produce the
  repository's only production bug — the mawk defect was latent and never
  fired (ADR-0025); the red CI run was `gate.yml`'s shallow clone. And no
  TMPDIR/scratch-probe ledger truncation exists anywhere in the record: no
  commit has ever cut more than fifty lines from any ledger, and both grew
  monotonically this session. No finding was built on either.

## T-039 — Execute the subtraction audit's three removals

- **Description:** ADR-0027 sent three mechanisms to the human; all three came
  back REMOVE (decision of 2026-08-11, final). Delete `.github/workflows/`
  `audit.yml`; delete `drift.sh`'s duplication sub-check; delete the
  git-history deletion walk from `check_superseded` while keeping ADR-number
  contiguity. Record what each was watching for so a future reader sees a
  decision rather than an oversight. Separately, correct ADR-0027's claim
  that the TMPDIR incident has no evidence — it does — and add the §5 Known
  limits entry for the seam that let the wrong claim travel.
- **Acceptance:** the two check-table removals routed through `/amend` per §6
  (they are loosenings) and the Known-limits additions through the correction
  path, with each route named; ADR-0028 records the removals, the evidence,
  and what is now unguarded; ADR-0027 forward-linked rather than edited;
  `CLAUDE.md` updated in the same commit so the migration does not ship the
  staleness the drift guard exists to catch; gate and all three suites pass;
  full matrix green.
- **Status:** done
- **Commit:** `d1bc2ea`
- **§6 route note:** the removals rest on §6's **quarterly-self-audit clause**
  ("rules that have never fired… a dead rule kept on the books teaches readers
  that rules here are decorative"), not on its specific-incident clause, which
  is written for amending a rule that failed and does not cover subtracting
  one that never fired. Named in ADR-0028 so the route is auditable.

## T-040 — One file per ADR; DECISIONS.md becomes a generated index

- **Description:** `DECISIONS.md` reached 2,499 lines holding 28 ADRs, and
  every session resolving one citation paid context for all of it. Split each
  ADR into `docs/adr/NNNN-short-slug.md` preserving numbering exactly; make
  `DECISIONS.md` a generated index (id, status, title) plus the hand-written
  "Spec gaps observed" section inline. Add the lifecycle rule to
  `.claude/rules/ledger.md` — archival is a `git mv` into `docs/adr/archive/`,
  ids resolve from either directory forever, the scribe owns the moves — and
  name its enforcing check in the rule's own text per ADR-0023's discipline.
- **Acceptance:** every `ADR-NNNN` citation in the repository still resolves;
  the gate never runs the generator (verification only — the rule T-030 tests
  in CI), so drift calls its `--print` mode and compares; `gate-regression.sh`
  gains two cases (a citation resolving to an archived ADR passes, one
  resolving to nothing fails); `docs/adr/` is in the scribe's writable set and
  the implementer's denied set in both mirrored copies; `CLAUDE.md`'s
  structure block updated in the same commit; gate and all three suites pass;
  full matrix green.
- **Status:** done
- **Commit:** `f238b84`
- **Routes used, per §6:** all corrections, no amendment. Adding the
  index-parity check is a **tightening**, which the ratchet exempts from the
  ADR bar and records as a correction to §5's table. The four DESIGN.md
  passages naming `DECISIONS.md` as the ADR location — including §6's own
  "recorded in `DECISIONS.md`", which the migration made literally false —
  changed storage, not obligation, so they went the correction path too.
  `/amend` was not needed and was not run.
- **Found before shipping:** on a fresh Windows checkout `DECISIONS.md` is
  CRLF while the generator emits LF, so the parity check would have failed the
  windows leg on a clean tree. Both sides now strip CR before comparing. First
  time this cross-platform class was caught before the matrix rather than by
  it (compare ADR-0025).
- **Two pre-existing heading bugs fixed in passing:** ADR-0020 and ADR-0021
  had titles wrapped across two lines, which markdown renders as a heading
  plus a stray paragraph and which truncated their index rows. Joined.

## T-041 — Autopilot: the driver loop above `/task`

- **Description:** The human is currently the transport layer between sessions,
  hand-carrying output the repository already holds — and twice the carried
  summary disagreed with the repository (a stale todo list; a fix reported done
  that was not on `main`). Build `scripts/autopilot.sh`, a bounded driver that
  runs `/task` headless over the `todo` queue and **routes on the gate's
  verdict instead of transporting the worker's account of it**: work that agrees
  with the spec proceeds unattended, disagreements stop the loop and surface.
  Wrap it in an `/autopilot` skill. The gate is the router — it is already the
  single definition of agreement, and autopilot adds no second opinion on it.
- **Acceptance:** preflight refuses a dirty tree, a failing gate, and `main`
  without `--create-branch`; the worker is invoked with the interactive flow's
  permissions and **no widened allowlist**; routing is agreement → digest and
  continue, new `SG-NNNN` / anything `/amend`-shaped / a question for the human
  → stop (spec), gate exit 2 → one retry with the gate's findings appended then
  stop (three strikes per task, ADR-0008's counter pattern), anything else →
  stop; at most `--max-tasks` (default 3) per invocation; every stop and the run
  cap write `reports/autopilot-DATE.md` in the fixed order DECISIONS NEEDED /
  COMPLETED WITHOUT YOU / RUN LEDGER, and print its path. Autopilot never edits
  `DESIGN.md`, never runs `/amend`, never resolves an `SG` entry, never pushes,
  never merges, and commits nothing but its own report. `scripts/autopilot-regression.sh`
  covers agreement-continues, SG-stops, gate-failure-retries-once-then-stops,
  run-cap-stops, dirty-tree-refuses, `main`-refuses, and runs in `gate.yml`
  beside the other three. ADR recorded; gate and all four suites green.
- **Status:** done
- **Commit:** `b6003aa`
- **Three reconciliations, named because they deviate from the instruction:**
  (1) *"the task's hash recorded"* cannot mean `done` + hash, because `/task`
  deliberately leaves a task `in-progress` — a commit cannot contain its own
  hash. Agreement therefore reads the `Task-Id:` trailer (T-027), falling back
  to `done` + resolving hash. (2) *"create autopilot/DATE if needed"* is
  implemented behind `--create-branch`; being on the default branch is
  otherwise a refusal, because moving someone's HEAD unasked is the improvised
  state ADR-0028 records. Both branch behaviours have cases. (3) the worker is
  driven as `/task`, not `/governed-dev:task`, wherever the local mirror
  exists — driving the installed copy would run a plugin pinned at install
  time, which is what ADR-0016 exists to avoid. Overridable by
  `AUTOPILOT_TASK_SKILL`.
- **Not verified:** no `claude` CLI on this machine, so the suite stubs the
  worker and runs the real gate. The router is tested; that
  `claude -p "/task T-NNN" --output-format json` behaves as assumed is not.
  Give the first real run explicit ids and `--max-tasks 1`.

## T-042 — Compress `CLAUDE.md` back under the warning mark

- **Description:** `CLAUDE.md` has been past the 250-line warning mark since
  before T-041 (268 lines at that point, 276 after it, against a 300 ceiling),
  so every gate run prints a warning nobody acts on — which is how a guard
  trains its readers to skip its output. T-041 compressed what its own change
  made redundant and stopped there rather than mixing a restructure into a
  feature commit. Do the pass properly, routing detail by the compression
  protocol's table: constraints to `DESIGN.md`, rationale to a `docs/adr/`
  entry, per-directory mechanics to that directory's `README.md`, pending work
  here, superseded state deleted outright.
- **Acceptance:** `CLAUDE.md` at or under 250 lines with no fact lost — every
  removed passage either moved to its owning document with a one-line pointer
  left behind, or was superseded state git already holds; the gate reports no
  drift warning; the structure block still names every top-level directory.
- **Status:** todo
- **Commit:** —

## T-043 — `templates/TASKS.md` documents a state the gate rejects

- **Description:** The shipped template's Conventions section sanctions
  `Commit: pending` for a task marked `done`. Check 5 exits 2 on exactly that
  state. The correction was made in devseed's own `TASKS.md`, in
  `agents/scribe.md`, and in `DESIGN.md` §5, and never propagated to the
  template, so every bootstrapped project inherits the pre-correction
  convention and is blocked on its first completed task by a failure message
  instructing it to record a hash that does not exist yet.
- **Acceptance:** the template's Conventions bullet describes the two-commit
  flow and names check 5 as the enforcer; the word `pending` appears in the
  template only as a value the gate rejects, if at all; a `TASKS.md` written by
  following the template verbatim passes check 5; all four regression suites
  still pass.
- **Status:** done
- **Commit:** `c2a03bb`

## T-044 — Drift check 1 tests the filesystem, so it passes locally and fails on every clone

- **Description:** `drift.sh`'s `check_staleness()` and the glob branch above
  it both gate on `[ -e "$path" ]`. Existence on disk is not portability: a
  path that is untracked, un-ignored, and present only on the author's machine
  satisfies `-e` for him and is absent for everyone else. Observed live — a
  bootstrapped project's structure block named `install.cmd` and `claude`, both
  untracked and un-ignored, and the gate was green locally while exiting 2 on a
  fresh clone. §5's CI-parity rule already names this class: a local/CI
  disagreement is a defect in the gate. The direction is the dangerous one, a
  false green for the person most likely to act on it. Test tracking with
  `git ls-files --error-unmatch` before falling back to existence, preserving
  the `.gitignore` exemption that `.claude/in-flight.md` and
  `.claude/.hook-state/` depend on. This is a tightening under §6's ratchet and
  proceeds without an ADR; the §5 check-7 table row it touches is then updated
  as a correction.
- **Acceptance:** a `CLAUDE.md` naming an untracked, un-ignored path that
  exists on disk exits 2, with a message naming all three resolutions (commit
  it, gitignore it, or delete the line) and stating why the condition is a
  problem; a tracked path still passes; a gitignored path still passes,
  including one absent from disk; an absent un-ignored path still fails as
  before; the same treatment is applied to the glob branch;
  `gate-regression.sh` gains coverage for the untracked-but-present case; all
  four regression suites pass; `DESIGN.md` §5's check-7 table row says the path
  must be committed.
- **Status:** in-progress
- **Commit:** —

## T-045 — `templates/DESIGN.md` §5 and §6 ship as skeletons, which deadlocks the consumer

- **Description:** The template ships §6 as a comment ending "Until this
  section is written, there is no sanctioned path for editing this document",
  while its own header says changes to the file go through §6 and nothing else,
  and `skills/amend/SKILL.md` says it executes §6 in §6's order. The only
  sanctioned route to editing DESIGN.md requires §6, and writing §6 requires
  editing DESIGN.md. Observed live — bootstrap correctly disclosed two of its
  own inferences and pointed at §6 to overturn them, and §6 was empty. §6 is
  mechanism, not opinion: it is the procedure `/amend` implements, and `/amend`
  ships to every consumer. Hand-inventing it produces a second amendment
  procedure with no maintainer, diverging from the skill that actually runs —
  the same argument bootstrap already makes about not generating a second
  `gate.sh`. §5 gets the same treatment by the same reasoning, decided with the
  human and recorded in the ADR this task writes: seed the gate's mechanism,
  prompt for the project's own build rules. A skeleton section is currently silent and should cost
  something, so bootstrap records a spec gap for every section it leaves
  skeletal.
- **Acceptance:** a freshly bootstrapped project has a §6 `/amend` can execute
  without further human input, and `/amend` run immediately after bootstrap
  reaches its first real question rather than refusing for want of a procedure;
  §5 ships the seeded gate mechanism (exit-code contract, "a check that cannot
  run is a failed check", CI parity, the seven-check table, the conventions the
  gate depends on) with the project's own build rules left as a prompted slot;
  both sections state their relationship to the shipped procedure, including
  that a project which rewrites them takes on maintaining both;
  `bootstrap/SKILL.md` instructs an `SG-NNNN` entry under "Spec gaps observed"
  for every section left skeletal, naming the section, what it does not say,
  what is unenforced or unreachable while it stays empty, and the shape of a
  resolution; no devseed-specific id, date, or path appears in the seeded text;
  `bootstrap-regression.sh` covers the seeded §6 and §5 and passes, and its
  existing check that no shipped template cites a devseed ADR or SG number
  still passes; a new ADR at the next free number records the decision with the
  rejected alternative (interviewing for §6) and what seeding makes harder; all
  four suites pass.
- **Status:** todo
- **Commit:** —

## T-046 — `drift.sh`: batch the per-item spawns

- **Description:** Every expensive drift sub-check spawns one or more processes
  *per item* where one process for the whole batch would do. Measured on the
  development machine (Windows 11, Git Bash, Defender real-time already off —
  this is MSYS2 fork emulation): a spawn costs ~100 ms, ~170 ms for `git`,
  against ~1–2 ms on Linux. `check_orphans` 68.0 s (one `grep` plus `sort` per
  tracked file, 224 spawns, plus an `ls` per citation, 257–500);
  `check_superseded` 8.6 s (a `printf` piped to `grep -q` per ADR number to
  answer set membership, 60 spawns); `check_staleness` 10.8 s
  (`git check-ignore` per path, 64). Item counts are small; spawn counts are
  not. No check does too much work — every expensive check does its work in too
  many processes, which is why batching changes no verdict. Same
  works-on-my-machine direction as T-044, one layer down: invisible to a Linux
  author, paid by every Windows consumer on every turn. `check_budget` and the
  three parity checks are already cheap and are out of scope. Two ordering
  semantics must be preserved exactly, both verified against the current code
  rather than assumed: the per-file `sort -u -t: -k2` dedupes by **id**, so a
  repeated citation in one file is reported once at the lexically smallest
  `line:id`, and it orders findings **by id, not by line**.
- **Acceptance:** byte-identical stdout, stderr and exit code, CR stripped,
  against a pre-change capture over twelve fixtures — devseed clean, the inline
  `DECISIONS.md` layout, the per-file layout with an archive, all four
  `check_staleness` states, an untracked glob, orphan ADR and SG citations, an
  ADR numbering hole, and done tasks with missing and fabricated hashes; the
  four-state staleness verdict from T-044 unchanged; both ADR layouts still
  handled; `DECISIONS.md` and `activity.jsonl` still excluded from the citation
  scan; binary files skipped explicitly rather than emitting "Binary file
  matches" into the parse; no `ENDFILE` and no ERE interval expressions
  (ADR-0025 — the CI matrix runs mawk); all four regression suites green;
  full-gate wall-clock before and after recorded in the closure note.
- **Status:** in-progress
- **Commit:** —

## T-047 — `rebuild-adr-index.sh`: one pass, not fourteen per ADR

- **Description:** The generator extracts id, title and status with three
  `sed` piped to `head` pairs, two or three `grep`s for the superseded parsing,
  and an `ls` piped to `head` for the path — roughly 10–14 spawns per ADR file,
  about 390 across the thirty, 38.9 s measured in isolation. `check_adr_index`
  runs the generator's `--print` mode to verify the committed index, so the
  generator's cost is the check's cost: 50.0 s, 35 per cent of the gate. Replace
  the per-file extraction with a single `awk` pass over `docs/adr/*.md` and
  `docs/adr/archive/*.md` emitting id, status, title and path, with the
  superseded-status parsing moved into the same program. The generator remains
  the single implementation of the derivation — this changes how it reads, not
  what it derives.
- **Acceptance:** `bash scripts/rebuild-adr-index.sh --print` byte-identical to
  the pre-change capture, CR stripped; the same command diffed against
  `DECISIONS.md` is empty CR-insensitively, so the committed index is unchanged;
  the three status classes (active, superseded in part, superseded by ADR-NNNN)
  still resolve as before; archived ADRs still resolve and still occupy their
  numbers; no `ENDFILE` and no ERE intervals (ADR-0025); all four suites green;
  before and after wall-clock in the closure note.
- **Status:** todo
- **Commit:** —

## T-048 — hooks: one `jq` per event, and the encoding landmine

- **Description:** `hook_field()` pipes the event JSON into a fresh `jq` on
  every call. `boundary.sh` calls it four times plus the `hook_root`,
  `hook_state_dir` and slug helpers — roughly 17 spawns before it does any
  thinking, 1.7 s on every Edit, Write, NotebookEdit, Bash and PowerShell call
  in every governed session. This is the change a consumer feels most, because
  it is per-keystroke rather than per-turn. Three parts. First, a
  `hook_fields()` that extracts every needed field in one `jq` invocation;
  `hook_field()` stays for single-field callers. Second, the encoding hazard,
  verified rather than supposed: a command string may contain literal tabs and
  newlines, boundary decisions are made on that text (ADR-0013), and
  `jq -r` with `@tsv` escapes both into backslash sequences that a naive
  read-split does not undo — a command containing a tab and a newline comes back
  as a different string and would be ruled on differently. A delimiter-safe
  encoding is required. Third, `boundary.sh` line 57 is
  `[ -n "$AGENT" ] || exit 0`: an absent `agent_type` means the main session,
  which is allowed unconditionally (SG-0005) — and it is allowed *after* three
  `jq` spawns it never needed. Reading `agent_type` first and exiting before
  extracting anything else makes the dominant path cost one `jq`. SG-0005's
  marker and reasoning are unchanged; only their cost is.
- **Acceptance:** all 81 `boundary-regression.sh` cases pass unchanged; a new
  case covering an event whose command contains a literal tab and a literal
  newline asserts the boundary reads the command intact and rules on it
  identically to the pre-change code; the main-session allow path invokes `jq`
  once and the count is stated in the commit message; no verdict changes for any
  input; per-call wall-clock before and after in the closure note, noting that
  `bash` startup alone costs about 100 ms here so sub-300 ms is not reachable.
- **Status:** todo
- **Commit:** —

## T-049 — `gate-regression.sh`: capture once, assert many

- **Description:** `run_drift` re-invokes `drift.sh` for every assertion, so
  asserting N things about one fixture costs N full runs. T-044's cases run it
  four times against a single unchanged fixture to check four substrings of one
  message; three of those runs are waste, and the pattern invites more of the
  same. Run once, capture stdout, stderr and the exit code, then assert the exit
  code and N substrings against the captured text. No fixture changes and no
  assertion changes — the same strings are checked against the same output,
  produced once instead of N times. The suite also inherits T-046 and T-047
  underneath it.
- **Acceptance:** identical pass and fail case counts across all four suites
  before and after; the gate and drift invocation count in `gate-regression.sh`
  stated before and after; total suite wall-clock before and after recorded; no
  fixture and no asserted string altered.
- **Status:** todo
- **Commit:** —

## T-050 — Parallel regression-suite runner

- **Description:** The four suites run sequentially and cost 799 s together
  (`autopilot` 384, `gate` 235, `boundary` 137, `bootstrap` 43, measured before
  T-046). They use PID- and `mktemp`-scoped work directories
  (`gate-regression.sh` line 16, `autopilot-regression.sh` line 28,
  `bootstrap-regression.sh` line 31), which makes concurrent execution *look*
  safe. That is an assertion tested nowhere, and establishing it is this task's
  first job, not an assumption to build on. Filed separately from T-046 to T-049
  deliberately: those are subtractive — the same work in fewer processes, proved
  byte-identical against a capture — whereas a runner is new harness code, and
  new harness code validated on one machine is the class that produced the
  Linux-only interval regex (ADR-0025) and the `TMPDIR` incident (ADR-0028).
  Batching must land and be measured before concurrency shares a diff with it.
- **Acceptance:** written when the task is started, not now.
- **Status:** todo
- **Commit:** —
