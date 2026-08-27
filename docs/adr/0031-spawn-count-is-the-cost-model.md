# ADR-0031 — Process spawns are the gate's unit of cost; checks are written batch-first

- **Date:** 2026-08-27
- **Status:** Accepted

## Context

A session that produced one small change took roughly ninety minutes of wall
clock. Profiling put the cause in one place, and it is not the one the code
reads as.

**A process spawn costs about 100 ms under Git Bash on Windows** — 170 ms for
`git` — against 1–2 ms on Linux. Measured, not estimated: fifty forks of
`/usr/bin/true` take 5.0 s on the development machine, with Defender real-time
protection already off, so this is MSYS2 fork emulation and it is inherent
rather than something a configuration change removes.

Every expensive check was spending processes per *item* where one process for
the whole batch would do:

| Check | Cost | Shape |
|---|---|---|
| `check_orphans` | 68.0 s | one `grep` plus `sort` per tracked file (224), plus an `ls` per citation (257–500) |
| `check_adr_index` | 50.0 s | the generator: ~10–14 spawns per ADR file, ~390 across thirty |
| `check_staleness` | 10.8 s | `git check-ignore` per path (64) |
| `check_superseded` | 8.6 s | `printf` piped to `grep -q` per ADR number (60) |
| `boundary.sh` | 1.7 s | one `jq` per field, on **every** tool call |

The item counts are all small — 112 tracked files, 393 citations, 30 ADRs, 64
structure-block paths. The spawn counts are not. **No check was doing too much
work. Every expensive check was doing its work in too many processes.**

The full gate ran 132–198 s, and the `Stop` hook runs it before every turn may
end. Twenty turns is over an hour of drift checking.

**This is the same defect class as T-044, one layer down.** T-044 fixed a check
that passed for the author because a file existed only on his machine. This is a
cost that is invisible to a Linux author and paid by every Windows consumer on
every turn — the same asymmetry, in the same direction: the person best placed
to notice is the one person who does not experience it.

**Alternatives considered:**

- **Memoize the gate's result on tree state.** Key on `HEAD`, the porcelain
  status and the ledger hashes; skip a re-run when the key matches a previous
  pass. **Rejected.** §5 says a check that cannot run is a failed check, and a
  memo is a check that did not run. A stale-key bug produces a green gate that
  never looked — precisely the false green T-044 had just closed, arriving
  silently and in the dangerous direction. Batching takes the gate to about ten
  seconds; memoization would buy seconds beyond that and cost the property the
  gate exists to provide. Recorded here so it is a declined alternative rather
  than an idea that resurfaces whenever the gate feels slow.
- **Scope the citation scan to changed files.** **Rejected.** Deleting an ADR
  makes citations stale in files that did not change, so a changed-files scan
  reports nothing and passes. Full scan is the correct semantics; batching is
  what makes correct affordable.
- **Accept the cost.** **Rejected.** It compounds per turn, it is worst for
  consumers rather than for the author, and it trains people to switch the gate
  off — which converts a verification system into decoration.

## Decision

**Process spawns are the unit of cost in the gate and hooks. Checks are written
batch-first:** one pass over many items, with membership and lookup answered
in-process, rather than a shell-out per item.

Concretely, and as applied in T-046 through T-049:

- Build lookup sets **once** (the valid ADR and SG ids, the tracked-file set,
  the ignored-path set) and test them with `case`, which forks nothing.
- Scan with **one** `grep` over a file list, not one per file.
- Extract with **one** `awk` pass over many files, not `sed | head` per file.
- Read structured input with **one** `jq` per event, not one per field.
- Prefer shell builtins that do not fork — `printf -v` over
  `$(printf ...)` — inside loops.

**A new check that spawns per item needs a stated reason.** The bar is not
absolute; it is that the cost is now known and choosing to pay it is a decision
rather than an accident.

**Batching must not change a verdict.** Every such change is proved against a
captured before-and-after over a fixture set covering both ADR layouts and each
branch of the check, compared byte for byte with CR stripped. A diff is a bug,
not an improvement. Two ordering semantics found this way, and preserved because
neither was obvious: the per-file `sort -u -t: -k2` in `check_orphans` dedupes by
**id** rather than by line, and `sort -u` keeps the **first record of an
equal-key run** rather than the lexically smallest, so the lowest-numbered
citation survives.

## Consequences

The full gate falls from 132–198 s to roughly ten seconds, and `boundary.sh`
from 1.7 s to about half a second on every tool call. The `Stop` hook stops
being the dominant cost of a session, and the four regression suites inherit the
same speedup because they invoke the same code.

**What this costs: contributor convenience.** A per-item shell-out is easier to
write and easier to read than a batched pass with an `awk` program in the middle
of it. `check_orphans` is materially harder to follow than it was. That is a
real loss, paid once by whoever writes a check, in exchange for an order of
magnitude paid back on every run by everyone. The comments in the batched code
carry the reasoning precisely because the code no longer shows it plainly.

**What this does not fix:** the underlying spawn cost. A future check written
without this in mind will be slow again, and nothing enforces the convention
mechanically — the gate cannot measure its own cost, so this remains a habit
supported by a written decision, in the same category as the other habits §5's
Known limits names.

`ENDFILE` and ERE interval expressions stay forbidden inside `awk` programs
regardless of what batching makes convenient: the CI matrix runs mawk, and
ADR-0025 records what a silently non-firing match already cost once.
