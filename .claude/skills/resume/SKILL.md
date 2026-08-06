---
name: resume
description: Reconstruct working state after an interruption, compaction, or a fresh session. Runs the orientation script, reads the ledger, and reports what is in flight and what is inconsistent. Changes nothing. Use at the start of a session, or whenever you have lost the thread.
allowed-tools: Read, Grep, Glob, Bash
---

You rebuild the picture of where this project stands. **You change nothing** —
not a file, not a status, not a stale line you happen to notice.

`allowed-tools` above pre-approves these tools; it is **not** a boundary. The
read-only discipline here is yours to keep, and it matters: a resume that
tidies as it reads destroys the evidence it was invoked to gather.

## What to read

1. **Run the orientation hook script** — `hooks/orient.sh`, the same one
   `SessionStart` runs. It reports the branch, the working tree, recent commits,
   the first task with no recorded hash, and any state disagreement it detects.
   Locate it the way the hooks do: `${CLAUDE_PLUGIN_ROOT}/hooks/orient.sh` when
   running from an install, otherwise `plugins/governed-dev/hooks/orient.sh`
   relative to the repository root.
2. **`.claude/in-flight.md`**, if it exists. The `PreCompact` hook writes it, so
   its presence means a session was compacted mid-work and this is the record of
   what it was halfway through. It is git-ignored, so it does not survive a
   clone.
3. **The ledger** — `CLAUDE.md` for what exists, `TASKS.md` for what is in
   flight and what is next, `DECISIONS.md` for open spec gaps.

Read the ledger, not the codebase. The point of this system is that these
documents are sufficient to resume from; exploring the code instead both wastes
the session and hides it when they are not.

## What to report

- What exists, in a few lines — from `CLAUDE.md`, not rediscovered.
- What is **in progress**, and what the next unstarted task is.
- **Open spec gaps**, by id. These are the questions the project is currently
  building on top of without an answer, and they are the most likely thing to
  have been forgotten across the interruption.
- Anything **inconsistent**, quoted from each source.

## The one hard rule

**Do not infer past a disagreement.** If `TASKS.md`, git history, and the
filesystem do not agree about what has happened — a task marked `done` with no
commit, a commit that closed a task nobody updated, a dirty tree with nothing
in progress — **report it and stop.**

Quote what each source claims and ask which is wrong. Do not pick the most
plausible reading and continue on it; do not edit one record to match the other.
That choice is the human's, and reconciling it silently buries a decision they
never got to make — which is exactly the drift this project exists to catch,
committed by the tool built to detect it.

A disagreement is a finding. Reporting it *is* doing the job, not failing at it.
