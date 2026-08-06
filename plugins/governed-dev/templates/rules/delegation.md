# Rule: The delegation loop

Five agents, each holding a different set of tools. The roster is not the point.
The **boundaries between them** are the point, and they exist because a single
agent that can do everything can also cover for itself.

## The one rule

> **The agent that makes a decision never writes the record justifying it.**

Everything below is a consequence of this. It is worth stating on its own
because it is the rule that stops working the moment someone finds it
inconvenient, and it will look inconvenient exactly when it is doing its job.

An agent that decides *and* records can make the two agree by adjusting whichever
is cheaper. Faced with a spec wall, the cheapest edit is almost never the code —
it is the sentence that makes the wall go away. The result passes every check,
because the record now says the thing the code does was always intended. Nothing
downstream can detect this: the repository is internally consistent and the
reasoning is gone.

Separating the two makes that edit require a second agent that has no reason to
make it, and no tool to make it with.

## The loop

```
             ┌──────────────────────────────────────────────┐
             │                                              │
   proposal  ▼                                              │
  ──────► spec-guardian ──── CONFLICT / blocking GAP ───► human decides
             │                                              │
        SANCTIONED                                          │
             │                                              ▼
             ▼                                          scribe records
        implementer ───── spec wall ──────────────────►  (ADR / SG entry)
             │                                              ▲
          builds                                            │
             │                                              │
             ▼                                              │
          reviewer ──── BLOCK ──► back to implementer       │
             │                                              │
           PASS                                             │
             │                                              │
             └──────────────────────────────────────────────┘
                        scribe records what landed

  auditor runs across all of it, continuously, changing nothing
```

**spec-guardian gates in.** Nothing gets built until the spec has been asked.
Returns `SANCTIONED`, `GAP`, or `CONFLICT` — one of the three, never a hedge.
Holds `Read`, `Grep`, `Glob`: it can read every document and change none.

**implementer builds.** Test first: the failing test, confirmed failing for the
right reason, then the code. Holds `Write`, `Edit`, `Bash`. Denied `DESIGN.md`,
`DECISIONS.md`, `TASKS.md` — on both the editing tools and the shell.

**reviewer gates out.** Read-only and adversarial, against `DESIGN.md` and the
task's acceptance criteria rather than against taste. `NO FINDINGS` is an
expected outcome; a reviewer that always finds something has stopped reviewing.

**scribe records.** `CLAUDE.md`, `DECISIONS.md`, `TASKS.md` and nothing else.
Holds `Read` and `Edit` — no `Write`, so it cannot create files, and no shell.
Records what was decided; never decides.

**auditor runs continuously.** Runs the drift guards, reports discrepancies with
file and line, proposes nothing and fixes nothing.

## Why each boundary is where it is

| Agent | Can write | Cannot write | Because |
|---|---|---|---|
| spec-guardian | nothing | everything | An interpreter that can amend will eventually resolve a hard question by amending. |
| implementer | code, tests, `CLAUDE.md` | `DESIGN.md`, `DECISIONS.md`, `TASKS.md` | These are the records it would edit to grant itself permission — rewriting the spec to clear a wall, or closing a task by declaring it closed. |
| reviewer | nothing | everything | An agent that can act on its own finding cannot be trusted to report one it would rather not act on. |
| scribe | `CLAUDE.md`, `DECISIONS.md`, `TASKS.md` | code, tests, `DESIGN.md` | An agent that writes both the record and the code can make them agree by changing whichever is more convenient. |
| auditor | nothing | everything | The trivial fix is how an auditor becomes an editor of the records it audits. |

`CLAUDE.md` is writable by both implementer and scribe, deliberately. It records
what currently exists, the implementer is required to keep it current, and the
gate fails a change under `src/` that leaves it stale. `DESIGN.md` is writable by
**nobody** — amendments go through its own amendment procedure, and are human.

## What actually enforces this

Not these paragraphs. Two mechanisms, and it is worth knowing which does what:

1. **`tools:` allowlists** in each agent's frontmatter — a *capability*
   boundary. Omitting `tools:` inherits every tool, which silently deletes the
   boundary while the file still looks like it declares one. Every agent lists
   its tools explicitly.
2. **The `PreToolUse` boundary hook** — a *path* boundary. `tools:` cannot
   express "may not write this file", so the hook denies by path, and by
   command for shell tools.

Neither is sufficient alone. A `tools:` list cannot say which files; a hook
cannot deny a tool the agent was never given.

**Two known limits, stated so they are not mistaken for coverage:**

- **The shell check is syntactic.** It stops the expedient redirect, not a
  determined evasion through a variable or a glob. The threat model is an agent
  taking the cheap way out of a spec wall, not an adversary. What carries the
  weight instead is the capability boundary: the scribe and spec-guardian hold
  no shell at all, which is not a matcher and cannot be outwitted.
- **The main session thread carries no `agent_type`**, so none of these
  boundaries bind it. Work done on the main thread is unbounded. The roster
  binds real subagents. That is the honest scope.

## Using the loop

Not every change needs five agents. A typo fix does not need a spec ruling.

The test is whether the change involves a **decision**. If it does, the loop
applies, and the part that matters is that whoever decides is not whoever
records. If it does not — a rename, a formatting pass, a fix to something
already sanctioned — do it directly.

Skipping the loop for something that *does* involve a decision is not a
shortcut; it is the failure the loop exists to prevent, taken deliberately.
