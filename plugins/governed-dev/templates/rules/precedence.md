# Rule: Document precedence

Two documents govern this repository, and they answer different questions.

- **DESIGN.md is authoritative for what the system *should be*.** Intent, scope,
  constraints, architecture, and the rules the build must satisfy.
- **CLAUDE.md is authoritative for what *currently exists*.** The state of the
  code as it actually stands: what is built, what is stubbed, what is broken.

## On apparent disagreement

- For a **spec question** — "what should this do", "is this in scope", "what
  constraint applies" — **DESIGN.md wins.**
- For a **current-state question** — "what does this do today", "what is already
  built", "where does this live" — **CLAUDE.md wins.**

Applying the right document to the right question resolves most conflicts. Stale
state in CLAUDE.md is an ordinary, expected condition: the code moved and the
notes have not caught up. Correct it and continue.

## When to stop instead

If the disagreement is **structural rather than stale state**, stop and surface
it. Do not reconcile silently.

Structural means the two documents describe incompatible systems, not the same
system at two points in time. Signals:

- CLAUDE.md documents a component, boundary, or dependency that DESIGN.md does
  not sanction and could not sanction.
- DESIGN.md states a constraint the existing code categorically violates, such
  that satisfying it means removing or rebuilding something real.
- Both documents are internally consistent and current, and still cannot both be
  true.

In those cases the resolution is a human decision about which document is wrong.
Editing either one to match the other buries that decision. Say plainly what the
two documents claim, why they cannot both hold, and wait.

## Corollary

Never edit DESIGN.md to match code that has drifted. That inverts the direction
of authority: it converts an unsanctioned implementation detail into a
sanctioned constraint by fiat. Changes to DESIGN.md go through the amendment
procedure defined in DESIGN.md itself.
