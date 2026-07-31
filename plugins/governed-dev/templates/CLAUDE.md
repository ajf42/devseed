# CLAUDE.md — {{PROJECT_NAME}}

> **Line budget: target 200, hard ceiling 300.** This file is working memory,
> not an archive. It is read in full every session; every line spends context
> that belongs to the task. See "Compression protocol" before adding.

<!-- SKELETON. Replace the guidance in each section with this project's real
     content. Delete the HTML comments as you go. Do not delete the line
     budget or the compression protocol. -->

## How this relates to DESIGN.md

`DESIGN.md` says what this system **should be**. This file says what it **is
right now**. Spec questions resolve against DESIGN.md; current-state questions
resolve against this file.

This file is expected to go stale — code moves faster than notes. Ordinary
staleness is corrected in place, no ceremony. But if the two documents describe
*incompatible systems* rather than the same system at two points in time, that
is not staleness. Stop and surface it rather than reconciling silently.

Never edit DESIGN.md to match drifted code: that converts an accident into a
sanctioned constraint.

## Current state

<!-- What exists and works, what is stubbed, what is known-broken. Be specific
     enough that a fresh session does not need to explore to find out. Prefer
     "X works, Y is a stub returning fixed data" over "X and Y are in
     progress". -->

**Built and working:**

**Not built yet:**

<!-- Also record any fact that has already bitten someone twice — the
     non-obvious gotcha that is not discoverable by reading the code. -->

## File structure as it stands

```
<!-- A tree of the directories that matter, one line of purpose each. Not
     exhaustive: omit anything a reader can infer. Update when it changes. -->
```

## Build rules

Defined in **`DESIGN.md` §5**, not here. Do not restate them — a copy that
drifts from its source is worse than a pointer.

## Compression protocol

When a change would push this file past **300 lines**, compress *before*
continuing the change. Do not commit an over-budget file with a note to clean
it up later.

Route the detail by what it is:

- **Spec** — a constraint or intent, something that should be true → move to
  `DESIGN.md` via its amendment procedure. Leave a one-line pointer here.
- **Rationale** — why a choice was made → move to `DECISIONS.md` as an ADR.
- **Local mechanics** — how one directory works → move to a `README.md` in
  that directory, linked from the file-structure block above.
- **Pending work** → move to `TASKS.md`.
- **Superseded state** → delete it. This file is not an archive; git holds the
  history.

The budget is the point, not an aspiration. A CLAUDE.md that grows without
bound stops being read carefully, and an unread current-state record is worse
than none: it looks authoritative while nobody checks it.
