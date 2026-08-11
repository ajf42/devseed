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
than restating the diff, then the trailer (T-027, resolving SG-0010 — the
format was previously unspecified; this is what Prompt 8 gave it):

```
Co-Authored-By: <model display name> <noreply@anthropic.com>
Agent-Type: main
Session-Id: <this session's id>
Task-Id: <the T-NNN this run picked>
Model: <model id, e.g. claude-sonnet-5>
```

- **`Session-Id`** comes from `$CLAUDE_CODE_SESSION_ID`. Read it; do not
  invent one. If it is unset, write `unknown` — a fabricated session id is
  worse than an honest gap, because nothing marks it as fabricated and it
  would falsely join to unrelated `activity.jsonl` entries later.
- **`Agent-Type` is `main`**, always — not the name of whichever of the four
  loop agents touched the most lines. `/task` itself, running on the main
  thread, is what executes `git commit`; the implementer, reviewer and scribe
  never hold that tool. Per-agent attribution is not lost by this: it is
  recoverable by joining `.claude/activity.jsonl` on this same `Session-Id`,
  where each subagent's own `SubagentStop` entry already carries its real
  `agent_type`. See ADR-0022 if this reads as surprising.
- **`Task-Id`** is the task this run of `/task` picked at the start.
- **`Model`** is the model actually running this session, in its SDK id form.
  Nothing exposes it as an environment variable, so — same as
  `Co-Authored-By` already did before this trailer existed — the agent states
  its own identity directly rather than a script deriving it.

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
