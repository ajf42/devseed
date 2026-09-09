# ADR-0034 — The `/autopilot` skill leaves the plugin; the driver stays devseed-only

- **Date:** 2026-09-09
- **Status:** Accepted. Supersedes ADR-0030 **only** on its clause
  "`/autopilot` wraps it"; the driver, its routing and its bounds stand.

### Context

SG-0012: `scripts/autopilot.sh` is devseed's own tooling and nothing under
`scripts/` ships, but the skill that wrapped it could not be devseed-local,
because drift check 6 compares shipped and mirrored skills in both directions.
So every consumer received `/governed-dev:autopilot`, whose only behaviour
outside devseed was to explain that it does nothing.

Autopilot is worth keeping for devseed's own development — ADR-0030's
motivation, the human as a transport layer that twice carried a stale account
of work, is real. It is not a consumer feature. `DESIGN.md` defines devseed as
a scaffold that constrains an agent; a driver that spawns headless sessions
is tooling *around* the scaffold, the same category as the regression suites.
Its consumer costs are concrete: the `claude` CLI becomes a prerequisite, a
second committer exists, `reports/` must be named in the structure block,
and `todo` becomes load-bearing (SG-0013). And it has never been run against
a real worker (ADR-0030's own consequences). A governance tool should not
ship an unverified driver as its first impression.

**Alternatives considered:**

- **Ship the script in the plugin** and have bootstrap seed it. Rejected for
  the costs above, and because a feature that has not run once is not ready
  to be someone else's.
- **A devseed-only exemption in drift check 6.** Rejected: new mechanism
  whose sole purpose is to let something ship half-present.
- **Keep shipping the self-disabling skill, documented.** Rejected: a shipped
  command whose only behaviour is an apology.

### Decision

Delete the skill from `plugins/governed-dev/skills/` and from the
`.claude/skills/` mirror. `scripts/autopilot.sh`, its regression suite, its
CI step and `reports/` remain devseed tooling, invoked by hand:
`bash scripts/autopilot.sh --max-tasks 1 T-NNN`. The skill's one rule worth
keeping — present the report's decisions in full and the digest as one line,
never re-narrated — moves to `reports/README.md`. SG-0012 is resolved.
SG-0013 stays open as an operating note: autopilot is always given explicit
task ids, and no status vocabulary is planned.

### Consequences

- The plugin ships five skills and carries no reference to the `claude` CLI.
- Running autopilot now requires knowing the script exists. It is documented
  in `README.md`'s "Developing devseed" section and in `CLAUDE.md`.
- ADR-0030's "the first real run wants explicit ids and `--max-tasks 1`"
  advice is unchanged and still untested.
