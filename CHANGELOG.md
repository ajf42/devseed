# Changelog

Versions are the `governed-dev` plugin's, declared in
[`plugins/governed-dev/.claude-plugin/plugin.json`](plugins/governed-dev/.claude-plugin/plugin.json).
An installed plugin moves **only** when that field is bumped and you run
`/plugin update` — pushing commits alone reaches nobody. See ADR-0026.

Each entry says what changed for **someone installing the plugin**. Changes to
devseed's own development tooling are noted only where they change what ships.

## 0.1.3 — 2026-09-23

**Fixed — every bootstrap ended with the turn blocked.** The seeded `CLAUDE.md`
names the files bootstrap writes, bootstrap does not commit, and since 0.1.1
the drift guard fails on a named path git does not track. So the `Stop` hook
blocked the end of every bootstrap three times and released it unfinished,
with no fix the agent was allowed to make. Bootstrap now **stages** the files
it wrote — by explicit path, never `git add -A`, and still never commits — so
the gate passes and your first commit is still yours to compose. The gate
itself is unchanged (T-058).

If you bootstrapped on 0.1.2, stage the files yourself:
`git add -- DESIGN.md CLAUDE.md DECISIONS.md TASKS.md gate.sh .gitignore .gitattributes .claude/rules .claude/activity.jsonl`.

**Fixed — hook scratch showed up as untracked files.** The seeded `.gitignore`
now excludes `.claude/.hook-state/`, `.claude/in-flight.md` and
`.claude/settings.local.json`. On an existing project, add those three lines
yourself; bootstrap does not run twice.

## 0.1.2 — 2026-09-09

The first release meant for people other than its author. Four decisions that
had been sitting open are recorded, and the defects a new consumer met first
are fixed.

**Fixed — the seeded `DESIGN.md` deadlocked new projects.** §6 shipped as a
comment saying there was no sanctioned path for editing the document, while
the file's own header said changes go through §6 and `/amend` refused to run
without one. Writing §6 was itself a change to the file. §5 had the same shape:
it described the contract the gate already enforces and shipped empty. Both now
arrive filled in, each saying why. §5's second half, your project's own build
rules, stays a prompted slot — what your build must satisfy is not the
template's to decide (T-045, ADR-0036).

**Fixed — `jq` was a hard requirement nobody was told about.** Without it the
boundary hook denies every write and the `Stop` hook blocks every turn, by
design. The README now names it alongside Git Bash, with the winget `PATH`
quirk.

**Fixed — shipped agents and skills pointed at paths that do not exist in your
project.** Four of them named devseed's own repo-relative script paths. They now
resolve the way the hooks do: `${CLAUDE_PLUGIN_ROOT}` first, repo-relative as a
named fallback. The task skill also cited three of devseed's own ledger ids,
which resolve to nothing in yours.

**Fixed — two decision-log conventions were stated as one.** The scribe and
implementer described one file per decision under `docs/adr/`; the `adr` skill
and the seeded `DECISIONS.md` described entries appended inline. The gate
already accepted either. The agents now follow whichever convention your
project uses, and will not migrate you between them.

**Removed — the `/autopilot` skill.** Its driver script never shipped, so the
command's only behaviour in your project was to explain that it does nothing.
The driver stays devseed's own tooling; it has never been run against a real
worker (ADR-0034).

**Added — how to run the gate in CI.** Clone the plugin at the tag matching
your installed version and run its `gate.sh` against your checkout. Nothing is
vendored into your repository, so there is one definition of "done" and it
keeps receiving fixes. The README section states the three parts that are
load-bearing (ADR-0035).

**Decisions recorded.** The repository is public as a position rather than a
temporary window (ADR-0032). The main session thread is trusted and the roster
binds delegated work, so the separation of duties is what `/governed-dev:task`
buys you (ADR-0033) — the README's "What this does not do" says so plainly.

## 0.1.1 — 2026-08-28

Performance and one portability fix. No behaviour change to what the gate
accepts or rejects, except where noted.

- **The gate no longer passes on paths that exist only on your machine.**
  Drift check 1 tested the filesystem, so a `CLAUDE.md` naming an untracked,
  un-ignored file passed locally and failed in every clone. It now tests
  tracking. This is a tightening: a green gate that was hiding this starts
  reporting it (T-044).
- **Fewer process spawns**, so the gate and hooks run faster on large
  repositories: the drift guard batches its per-item checks, the boundary hook
  reads one JSON event with one `jq` instead of four, and the ADR index
  generator makes one pass instead of fourteen per entry (T-046 to T-049,
  ADR-0031).

## 0.1.0 — 2026-08-11

First tagged release. The gate, the seven checks, the drift guard, the eight
lifecycle hooks, the five-agent roster with enforced tool boundaries, the
skills, and the templates the bootstrap skill seeds.
