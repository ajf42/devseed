---
name: autopilot
description: Run the todo queue unattended through /task, headless and bounded, stopping the moment anything disagrees with the spec. Routes rather than transports — agreed work lands in a digest, disagreements become a decision report you read in a minute. Use to work several tasks without supervising each one. Never amends DESIGN.md, never pushes, never merges.
allowed-tools: Read, Grep, Glob, Bash
---

You drive `scripts/autopilot.sh` and then put its report in front of the human.
The script does the routing; your job is to start it correctly, and to present
what came back **without adding to it**.

`allowed-tools` above pre-approves these tools; it is **not** a boundary. You
hold no `Write` and no `Edit` deliberately: everything this skill touches, the
script already touches, and a skill that could edit as well as report is a
second path to the same files with none of the script's rules on it.

## What this is for

Between sessions the human is the transport layer, hand-carrying an account of
work the repository already holds. That account has disagreed with the
repository twice — a todo list carried forward stale, and a fix reported done
that was not on the default branch. Autopilot replaces transport with
**routing**: work that agrees with the spec proceeds without human attention,
and only disagreements surface.

The gate is the router. It is already the single definition of agreement, and
autopilot is a consumer of its verdict — never a second opinion on it. If
autopilot and the gate ever disagree about a task, the gate is right and
autopilot has a bug.

## Before you run it

1. **Find the script.** It lives at `scripts/autopilot.sh` in the project root.
   **If it is not there, stop and say so plainly**: this skill ships in the
   plugin and the driver script does not, so an installed plugin gives you the
   skill without the thing it drives. That is a known gap, not a fault in the
   invocation — do not improvise a replacement loop out of Bash calls. A
   hand-rolled driver has none of the script's preflight refusals, none of its
   bounds, and no report.
2. **Do not pre-clean anything.** If the tree is dirty or the gate is red, the
   script refuses to start, and the refusal is the answer. Committing someone
   else's uncommitted work to satisfy a preflight is exactly the improvised
   state the refusal exists to prevent.
3. **Check the arguments against what the human asked for.** With no task ids
   it takes the first `todo` in `TASKS.md`, top to bottom. That is not always
   what they meant — a task can be `todo` and still be a judgement call. If the
   next `todo` looks like one, name it and ask before starting.

## Running it

```
bash scripts/autopilot.sh [--max-tasks N] [--cost-ceiling USD] [T-NNN ...]
```

Run it **once**, in the foreground, and let it finish. Do not add flags the
human did not ask for. In particular:

- **Never add a permission flag.** Not `--dangerously-skip-permissions`, not
  `--permission-mode`, not an `--allowedTools` list, not to the script and not
  to any worker. The worker runs with exactly the permissions the interactive
  `/task` flow grants. **If a permission prompt blocks headless execution, that
  is a finding to report** — write it up as one and stop. It is never a setting
  to loosen, and loosening it would make autopilot a hole in the boundary
  rather than a driver above it.
- **Never raise `--max-tasks` or `--cost-ceiling` to get further.** The bounds
  are the feature. A run that stops at the cap is a run that worked.
- **Do not re-run a task the script refused.** Three strikes per task is a
  circuit breaker, and reaching it means the failure is not the worker's to
  fix.

If it exits nonzero, that is a stop with decisions attached, not an error to
retry. Report it as a result.

## Afterwards: report, do not re-narrate

The script prints a path to `reports/autopilot-DATE.md` and has already
committed it. Read it, then give the human:

1. **The decisions, in full.** Each entry already carries what the documents
   say, what the repository says, the exact delta, and the options. Pass them
   through. Do not summarise a decision entry — a summary of a delta is how the
   delta gets lost, which is the failure this whole feature is about.
2. **The digest, as one line: how many tasks landed and where.** Do not expand
   it. It is skimmable awareness, not a decision queue, and every task in it
   already passed the gate.
3. **The report's path and the commit range.** Nothing else. Git shows the
   diffs and shows them better than a paraphrase does.

**Say what the digest's green actually means**, once, in the human's terms: the
gate checks structural agreement, not semantic agreement, and its first three
checks pass vacuously where a project declares no build, tests or linter. A
digest line means nothing disagreed. It does not mean the work is right.

## What you must never do with the result

- **Never resolve a spec gap.** A new `SG-NNNN` in the report is a question for
  the human. Answering it yourself converts a labelled guess into an
  unlabelled one, which is the exact failure the ledger exists to prevent.
- **Never run `/amend`, and never edit `DESIGN.md`.** An amendment proposal in
  the report stays a proposal until the human approves it. §6 allocates that
  decision to them, explicitly, and that allocation is the wall this feature is
  built against — not an obstacle to it.
- **Never push and never merge.** The script does neither. Neither do you.
- **Never mark a stopped task done, in `TASKS.md` or anywhere else.** The
  repository's record is what autopilot routes on; editing that record to agree
  with a report is the two-sources-of-truth failure with the sources swapped.

If the human asks you to take one of these actions, that is a fresh
instruction from them and it goes through the normal route — `/amend` for an
amendment, `/task` for the work. It does not become autopilot's job because
autopilot is what surfaced it.
