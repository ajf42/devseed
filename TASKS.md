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
- **Status:** todo (Prompt 4)

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
- **Status:** todo (Prompt 5)
- **Note:** criteria reconstructed, not transcribed — see SG-0004.

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
- **Blocked on:** T-005. `tools:` gates which tools an agent has, not which
  files it may touch, so the path boundary needs a `PreToolUse` deny hook.
  Until that exists the boundary is documentation, and CLAUDE.md must not
  describe it as enforced.
- **Status:** todo (Prompt 6)

## T-008 — Bootstrap skill

- **Description:** Build `plugins/governed-dev/skills/bootstrap`, which seeds a
  target project from `plugins/governed-dev/templates/`.
- **Acceptance:** Sources documents from `templates/` rather than generating
  prose; installs namespaced as `/governed-dev:bootstrap`; verified against a
  project outside this repo.
- **Status:** todo (Prompt 7)

## T-009 — CI parity

- **Description:** Run the same gate in CI that runs locally, so "passes on my
  machine" and "passes in CI" cannot diverge. CI calls `gate.sh` itself, not a
  reimplementation.
- **Acceptance:** CI invokes the identical `gate.sh` — no forked copy, no
  reimplemented checks; a change that fails locally fails CI and vice versa; the
  gate's no-side-effects rule holds under CI, which is why commit-and-push lives
  in `/task` and never in the gate. Resolving **SG-0003** is a prerequisite:
  `${CLAUDE_PLUGIN_ROOT}` does not resolve where the plugin is not installed, so
  CI either vendors a copy or installs the plugin first, and that question is
  still open.
- **Status:** todo (Prompt 8)
- **Note:** criteria reconstructed, not transcribed — see SG-0004.

## T-010 — Amendment procedure

- **Description:** Fill in `DESIGN.md` §6 — how DESIGN.md itself changes, who
  may amend, what is recorded, and how an amendment differs from a correction.
- **Acceptance:** §6 is no longer a placeholder; the procedure is executable by
  a fresh session without asking; it forbids amending DESIGN.md to match
  drifted code.
- **Status:** todo (Prompt 9)

## T-011 — Make the GitHub repository private

- **Description:** `github.com/ajf42/devseed` is public; private was required.
  Needs `gh` installed and authenticated, or the GitHub web UI.
- **Acceptance:** An unauthenticated request to the repo API returns 404;
  `marketplace add` still resolves with credentials available.
- **Status:** blocked — requires human action, see SG-0002

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
- **Status:** todo (Prompt 7)

## T-019 — `/adr` skill

- **Description:** Appends a decision entry to `DECISIONS.md` in the format that
  file defines.
- **Acceptance:** Appends to the bottom; never edits or deletes an existing
  entry; refuses to write an entry whose Context names no rejected alternatives,
  since an ADR without them records a preference rather than a decision; marks
  superseded entries rather than removing them.
- **Status:** todo (Prompt 7)

## T-020 — `/resume` skill

- **Description:** Reconstructs working context for a fresh session from the
  ledger alone — the acceptance criterion T-003 was built against.
- **Acceptance:** Reads `CLAUDE.md`, `TASKS.md`, `DECISIONS.md` and reports what
  exists, what is in progress, and what is next, without exploring the codebase;
  names open spec gaps; does not modify anything.
- **Status:** todo (Prompt 7)

## T-021 — `/amend` skill

- **Description:** Executes the amendment procedure that T-010 writes into
  `DESIGN.md` §6. **T-010 currently writes §6 prose with nothing able to run
  it** — the procedure and its executor are separate tasks, and the procedure
  alone is advice.
- **Acceptance:** Executes §6's steps; records the amendment in `DECISIONS.md`;
  refuses to amend `DESIGN.md` to match drifted code, which `precedence.md`
  forbids and which is the one edit an amendment tool must not make easy.
  Distinguishes an amendment from a correction as §6 defines it.
- **Status:** todo (Prompt 9, paired with T-010)

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
- **Status:** in-progress — hash recorded next commit
