# DESIGN.md — {{PROJECT_NAME}}

> This document is the project constitution. It is authoritative for **what this
> system should be**. `CLAUDE.md` is authoritative for **what currently
> exists**. On a spec question DESIGN.md wins; on a current-state question
> CLAUDE.md wins. If the two describe incompatible systems rather than the same
> system at two points in time, stop and surface it — do not reconcile silently.
>
> Changes to this file go through the amendment procedure in §6. Nothing else.

<!-- SKELETON. Replace the guidance in each section with this project's real
     content. Delete the HTML comments as you go. Sections 5 and 6 are the
     mechanism — fill them in, do not remove them. -->

## 1. What this is

<!-- One paragraph, plain language. What the system does and for whom. No
     architecture, no justification. If it cannot be said in a paragraph, the
     scope in §4 is probably wrong. -->

## 2. Problem context and who this is for

<!-- The problem that exists whether or not this system is built, who has it,
     and what they do today instead. Then who this is for — and, as sharply,
     who it is not for. A system with no non-users has no scope.

     Also: what success looks like, stated so it could be observed rather than
     asserted. -->

## 3. Architecture and stack

<!-- A table. The "why" column is the point: it records the reasoning that a
     future reader would otherwise have to reconstruct, and makes it possible
     to tell whether a choice still holds when its context changes. A why that
     reads "industry standard" or "well supported" is not a reason — it is a
     reason to look for the reason. -->

| Choice | What it is | Why |
|---|---|---|
|  |  |  |

## 4. Scope

### In scope

<!-- What this system commits to doing. -->

### Out of scope

<!-- What it will not do, and why not. This section prevents more work than
     §4.1 creates. -->

### Explicitly deferred

<!-- Every deferred item names where it gets treated instead. An item with no
     venue is not deferred — it is out of scope, and belongs in the section
     above. This distinction is the whole value of the section: "later" without
     an address is how work disappears. -->

| Deferred | Treated instead in |
|---|---|
|  |  |

## 5. Build rules

<!-- What every change must satisfy: which gates exist, what blocks versus what
     merely warns, and what "done" means. Rules here are enforced mechanically
     where possible — advice that lives only in prose is optional in practice.

     If this section is empty, nothing is enforced. That is a known hole, not
     permission. -->

## 6. Amendment procedure

<!-- How this document changes: what counts as an amendment versus a
     correction, who may make one, and what must be recorded where.

     Whatever is written here, it must forbid amending DESIGN.md to match
     drifted code — that inverts the direction of authority and converts an
     unsanctioned implementation detail into a sanctioned constraint by fiat.

     Until this section is written, there is no sanctioned path for editing
     this document. -->
