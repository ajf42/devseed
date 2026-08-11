# ADR-0018 — `/amend` is deferred to Prompt 9 rather than built now

- **Date:** 2026-08-06
- **Status:** Accepted

### Context

Prompt 7 asked for an `/amend` skill implementing a four-part amendment
procedure. spec-guardian ruled **CONFLICT**: `DESIGN.md` §4 defers the
amendment procedure to §6 "filled in by Prompt 9", §6 says "until it is
written, there is no sanctioned path for editing this document," and the
four-part shape appears nowhere in `DESIGN.md`. T-021 already pairs the
executor with T-010 and states "the procedure and its executor are separate
tasks".

**Alternatives considered:**

- **Build it against the prompt's four-part procedure, treating the human as
  supplying §6's content.** Rejected: it makes the tool the source and §6 the
  transcription, which is the direction `precedence.md` forbids, and a
  working tool would then shape what T-010 writes.
- **Build it inert, refusing until §6 exists.** Rejected on the narrower
  ground that the artifact built to detect and refuse would still encode the
  deferred procedure, which is what §4 reserves for §6.
- **Defer.** Chosen by the human when the conflict was put to them.

### Decision

`/amend` is not built. It stays T-021, Prompt 9, paired with T-010.

### Consequences

- Prompt 7's deliverable is four skills, not five, and that is stated rather
  than quietly absorbed.
- `DESIGN.md` §6 stays a placeholder, so the repository currently has no
  sanctioned route to amend its own constitution — which is a real hole with
  a scheduled fix.
