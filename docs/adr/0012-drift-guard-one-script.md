# ADR-0012 — The drift guard measures copying, and is one script, not six checks

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

T-006 asks for guards against the documents and the repository disagreeing.
The obvious reading is "check the documents are *correct*," which no script can
do — correctness is a judgement about meaning.

What is mechanically decidable is the *mechanism* by which they stop being
correct. A summary that references its source stays right when the source
changes. A summary that copied its source is a second copy with no maintainer,
and diverges the moment either side is edited. So the guard measures **copying,
not agreement**: a long verbatim run between a rules section and `CLAUDE.md` is
evidence of a future divergence, detectable today. The same logic covers the
rest — a path that resolves to nothing, an id with no entry, an ADR git
remembers and the file does not.

The prior art is `check_design_sync.py` in the utility-bill-pipeline, which
slid a 12-word window over one hardcoded DESIGN.md section. Two things about it
generalised badly: it named `§8` explicitly, so renumbering the spec silently
disarmed it, and it was Python in a project that had Python.

**Alternatives considered:**

- **Six more `check-NN-*.sh` files, one per drift class.** Rejected. The gate's
  checks stop at the first failure, which is right for "is this done?" — you fix
  it and re-run. It is wrong for a drift report: drift findings are independent,
  and being shown one of six means five more re-runs to see the list. T-006 also
  requires standalone execution for CI (T-009), which a sourced fragment cannot
  do. One script that accumulates findings and exits at the end satisfies both;
  `check-07-drift.sh` is a four-line adapter.
- **Port the Python directly.** Rejected. DESIGN.md §3 gives devseed no runtime
  and no dependencies, and `lib.sh` already carries a `python_bin()` workaround
  for a Windows shim that resolves but does not execute. A guard that silently
  skips where Python is absent is the silent degradation §5 exists to prevent.
  `awk` is present wherever `bash` is, which is already a hard requirement
  (ADR-0006).
- **Hardcode `§5`, as the original hardcoded `§8`.** Rejected — that is the
  defect, not the design. Check 7 finds rules sections by *title* matching
  rules/conventions/constraints/contract/standards, so the guard re-reads the
  spec at runtime and renumbering cannot disarm it.
- **Compare full hook command strings for parity.** Rejected: the two wirings
  point at different roots deliberately (ADR-0011), so the strings *must*
  differ. Only the event set, matchers, script basenames and async flags are
  compared — precisely the surface that can drift, since the scripts themselves
  are shared.
- **A stricter or looser window than 12 words.** 12 is inherited from the prior
  art and confirmed empirically here: at 12 devseed is clean, at 8 the only hit
  is the phrase "and the script disagree the script wins and", and at 6 a bare
  file path. The threshold sits above what legitimately co-occurs and below a
  copied bullet.

### Decision

Check 7 is `gates/drift.sh`: one bash script, six drift classes, every finding
reported, exit 2 at the end, runnable standalone. Canaries are derived from
`DESIGN.md` at runtime by section title. Text work is `awk`. `jq` is required
only for hook parity, and only where the mirrored pair exists.

### Consequences

- **Editing the spec never requires editing the guard.** This is the property
  worth the most and the one most easily lost.
- **A wrong-but-not-copied summary passes.** The guard catches the mechanism,
  not the meaning. Stated as a known limit in §5 so it is not mistaken for
  coverage.
- **`find_jq()` duplicates `_jq_dir()` in `hooks/lib.sh`.** Accepted
  deliberately: the two libs are separately-sourced deliverables — one by the
  gate, one by the hooks — and making either depend on the other to save nine
  lines would couple the gate's availability to the hooks'.
- **The reverse staleness test only covers top-level directories.** Going
  deeper would demand every file appear in the structure block, which fights
  the line budget the same file is held to.
- **Check 7 runs on the full gate, not `--fast`.** It walks git history for
  `DECISIONS.md`, which is too slow for a per-edit hook.
- **`CLAUDE.md`'s structure block is now load-bearing syntax**, not just prose.
  Its indentation and two-space comment column are parsed. The convention is
  recorded in §5 so it is not reformatted by accident.
