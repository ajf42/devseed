---
name: adr
description: Capture an architectural decision in DECISIONS.md. Interviews for the context and the alternatives that were actually rejected, then delegates the write to the scribe. Refuses to write an entry with no rejected alternatives. Use when a choice has been made that someone could reasonably have made differently.
allowed-tools: Read, Grep, Glob, Agent
---

You capture a decision that has already been made. You do not make it, and you
do not write it — the scribe does.

`allowed-tools` above pre-approves these tools; it is **not** a boundary and
grants no protection. Omitting `Write` and `Edit` from it removes their
pre-approval, **not** the capability — a skill runs on the invoking thread,
which still holds them, and the main thread carries no `agent_type` so the
`PreToolUse` boundary does not bind it either.

So the separation here is **convention, kept by you**: the agent that makes a
decision never writes the record justifying it, and interviewing for a decision
is close enough to participating in one that the separation is worth keeping.
Delegate the write to the scribe, whose missing `Write` *is* a real capability
boundary. Do not write `DECISIONS.md` yourself because you can.

## First, is it an ADR at all?

Route it before writing it:

- **"We will use X"** — a decision, and a decision someone could reasonably have
  made otherwise. That is an ADR.
- **"Implement X"** — a task. `TASKS.md`.
- **"X is true right now"** — current state. `CLAUDE.md`.
- **"X should always be true"** — spec. `DESIGN.md`, and that is an amendment,
  not an ADR.
- **Genuinely undecided** — not a decision at all. It is a spec gap, and belongs
  under "Spec gaps observed" as `SG-NNNN`. Say so and stop.

## The interview

Read `DECISIONS.md` first for the house format and the next unused number.
Numbering is permanent and never reused.

Ask for, and do not accept a gesture at:

- **Context.** What was true, what was in tension, and why doing nothing was not
  available. A decision with no forcing condition is a preference.
- **The alternatives, and why each was rejected.** The specific cost or failure
  mode — not "it was worse". Include options that were rejected on constraints
  that may later change, since those are the ones worth revisiting.
- **Consequences, including the costs accepted.** An entry whose consequences
  are all upside is incomplete and reads as advocacy rather than record.

**Refuse to write an ADR whose alternatives-considered section is empty.** An
ADR that names only the option taken is a changelog entry wearing a costume: it
records that something happened, not that a choice was made, and the next reader
has no way to tell whether the reasoning still holds. If the human says there
were no alternatives, that is usually a sign it was not a decision — offer
`CLAUDE.md` or `TASKS.md` instead.

**Never invent an alternative to fill the section.** A fabricated rejection is
worse than an absent one, because it reads as evidence that a path was
considered and closed when nobody ever walked it, and the next reader will trust
it.

## The write

Delegate to **scribe**. `DECISIONS.md` already exists, so `Edit` suffices — the
scribe holds `Read` and `Edit` and no `Write`, and cannot create files.

Hand it the interview answers, not a drafted entry. Formatting the entry is its
job and it knows the house format.

Rules it will hold you to, worth knowing before you ask:

- **Append to the bottom.** Reading top to bottom is reading chronologically.
- **Superseded entries are marked, never deleted.** Set the old `Status:` to
  `Superseded by ADR-NNNN` and change nothing else. The superseding entry names
  what it replaces and why. A reversed decision is evidence about how this
  project reasons; deleting it makes the reversal invisible.
- **A change to reasoning is a new entry**, not an edit to an old one. Typo and
  link fixes in place are fine.

## After

Report the number assigned and where it landed. Do not commit — `/task` owns
commits.
