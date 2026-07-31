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

## T-006 — Prompt 5

- **Description:** Not yet specified. Placeholder so numbering matches the
  prompt series; criteria to be written before work starts.
- **Status:** todo

## T-007 — Scribe agent

- **Description:** Build the scribe agent at
  `plugins/governed-dev/agents/`, which writes DECISIONS.md entries so future
  ADRs are not hand-written.
- **Acceptance:** Agent exists with a bounded scope; appends ADRs in the format
  defined in DECISIONS.md; never rewrites or deletes existing entries.
- **Status:** todo (Prompt 6)

## T-008 — Bootstrap skill

- **Description:** Build `plugins/governed-dev/skills/bootstrap`, which seeds a
  target project from `plugins/governed-dev/templates/`.
- **Acceptance:** Sources documents from `templates/` rather than generating
  prose; installs namespaced as `/governed-dev:bootstrap`; verified against a
  project outside this repo.
- **Status:** todo (Prompt 7)

## T-009 — Prompt 8

- **Description:** Not yet specified. Placeholder; criteria to be written before
  work starts.
- **Status:** todo

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
- **Status:** in-progress — hash recorded next commit
