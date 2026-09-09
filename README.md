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

To pin to a release, add the marketplace by git URL with a tag ref —
`/plugin marketplace add https://github.com/ajf42/devseed.git#v0.1.2` — and note
that an installed plugin moves only when `plugin.json`'s `version` is bumped
*and* you run `/plugin update`, so an install left alone stays exactly where it
was.

**Windows requires Git Bash.** The gate is a bash script; `gates/gate.ps1` finds
Git Bash and hands off, or fails with install instructions. It never silently
skips — a gate that only runs on one platform is a gate that silently does not
run. See ADR-0006.

**`jq` is required, on every platform.**

```
Windows   winget install --id jqlang.jq -e
macOS     brew install jq
Debian    sudo apt-get install jq
```

The hooks parse a JSON event and emit JSON decisions, and hand-rolled escaping
in shell is how a deny reason containing a quote becomes a malformed object the
harness drops — a boundary that stops enforcing and says nothing. So without
`jq` the boundary hook denies **every** write and the `Stop` hook blocks every
turn, deliberately: an enforcement point that cannot evaluate itself must not
default to allow. Install it before the first session. Note that winget puts it
in a directory only processes started *after* the install can see, so start a
new terminal; the hooks probe the usual install locations when `PATH` misses.

## What you get

| | |
|---|---|
| **`gate.sh`** | The single executable definition of "done". Seven checks: build, tests, lint, working-memory-current, task-ledger-honest, spec-gaps-answered, and a structural drift guard over the ledger documents. Exit 0 or 2, never 1 — Claude Code treats exit 1 as non-blocking. Verification only; it never commits, pushes, or writes. |
| **Ledger documents** | `DESIGN.md` (what the system should be), `CLAUDE.md` (what exists now, line-budgeted), `DECISIONS.md` (why, append-only), `TASKS.md` (what's next, one task per commit). |
| **Rules** | Document precedence, and what to do at a spec gap: ask, or record the assumption in *both* the code and `DECISIONS.md`. Never invent. |
| **Agents, skills, hooks** | Five agents whose `tools:` lists are the enforcement, five skills (`bootstrap`, `task`, `adr`, `resume`, `amend`), and eight lifecycle hooks — the load-bearing one being `Stop`, which runs the full gate and blocks the turn ending on failure. |

## A working session

**Day one — `/governed-dev:bootstrap`**, in a repo with no `DESIGN.md` (if one
exists it refuses and points you at `/governed-dev:resume`). It reads your
manifests, lockfiles and test directories, offers its inferences for
correction, then asks what reading cannot: what this project is, who it is
explicitly *not* for, what is out of scope, and what exists versus what is
planned. Decline a question and that section keeps its skeleton comment —
invented prose is indistinguishable from a real decision within a week. It
writes the four ledger documents, `.claude/rules/`, `.gitattributes`, a
placeholder `gate.sh` and an empty `.claude/activity.jsonl`. It does not commit.

**Then `/governed-dev:task`**, which takes the task you name or the first
`todo`, and runs exactly one task to exactly one commit:

```
spec-guardian   SANCTIONED — DESIGN.md §4 "In scope"    ← quotes the sentence
implementer     failing test first, confirmed failing for the right reason
reviewer        NO FINDINGS                             ← real, expected result
scribe          CLAUDE.md and TASKS.md updated
gate            gate: all checks passed.
commit          <scope>: <description>  + Task-Id / Session-Id / Model trailer
```

The gate runs before the commit, never after; a non-zero exit stops the run with
its output quoted, unstaged and unretried. On `main` it commits locally and
declines to push; the task stays `in-progress`, its hash the next commit's job.

**When the spec is silent, the loop stops.** spec-guardian returns `GAP`, names
what `DESIGN.md` does not say, and writes out the exact `SG-NNNN` entry it wants
recorded — which it cannot record itself, holding no write tool. A blocking gap
comes to you; a non-blocking one proceeds only with a `TODO(spec): SG-NNNN`
marker at the line of contact, and check 6 fails any marker whose id is missing
from `DECISIONS.md`. No agent may pick a plausible reading and carry on.

**Next morning, `/governed-dev:resume`.** It runs the orientation script
`SessionStart` runs, reads the ledger rather than the codebase, and reports what
is in flight, the open spec gaps by id, and anything `TASKS.md`, git and the
filesystem disagree about — quoted and unreconciled. It changes nothing.

## What this does not do

The main session thread is **unbounded**, by decision (ADR-0033, closing
SG-0005): it is the human's proxy. The roster's write boundaries bind real
subagents, because the hook event carries `agent_type` only inside one — and
most work happens on the main thread. The separation of duties is what
`/governed-dev:task` buys you. Checks 1–3 trigger on
*declared* tooling, so a project declaring no build, tests or linter passes them
vacuously and says so on stderr: the gate catches declared-but-unrunnable, not
never-declared. The shell half of the write boundary is syntactic — it stops the
expedient redirect, not a determined evasion through a variable or a glob
(ADR-0013). And the reviewer and auditor hold `Bash` permanently; their write
boundary is best-effort by acceptance rather than by capability, with their
outputs gated instead (ADR-0024).

## Running the gate in your CI

The gate is the single contract between a local run and a CI run, so CI runs
**the same script**, not a copy of it. The plugin is not installed on a runner,
so clone it at the tag matching your installed version and point it at your
checkout:

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0          # not the default depth-1 clone -- see below

# ... set up your own build, test and lint tooling here: a declared
# toolchain that is missing is a gate failure, not a skip.

- name: Clone the gate
  run: git clone --depth 1 --branch v0.1.2 https://github.com/ajf42/devseed "$RUNNER_TEMP/devseed"

- name: Gate
  run: CLAUDE_PROJECT_DIR="$GITHUB_WORKSPACE" bash "$RUNNER_TEMP/devseed/plugins/governed-dev/gates/gate.sh"
```

Three things about that are load-bearing:

- **`fetch-depth: 0`.** Two checks resolve the commit hashes your `TASKS.md`
  cites. In a shallow clone none of them resolve and a correct ledger fails —
  which is exactly how devseed's own first matrix run went red on all three
  legs (ADR-0025).
- **The clone goes outside the workspace.** `$RUNNER_TEMP`, not the repository.
  A new top-level directory inside your checkout is drift the guard will report
  against your `CLAUDE.md` structure block, correctly.
- **Pin the tag to the version you installed.** `/plugin` and CI then run the
  same gate. A mismatch is a visible ref rather than a copy that drifted
  silently, which is the whole reason nothing is vendored into your repository.

`jq` is on the GitHub-hosted runner images already; elsewhere, install it. The
gate needs bash, so on a Windows runner set `shell: bash`.

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
bash scripts/boundary-regression.sh        # the agent write-boundary's
bash scripts/bootstrap-regression.sh       # a seeded project's own drift guard
bash scripts/autopilot-regression.sh       # autopilot's routing
claude plugin validate .                   # manifests
```

`scripts/autopilot.sh` runs `/task` headless over the `todo` queue and stops
the moment anything disagrees with the spec, writing what needs deciding to
`reports/`. It routes on the gate's verdict, which it obtains by running the
gate — not on the worker's report of it. It never touches `DESIGN.md`, never
pushes, and commits nothing but its own report. See ADR-0030.

devseed has no build, no tests, and no linter of its own (`DESIGN.md` §3), so
gate checks 1–3 pass vacuously here. Gate bugs involving real tooling are only
findable against a scratch project that declares some — which is what
`gate-regression.sh` builds. Run it after touching anything under `gates/`.

`plugin.json` declares `version` (ADR-0026, superseding ADR-0001 on this point
only): a tool other people install needs a version that is a claim rather than a
moving target. The cost is real — an unbumped commit reaches nobody, so releases
are deliberate and forgetting to bump is silent.
