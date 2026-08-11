# ADR-0009 — The compaction flush writes `.claude/in-flight.md`, not `CLAUDE.md`

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
