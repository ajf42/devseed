# ADR-0015 — Normalize `*.sh` to LF via `.gitattributes`, regardless of local `core.autocrlf`

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

On Windows, `core.autocrlf=true` lands every tracked script CRLF at checkout.
Git for Windows patches its own `bash` to ignore a trailing CR, so a CRLF
script still runs there — confirmed directly: `drift.sh` running CRLF under
gate check 7 passed with the gate exiting 0. That tolerance is specific to
Git Bash. WSL bash, `dash`/`sh`, and Linux CI reading a Windows-authored tree
do not ignore the trailing CR, and the repository currently ships CRLF to all
of them the moment a Windows contributor without `core.autocrlf=input` clones
and commits.

The change was sanctioned under DESIGN.md §4 ("whatever it takes to copy this
scaffold into a new repo and have it work") and §3's platform row (bash / Git
Bash as a stated Windows prerequisite), on the premise that a CRLF script is a
form Git Bash itself cannot execute. That premise was tested directly and
**disproved** — Git Bash tolerates it fine. The defect is real but narrower
than first stated: it is a cross-platform and CI problem, not a Windows-shell
problem. The sanction still holds under the same two clauses, for the
corrected reason.

**Alternatives considered:**

- **`core.autocrlf=input` as local git config.** Rejected: config is
  per-clone and not versioned. It protects only a contributor who remembers to
  set it and does not travel with a fresh clone, which is the exact failure
  this change exists to close.
- **A broader `.gitattributes` covering more filetypes.** Rejected as out of
  scope for this change: spec-guardian's sanction covered `*.sh` specifically
  and did not pre-clear a general normalization policy. Extending coverage to
  other extensions would need its own ruling.
- **Do nothing.** Rejected: it is the status quo that produced the defect —
  a Windows checkout can silently commit CRLF scripts that fail wherever the
  tolerance Git Bash grants does not extend, with no signal until something
  else reads the tree.

### Decision

Add root `.gitattributes` with one rule: `*.sh text eol=lf`. All 20 tracked
shebang-bearing scripts in the repository are `*.sh`, so the single rule has
full coverage with no gap.

### Consequences

- Every clone, regardless of local `core.autocrlf`, checks out `*.sh` as LF.
  What this closes is specifically WSL bash, `dash`/`sh`, and Linux CI reading
  a Windows-authored tree — not Git Bash on Windows, which already tolerated
  CRLF and was never actually broken by it.
- The index was already LF and none of the 20 tracked blobs contained a CR, so
  landing the rule required no `git add --renormalize` and changed no file
  content.
- Coverage is scoped to `*.sh` only, matching the sanction that was actually
  granted. `plugins/governed-dev/templates/` — which seeds a consumer's own
  repository, including its `gate.sh` — has no equivalent protection yet.
  Recorded as its own open question rather than folded into this decision,
  since extending scope to what ships to consumers needs its own ruling. See
  SG-0008.
