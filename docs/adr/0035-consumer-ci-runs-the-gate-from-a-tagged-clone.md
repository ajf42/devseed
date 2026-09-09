# ADR-0035 — Consumer CI runs the plugin's gate from a tagged clone; vendoring rejected

- **Date:** 2026-09-09
- **Status:** Accepted

### Context

The last open half of SG-0003: a consumer's CI does not have the plugin
installed, `${CLAUDE_PLUGIN_ROOT}` does not resolve there, and the `gate.sh`
bootstrap seeds at the consumer's root is a documented no-op. ADR-0020
settled devseed's own CI by calling the gate at its repo-relative path, which
does not transfer.

The facts that shape the answer: the gate is ten files and about 1,100
lines, not one script; it needs bash, git with **full** history (check 5 and
drift resolve commit hashes, and a depth-1 clone fails all of them, ADR-0025),
and whatever toolchain the project declares; `jq` is needed only by the
hook-parity sub-check, which self-disables in a consumer project. In a
session, the hooks locate the gate as their own sibling in the plugin cache
and point it at the consumer's checkout via `CLAUDE_PROJECT_DIR`. And
`DESIGN.md` §3 says "Git, no CI assumed": CI is an optional second layer.

**Alternatives considered:**

- **Vendor the gate into the consumer repository at bootstrap.** The natural
  first thought, rejected for three reasons that are invisible from outside.
  (1) Two definitions of done per consumer: the plugin-cache copy the hooks
  run and the vendored copy CI runs are identical at bootstrap and diverge
  at the first plugin update — either the hooks prefer the vendored copy and
  updates never reach the gate, or they do not and local and CI disagree
  silently, which §5's CI-parity rule names as a defect. (2) Gate fixes stop
  arriving; the gate has had real defects fixed after release (T-012 to
  T-015, T-044). (3) The gate moves inside the boundary it enforces: the
  implementer holds `Write`, `Edit` and `Bash` and is denied only the ledgers
  and `docs/adr/`, so a vendored gate is editable by it, and that edit is
  committed as the project's definition of done — §6's loosening ratchet
  with no chokepoint. The plugin-cache copy is never committed and is
  overwritten on update.
- **Install the plugin inside the CI job.** Rejected: it makes the `claude`
  CLI a CI prerequisite for a gate that is plain bash, and adds a marketplace
  round trip to every run.
- **Document the limit only.** Rejected: the recipe below is three lines and
  costs nothing to state.

### Decision

A consumer's CI checks out its own repository with full history, clones
devseed at the tag matching its installed plugin version into a directory
**outside** the workspace (so drift's reverse-staleness check does not see a
new top-level directory), and runs `plugins/governed-dev/gates/gate.sh` from
that clone with `CLAUDE_PROJECT_DIR` set to the workspace. The recipe ships as
README text; `templates/gate.sh` stays a no-op and its header points at the
recipe. SG-0003 is resolved in full.

### Consequences

- Depends on the repository staying public (ADR-0032).
- The consumer keeps one ref string in step with their plugin version. A
  mismatch is a visible ref rather than a silently drifted copy.
- Consumers on other CI platforms adapt three lines; only GitHub Actions is
  shown.
- A shipped workflow template, with bootstrap-regression coverage, is a
  follow-up task, not part of this decision.
