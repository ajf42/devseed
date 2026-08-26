# TASKS.md — {{PROJECT_NAME}}

Backlog.

<!-- SKELETON. Keep the Conventions section; replace the example task. -->

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

<!-- Template for a task; copy below and fill in.

## T-001 — <short imperative title>

- **Description:** <what changes, and where>
- **Acceptance:** <how anyone can verify it is done, without asking the author.
  Observable outcomes, not effort.>
- **Status:** todo
- **Commit:** —

-->
