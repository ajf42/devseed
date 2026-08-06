---
name: task
description: Run one task from TASKS.md end to end through the full agent loop — spec-guardian, implementer, reviewer, scribe — then gate, commit and push. The only thing that commits. Use to work a numbered task; give it a task id, or none to take the next unstarted one.
allowed-tools: Read, Grep, Glob, Bash, Agent
---

You run one task from `TASKS.md` to a commit. You are the **only** thing in this
system that commits — the gate is verification-only precisely so that this can
own commit-and-push.

`allowed-tools` above pre-approves these tools; it is **not** a boundary. The
boundaries are the agents' `tools:` allowlists and the `PreToolUse` hook.

## Pick the task

Read `TASKS.md`. Take the task the human named, or — given none — the first with
status `todo`. Say which you picked and why before starting.

Stop if it is already `done`, or `blocked` with an unresolved blocker. Do not
pick a second task: one task per commit, and a commit closing two means one of
them was not a task.

## The loop

Four agents run *in* the loop, in order. The fifth — the **auditor** — runs
across it rather than inside it: it holds no write tools, proposes nothing, and
its guards are what the gate runs below, so putting it in the sequence would
mean running the drift checks twice and calling one of them a step. Invoke it
directly when a task touches the ledger documents or the guards themselves, and
say that you did.

**Stop and surface at any gate failure rather than retrying** — a retry past a
refusal is the loop being routed around, which is the one failure it exists to
prevent.

1. **spec-guardian** — hand it the task and its acceptance criteria. It returns
   `SANCTIONED`, `GAP` or `CONFLICT`. On `CONFLICT`, or a `GAP` it calls
   blocking, stop and put it to the human. Do not proceed under an assumption.
2. **implementer** — only once `SANCTIONED`. Test first: the failing test,
   confirmed failing for the right reason, then the code. If it reports a spec
   wall, stop; do not hand the work to a less restricted agent to finish. That
   is the boundary being laundered.
3. **reviewer** — adversarial, read-only, against `DESIGN.md` and the acceptance
   criteria rather than against taste. `BLOCK` goes back to the implementer.
   `NO FINDINGS` is a real and expected result.
4. **scribe** — records what landed in `CLAUDE.md` and `TASKS.md`, and any ADR
   the work produced. The scribe holds `Read` and `Edit` and **no `Write`**, so
   it cannot create a file that does not yet exist. If the record needs a new
   file, create it first, or the failure will look like an agent error rather
   than the wiring error it is.

## Then the gate

Run the full gate — `gate.sh`, **not** `--fast`. `--fast` is checks 1–3, for the
per-edit hook, and skips the ledger and drift checks that are the whole point
here.

**If it does not exit 0: do not commit. Do not stage.** Report its output
verbatim and stop. This mirrors the gate's own rule — a check that cannot run is
a failed check — applied to the task as a whole. Do not fix-and-rerun in a loop
without saying what you changed.

## Then commit

Only on exit 0.

Message is `<scope>: <imperative description>`, body explaining *why* rather
than restating the diff, then the trailer.

<!-- TODO(spec): SG-0010 — the trailer format was specified as "per Prompt 8 §4",
     which does not exist: Prompt 8 is CI (T-009) and has not been written.
     Assumed the convention already visible in git history rather than inventing
     a format that Prompt 8 would then have to match. Recorded in DECISIONS.md. -->

Take the trailer from what the repository already does — read `git log` and
match it. Do not invent one.

**Leave the task `in-progress`, not `done`.** A task's commit hash does not
exist until the commit completing it has been made, so it cannot be recorded in
that same commit. Recording the hash is the *next* commit's job. A task marked
`done` with no hash must fail the gate rather than be tolerated as a transient
state — that is check 5 working, not a bug to design around.

**Do not resolve this by amending.** Rewriting a commit to insert its own hash
makes the ledger's history unreproducible, which is the property the hash exists
to provide.

## Then push

**Check the branch first.**

- **On `main` or `master`:** commit locally, report the hash, and stop without
  pushing. Say plainly that direct pushes to the default branch are not
  automatic by design. Do not offer to force it.
- **On a feature branch:** push, and report the result.

**If the push fails for any other reason** — no remote configured, rejected,
diverged upstream — report the specific failure and stop. Do not retry, do not
force, do not swallow it. The local commit stands either way: a failed push is
not a failed task, but it is not silent either, and reporting success on a
commit that only exists locally is the exact dishonesty this rule prevents.
