# ADR-0020 — devseed's own CI needs neither a vendored `gate.sh` nor `${CLAUDE_PLUGIN_ROOT}`

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

T-009 required resolving SG-0003's CI half: `hooks.json` locates the gate via
`${CLAUDE_PLUGIN_ROOT}`, which does not resolve outside a Claude Code session,
so CI needs a different way to find `gate.sh`.

**Alternatives considered:**

- **Vendor a copy of `gate.sh` for CI to call.** Rejected: a second copy of a
  multi-file gate is exactly the drift ADR-0002 already named as this layout's
  sharpest cost, and devseed already refuses to do this for consumer projects
  (SG-0003's bootstrap half).
- **Install the plugin in the CI container before running it**, e.g. `claude
  plugin marketplace add` + `install`. Rejected as unnecessary complexity and
  circularity for devseed's own CI specifically: this repository already *is*
  `plugins/governed-dev/`'s source. Installing devseed's plugin into a
  checkout of devseed to find a script that already sits at a known
  repo-relative path solves a problem devseed's own CI does not have.
- **Call `plugins/governed-dev/gates/gate.sh` by its repo-relative path.**
  Chosen. Matches `hooks/lib.sh`'s own `hook_gate()`, which already prefers
  the sibling path over `${CLAUDE_PLUGIN_ROOT}` for the same reason (see its
  comment: devseed dogfoods against the working tree, not the installed,
  possibly-stale copy).

### Decision

`.github/workflows/gate.yml` checks out devseed and runs `bash
plugins/governed-dev/gates/gate.sh` directly. No vendoring, no plugin install
step, no `${CLAUDE_PLUGIN_ROOT}`.

### Consequences

- Settles SG-0003 **for devseed's own CI only**. A consumer project's CI truly
  does not have the plugin's source checked out, so this reasoning does not
  transfer, and that half of SG-0003 is explicitly left open in its own entry
  rather than closed by implication.
- CI platform is GitHub Actions, unstated by any prompt but an obvious
  consequence of `github.com/ajf42/devseed` already being where this repo
  lives (`CLAUDE.md`).
