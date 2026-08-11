# ADR-0029 — One file per ADR, with DECISIONS.md generated as the index

- **Date:** 2026-08-11
- **Status:** Accepted

## Context

`DECISIONS.md` had grown to 2,499 lines holding 28 ADRs plus the spec gaps.
Every session that needed to resolve one citation paid context for all of it,
and the file grew ~23% across two sessions — 180 of those lines were
ADR-0028, the record of *removing* three mechanisms, which is the shape of the
problem: subtraction from the scripts cost more ledger than it saved code.

The record's job is to keep currently load-bearing constraints traceable. Git
is the archive. A single flat file conflates the two: it makes the whole
history a prerequisite for reading any part of it.

**Alternatives considered:**

- **Prune old entries.** Rejected outright — it is the deletion this log's
  append-only convention exists to forbid, and ADR-0028 had just removed the
  check that would have caught it. Cheapest, and the one that destroys the
  thing being maintained.
- **Split by era** (`DECISIONS-2026H1.md`). Rejected: it moves the boundary
  without removing it. A reader still loads a slab to reach one entry, and the
  cut points are arbitrary in a way per-entry boundaries are not.
- **Keep the flat file and cap entry length.** Rejected as insufficient alone,
  though the underlying instinct is right and survives: a cap squeezes durable
  constraints and one-time forensics equally, because a flat file has no unit
  to hang a cap on. Per-file makes a length rule enforceable at all — the unit
  now exists. Not adopted here; noted as available.

## Decision

Each ADR is `docs/adr/NNNN-short-slug.md`, numbering preserved exactly.
`DECISIONS.md` becomes a generated index — id, status, title, one row each —
produced by `scripts/rebuild-adr-index.sh` and carrying a generated-file
header that names the script.

Three properties made this worth doing:

1. **Retrieval cost becomes proportional to citations, not history.** Reading
   `ADR-0007` costs 56 lines, not 2,499. The index is 51 rows.
2. **Concurrent authors add files instead of colliding in one.** Two sessions
   recording two decisions touch two paths; in the flat file they contended
   for the same trailing region.
3. **Archival is a move, not surgery.** Retiring an entry is `git mv` into
   `docs/adr/archive/` — no editing of a 2,000-line file to relocate a block,
   and no risk of taking a neighbour with it.

**The "Spec gaps observed" section stays inline and hand-written**, and is
preserved byte for byte by the generator. Gaps are meant to be one short
uncomfortable visible list; scattering them into files would let the list stop
being felt, which is the only thing making anyone close them.

**The gate never runs the generator.** The gate is verification-only and
writes nothing (DESIGN.md §5) — a rule `scripts/gate-regression.sh` asserts
and, since T-030, CI runs. Drift check 5 instead invokes the generator's
`--print` mode, which writes nothing, and compares. That keeps one
implementation of the derivation rather than a second copy in the guard, which
is the failure T-032 exists to prevent.

**Ids resolve forever, from either directory.** Every citation-resolving check
searches `docs/adr/` and `docs/adr/archive/`. If retirement broke citations,
retirement would be destructive and nobody would do it.

### Multi-author id collisions

Two authors taking "the next unused NNNN" concurrently produce two `ADR-0030`s
on two branches. Nothing in git prevents it and no check here can: the collision
is invisible until the branches meet. The convention, for when it matters: **the
number is claimed by the merge, not by the writing.** The second branch to merge
renumbers — its file is renamed and its own citations updated, which is cheap
precisely because the entry is one file. Contiguity in drift check 4 catches the
hole if a renumber is botched; nothing catches the duplicate before the merge,
and that is stated rather than papered over. For a solo repository this is
theory, and it stays theory until a second author exists.

### Out of scope: multi-repo and org-level governance

**One ledger per repository.** This layout says nothing about decisions that
cut across repositories, and devseed does not enforce that layer. The intended
shape, stated so nobody infers a different one from silence: cross-cutting
decisions belong in an **org-level governance repository** with its own ADR
sequence, which service ledgers cite **by URL**. A service repository never
holds an org decision, and an org repository never holds a service one.

devseed provides no mechanism for this and does not intend to. Nothing here
resolves an org-level citation, and drift would flag one as unresolvable if it
were written as a bare `ADR-NNNN` — cite the URL instead. Building it would
mean a shared registry, cross-repo id allocation, and a check that fetches
remote state at gate time, each of which is a larger commitment than anything
in this repository and none of which is answered by evidence anyone has yet.

## Consequences

- **`DECISIONS.md` is no longer editable by hand above the spec-gaps
  heading.** An edit there survives until the next rebuild and looks
  authoritative in the meantime. The generated-file header says so, and drift
  check 5 catches it, but this is a new way to waste someone's afternoon.
- **A new coupling: the shipped gate calls a script that does not ship.**
  `drift.sh` is inside the plugin; `scripts/rebuild-adr-index.sh` is devseed's
  own dev tooling. The check therefore triggers on `DECISIONS.md`'s
  generated-file marker rather than on `docs/adr/` existing, so a consumer who
  adopts per-file ADRs without the generator is unaffected. If consumers ever
  want the layout wholesale, the generator has to move into the plugin and
  bootstrap has to seed it — not done, because no consumer has asked.
- **The spec-gaps section is now the largest hand-written part of
  `DECISIONS.md`** — 366 of its 417 lines. If growth continues it will be
  there, not in the index, and the same argument will apply to it.
- **Line-ending fragility, contained.** `.gitattributes` pins only `*.sh` to
  LF (SG-0009), so `DECISIONS.md` checks out CRLF on Windows while the
  generator emits LF. Both the generator and the check strip CR before
  comparing; without that the Windows leg would have failed on every clean
  checkout. This was found before shipping rather than by the matrix, which
  is the first time this class was caught early (compare ADR-0025).
- **ADR-0021 is archived on day one** — its subject, `audit.yml`, was deleted
  by ADR-0028, which is exactly the lifecycle rule's "subject is deleted"
  trigger. The archive path is therefore exercised by the migration itself
  rather than waiting for its first real use.
