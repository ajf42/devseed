# devseed

A governance scaffold for building with AI coding agents, packaged as a Claude
Code plugin.

The expensive failures in agent-assisted development are not bad code — bad code
is cheap to find and cheap to fix. They are **unsanctioned constraints**:
assumptions an agent invented under ambiguity, which nothing marks as guesses,
and which become load-bearing before anyone notices. The spec did not say whether
errors bubble or get swallowed, so the agent picked. The pick was reasonable and
undocumented. A week later it is indistinguishable from a decision a human
actually made, and everything built on top depends on it.

devseed's job is to make those guesses either impossible or visible — through
mechanism rather than through paragraphs of instruction that fall out of working
memory as a session gets long.

## Install

```
/plugin marketplace add ajf42/devseed
/plugin install governed-dev@ajf42-devtools
```

Then `/reload-plugins`. Skills install **namespaced** — `/governed-dev:bootstrap`,
not `/bootstrap`. A "missing" skill is usually this.

**Windows requires Git Bash.** The gate is a bash script; `gates/gate.ps1` finds
Git Bash and hands off, or fails with install instructions. It never silently
skips — a gate that only runs on one platform is a gate that silently does not
run. See ADR-0006.

## What you get

| | |
|---|---|
| **`gate.sh`** | The single executable definition of "done". Six checks: build, tests, lint, working-memory-current, task-ledger-honest, spec-gaps-answered. Exit 0 or 2, never 1 — Claude Code treats exit 1 as non-blocking. Verification only; it never commits, pushes, or writes. |
| **Ledger documents** | `DESIGN.md` (what the system should be), `CLAUDE.md` (what exists now, line-budgeted), `DECISIONS.md` (why, append-only), `TASKS.md` (what's next, one task per commit). |
| **Rules** | Document precedence, and what to do at a spec gap: ask, or record the assumption in *both* the code and `DECISIONS.md`. Never invent. |

Agents, skills, and hooks are in progress — see `TASKS.md`.

## ⚠ Four filenames exist twice, with opposite roles

This is the sharpest edge in the layout. Check which directory you are in before
editing:

| Path | Role |
|---|---|
| `/DESIGN.md`, `/CLAUDE.md`, `/DECISIONS.md`, `/TASKS.md` | Govern **devseed itself**. Filled in, specific, **never copied anywhere**. |
| `plugins/governed-dev/templates/{DESIGN,CLAUDE,DECISIONS,TASKS}.md` | **Shipped to consumer projects.** Structural skeletons, deliberately free of opinions — a default baked into a template installs an unsanctioned constraint into every project at once. |

The test when unsure: anything under `templates/` is distributable; anything at
the repo root is not. See ADR-0002.

## Developing devseed

devseed is governed by its own `DESIGN.md` — the tool is built under the
discipline it exports, which is the only ongoing test that the discipline is
usable.

```
bash plugins/governed-dev/gates/gate.sh    # the gate, against this repo
bash scripts/gate-regression.sh            # the gate's own regression suite
claude plugin validate .                   # manifests
```

devseed has no build, no tests, and no linter of its own (`DESIGN.md` §3), so
gate checks 1–3 pass vacuously here. Gate bugs involving real tooling are only
findable against a scratch project that declares some — which is what
`gate-regression.sh` builds. Run it after touching anything under `gates/`.

`plugin.json` omits `version` deliberately: the installed version resolves to
the commit SHA, which is the right default for a solo, actively-iterated tool.
`claude plugin validate --strict` fails on that one warning by design.
