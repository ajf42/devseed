# ADR-0025 — First matrix run red on all three legs: shallow checkout was the cause; the offered awk-dialect diagnosis was a different, latent defect

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

The first CI run in this repository's history (the three-leg matrix,
T-009/T-030) failed at check 5 on every leg:

> GATE FAIL [5/7 task ledger]: ## T-001 — Governance scaffold cites commit
> aa53aef, which does not resolve to a commit in this repository.

The diagnosis offered alongside the failure blamed ERE interval expressions
(`{7,}` / `{7}`) inside awk programs — unsupported by some awks, notably
older mawk — at three sites: `drift.sh`'s done-task scan and two in
`orient.sh`. Verification showed that cannot be what happened:

- The failing message is check 5's **resolution** branch, not its
  no-hash branch. Check 5's awk already used the portable longhand
  (`[0-9a-f][0-9a-f]…`), extracted `aa53aef` correctly on whatever awk the
  runner has, and `git cat-file -t` then failed to find the commit.
- `gate.sh` stops at the first failing check, so `drift.sh` — where the
  interval regex lives — never ran at all.

The actual cause: `gate.yml` used `actions/checkout@v4` with its default
`fetch-depth: 1`. A depth-1 clone contains only HEAD; `aa53aef` is the
second commit in history, so every historical hash the ledger cites
resolves to nothing — on every leg, deterministically, starting with the
first done task checked. The same shallow clone also silently guts drift's
superseded check, which walks `DECISIONS.md`'s git history: one commit of
history means nothing to compare and a pass that proves nothing —
degradation without failure, the exact mode §5 is written against.

Two predictions were wrong in instructive ways. `gate.yml`'s own comment
named macOS the risky leg; the first red was platform-independent. And the
defect was invisible locally for the project's entire life not because of
awk dialects but because a developer clone is never shallow — no local run
could ever have seen it.

The interval-regex finding, though not the cause, was real and is the
second half of this record. `drift.sh` duplicated check 5's done-task
logic **deliberately** (it also runs standalone, where the rest of the
gate may not have), and the copies had already drifted: check 5 portable
longhand, `drift.sh` `{7,}`, `orient.sh` `{7}` and `{7,}`. On an awk
without interval support the interval form never matches, the extracted
hash stays empty, and every done task reads as hashless. Awks on the
current runner images appear to support intervals, so the divergence was
latent rather than live — but copy-drift inside the drift guard, with no
guard comparing the copies, is the exact failure class this repository
exists to catch, occurring in the component whose job is catching it.

The portability audit prompted by the diagnosis found two more genuine
platform breaks the diagnosis missed: GNU-only `sed -i` (one use also
carrying `\n` in the replacement, another GNU-ism) at two sites in
`scripts/gate-regression.sh`. BSD sed treats `-i`'s next argument as the
backup suffix, so the suite would have failed on the macOS leg — the
risky-leg prediction come true, one file over from where it was predicted.

**Alternatives considered:**

- **Deepen the clone just enough** (`fetch-depth: N`). Rejected: any
  finite N re-breaks the day history outgrows it, and the superseded walk
  needs full history regardless.
- **Extract the duplicated done-task scan into `gates/lib.sh`.** Feasible —
  `drift.sh` already sources `lib.sh`, so "standalone" does not preclude
  sharing. Rejected on minimum-size grounds (T-029's precedent): the two
  callers differ in reporting semantics — check 5 dies at the first
  finding, drift accumulates all of them with line numbers — so the truly
  shared piece is one awk program. Making the copies textually identical
  and asserting they agree is smaller than the refactor. If they drift a
  second time despite the guard, that incident is the evidence for
  extraction.
- **Install gawk on all legs.** Rejected: the gate promises to run on the
  platforms CI tests as they ship (DESIGN.md §3); installing around a
  dialect difference narrows that promise instead of keeping it.

### Decision

1. `gate.yml` checks out with `fetch-depth: 0`. Full history is a
   prerequisite of two checks' evidence: hash resolution (check 5, and
   drift's copy of it) and the superseded history walk.
2. Every ERE interval expression inside an awk program is normalized to
   the longhand check 5 already used — `drift.sh` one site, `orient.sh`
   two — and the two `sed -i` uses in `gate-regression.sh` are rewritten
   portably. Correction, not amendment: no constraint changes; scripts
   catch up to the existing promise that the gate and its suites run on
   the platforms CI tests. The §6 ratchet does not apply.
3. The check-5/drift duplication stays and gains a guard: assertions in
   `scripts/gate-regression.sh` that both copies rule the same `TASKS.md`
   fixtures the same way — a done task with a resolving hash passes both,
   a hashless done task fails both, a fabricated hash fails both.

### Consequences

- The dev machine (Git Bash: gawk, GNU sed, full clone) structurally
  cannot surface shallow-clone or BSD/mawk dialect defects. The matrix is
  the only detector for this class, and this incident — found on the
  first matrix run ever — is the matrix earning its keep.
- The longhand regex is uglier than `{7,}` and will tempt
  re-simplification; each site now carries a comment saying why it is
  written that way.
- Residual, noted and deliberately not changed: `flush.sh` sets a
  multi-character `RS`, undefined under POSIX but supported by gawk,
  current mawk, and macOS's awk. It runs only in local hooks, never in
  CI. If a platform ever joins where it differs, it is the next edge of
  this same class.
