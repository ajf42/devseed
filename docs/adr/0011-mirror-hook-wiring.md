# ADR-0011 — devseed mirrors the hook wiring in its own `.claude/settings.json`

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

devseed is governed by the tool it produces (ADR-0001). That dogfooding is the
only ongoing test that the discipline is usable — and for hooks it did not work
at all.

The hooks ship inside the plugin. devseed gets them only by installing the
plugin into itself, and **that install is pinned**: `plugin.json` deliberately
omits `version` (ADR-0001), so an install resolves to a commit SHA and stays
there. The copy on this machine is pinned at `70542ef38e36`, eleven commits
behind `HEAD`, with an **empty `gates/` directory** and the zero-hook
`hooks.json` placeholder. Nothing written under T-004 or T-005 was reachable
from it.

So the acceptance test for T-005 — break a check, confirm the `Stop` hook blocks
— could not be run in devseed at all. Neither could any subsequent change to a
hook be observed without committing, pushing, and explicitly updating first.

This consequence of omitting `version` was not recorded anywhere. ADR-0001 chose
the omission deliberately and for good reasons, and this entry does not reverse
it; it records the cost, which is that **an installed plugin is stale by
default**.

**Alternatives considered:**

- **Publish and update on every change.** Rejected: it reinstates the
  copy-and-drift loop ADR-0001 removed, one round trip per edit, and makes the
  fastest feedback in the system the slowest. It also means devseed can only
  dogfood code it has already published.
- **Install the plugin from a local path instead of the marketplace.** Not
  rejected on merit — it may well be the better answer — but it was not
  reachable from the documented `marketplace add` / `install` flow that
  `CLAUDE.md` records as the verified loop, and inventing an install mode to
  suit one repository is a larger change than a settings file.
- **Give up on dogfooding the hooks and test them only in a scratch project.**
  Rejected: it is exactly the "we will test it elsewhere" that leaves the
  primary repository ungoverned, and ADR-0001 kept dogfooding at the cost of a
  more complicated layout precisely to avoid this.

### Decision

devseed carries its own `/.claude/settings.json` registering the same eight
events against `${CLAUDE_PROJECT_DIR}/plugins/governed-dev/hooks/` — the working
tree. A hook edit takes effect on save, with no publish-and-update cycle.

The **scripts are not duplicated**. There is one copy of each, under
`plugins/governed-dev/hooks/`, and both wirings point at it. Duplication is
confined to the event set, the matchers and the async flags.

`hook_gate()` in `hooks/lib.sh` resolves the gate **relative to the running
script** rather than from `${CLAUDE_PLUGIN_ROOT}`, precisely because a stale
plugin may also be installed: taking the environment variable first would run
the working tree's hook against the installed copy's gate — two definitions of
done in one invocation.

### Consequences

- **A mirror that can drift.** `hooks.json` is the source of truth and
  `settings.json` follows it. Nothing notices divergence today, so **T-006's
  acceptance criteria are extended** to assert the two agree on events and
  matchers. Until T-006 lands, this is an unguarded seam and is named as one in
  both files.
- The consumer-facing path is unchanged. Consumers get the hooks from the
  plugin; only devseed carries the mirror, and `settings.json` says so in its
  own `_README`.
- Recorded here so it is findable: **omitting `version` from `plugin.json` means
  every install is pinned to a SHA and goes stale silently.** Any project
  depending on the plugin needs an explicit update step. That is a cost of
  ADR-0001, not a defect in it.
- `.claude/settings.json` is committed and shared, unlike
  `.claude/settings.local.json`, which `.gitignore` excludes as per-machine.
