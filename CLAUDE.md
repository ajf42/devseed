# CLAUDE.md — devseed working memory

> **Line budget: target 200, hard ceiling 300.** This file is working memory,
> not an archive. It is read in full every session; every line spends context
> that belongs to the task. See "Compression protocol" below before adding.

This file governs **devseed itself**. It is not the template shipped to consumer
projects — that is
[`plugins/governed-dev/templates/CLAUDE.md`](plugins/governed-dev/templates/CLAUDE.md).

---

## How this relates to DESIGN.md

[`DESIGN.md`](DESIGN.md) says what devseed **should be**. This file says what
devseed **is right now**. Spec questions resolve against DESIGN.md; current-state
questions resolve against this file.

This file is expected to go stale — code moves faster than notes. Ordinary
staleness is corrected in place, no ceremony. But if the two documents describe
*incompatible systems* rather than the same system at two times, that is not
staleness and must not be reconciled silently. Stop and surface it.

Never edit DESIGN.md to match drifted code: that converts an accident into a
sanctioned constraint. Full rule:
[`.claude/rules/precedence.md`](.claude/rules/precedence.md).

Where to write a given fact:
[`.claude/rules/ledger.md`](.claude/rules/ledger.md).

## Current state

devseed is a **governance scaffold**, not an application. It has no runtime, no
dependencies, and no build step. It serves two roles at once — it is a project
governed by its own DESIGN.md, and it is the source of the `governed-dev`
plugin installed into other projects. See ADR-0001.

**Built and working:**

- Constitution at [`DESIGN.md`](DESIGN.md). Sections 1–5 substantive.
  §6 (amendment procedure) is still a placeholder.
- **The gate**, at `plugins/governed-dev/gates/`. `gate.sh` orchestrates six
  checks in `check-*.sh`; `--fast` runs 1–3. Exit 0 pass, 2 fail, never 1.
  Verification only — it writes nothing. Run it as
  `bash plugins/governed-dev/gates/gate.sh`.
- Two rule files at [`.claude/rules/`](.claude/rules/) — `precedence.md`
  (document authority) and `ambiguity.md` (never invent past a spec gap).
  These govern devseed and are deliberately **not** shipped in the plugin.
- Plugin/marketplace manifests. `claude plugin validate .` passes with one
  warning: `version` is intentionally omitted from `plugin.json`, so the
  installed version resolves to the commit SHA. `--strict` fails on that
  warning by design and is unusable until a release is pinned.
- Published to `github.com/ajf42/devseed`. Install loop verified end to end
  from a directory outside this repo:
  `claude plugin marketplace add ajf42/devseed` then
  `claude plugin install governed-dev@ajf42-devtools`.
- Ledger documents: this file, [`DECISIONS.md`](DECISIONS.md),
  [`TASKS.md`](TASKS.md), and `.claude/activity.jsonl`.

**Not built yet:**

- `plugins/governed-dev/agents/` and `skills/` are empty. `hooks.json`
  registers zero hooks — it carries only the path-variable convention notes,
  so **the gate exists but nothing invokes it automatically yet** (T-005).
  Until then it must be run by hand.
- Checks 1–3 pass vacuously in devseed, which by DESIGN.md §3 has no build,
  tests, or linter. They trigger on *declared* tooling; see ADR-0004 and the
  Known limits in §5. Verified against a scratch project that does have tests.
- `templates/gate.sh` is still a placeholder — whether consumers vendor their
  own copy is open as SG-0003, and CI (T-009) forces the answer.
- `plugins/governed-dev/templates/` holds structural skeletons only, with no
  project-specific content by design.
- Repository visibility is **public**; private was required. `gh` is not
  installed on this machine. Open as SG-0002.

**Two facts that bite if forgotten:**

1. Four filenames exist twice with opposite roles. Root `DESIGN.md`,
   `CLAUDE.md`, `DECISIONS.md`, `TASKS.md` govern devseed and are never
   copied. The same names under `templates/` are shipped to consumers.
   Check which directory you are in before editing.
2. Plugin skills install namespaced — `/governed-dev:bootstrap`, not
   `/bootstrap`. A "missing" skill is usually this.

## File structure as it stands

```
.claude-plugin/marketplace.json    marketplace "ajf42-devtools"
.claude/
  activity.jsonl                   append-only audit log (committed)
  rules/
    precedence.md                  DESIGN.md vs CLAUDE.md authority
    ambiguity.md                   spec gaps: ask or record, never invent
    ledger.md                      which document owns which information
DESIGN.md                          constitution (§5, §6 are placeholders)
CLAUDE.md                          this file
DECISIONS.md                       ADR log + spec gaps observed
TASKS.md                           backlog, one task per commit
README.md                          one line; not yet written
.gitignore
plugins/governed-dev/              THE PLUGIN — everything below ships
  .claude-plugin/plugin.json       no "version" key, deliberately
  agents/                          empty — Prompt 6 adds the scribe
  skills/                          empty — Prompt 7 adds bootstrap
  gates/                           THE GATE — definition of "done"
    gate.sh                        orchestrator; --fast = checks 1-3
    lib.sh                         die/note/have, changed_files
    check-0[1-6]-*.sh              one check each, sourced in order
  hooks/hooks.json                 0 hooks; carries path conventions
  templates/                       seed docs copied into consumer projects
    DESIGN.md CLAUDE.md DECISIONS.md TASKS.md gate.sh README.md
```

Path rule for remaining work: content specified as `.claude/agents/*`,
`.claude/skills/*`, `.claude/gates/*`, or `.claude/hooks/*` is built under
`plugins/governed-dev/<same-subpath>`. Only `.claude/rules/` and
`.claude/activity.jsonl` keep their literal root paths.

Hook path variables are reversible by accident and both reversals fail
silently: `${CLAUDE_PLUGIN_ROOT}` **locates** scripts shipped with the plugin
(it is copied to a cache dir on install); `${CLAUDE_PROJECT_DIR}` **roots the
code a gate inspects**. Recorded in `hooks/hooks.json`.

## Build rules

Described in **[`DESIGN.md`](DESIGN.md) §5**, but the *authority* is
`plugins/governed-dev/gates/gate.sh`. If the prose and the script disagree, the
script wins and the prose gets fixed. Do not restate the rules here.

## Compression protocol

When a change would push this file past **300 lines**, compress *before*
continuing the change. Do not commit an over-budget file with a note to clean
it later.

Route the detail by what it is:

- **Spec** — a constraint, an intent, something that should be true → move to
  `DESIGN.md` via its amendment procedure. Leave a one-line pointer here.
- **Rationale** — why a choice was made → move to `DECISIONS.md` as an ADR.
- **Local mechanics** — how one directory works → move to a `README.md` in
  that directory. Link it from the file-structure block above.
- **Pending work** → move to `TASKS.md`.
- **Superseded state** → delete it. This file is not an archive; git holds
  the history.

The budget is the point, not an aspiration. A CLAUDE.md that grows without
bound stops being read carefully, and an unread current-state record is worse
than none: it looks authoritative while nobody checks it.
