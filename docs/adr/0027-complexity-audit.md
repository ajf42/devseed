# ADR-0027 — Complexity audit before 0.1

- **Date:** 2026-08-11
- **Status:** Accepted as a record. **Superseded in part by [ADR-0028]** —
  the line below reading "Nothing is removed by this entry" was accurate when
  written and is no longer the state of the repository: the human decided all
  three removals the same day, and ADR-0028 records them. Left standing rather
  than edited, per this file's append-only convention.
- **Correction (ADR-0028):** this entry's claim that the TMPDIR incident has
  no evidence in the record is **wrong**. The incident is real — dangling
  commit `8782c53` truncated all three ledgers and was recovered by a hard
  reset to `f1ad979`. The check behind the claim searched committed history
  and the working tree but not the reflog, and stated a conclusion wider than
  it had tested. ADR-0028 carries the evidence.

### Context

The complement of T-028/ADR-0023. That audit asked *which rules lack checks*
and found enforcement **gaps**. This one asks *which checks lack
justification* and looks for enforcement **excess**. Where the two overlap —
the reviewer/auditor `Bash` tension — this audit cites ADR-0024 and does not
re-open it.

Every mechanism was scored on three questions answered from the record
(`TASKS.md`, `DECISIONS.md`, the regression suites, `git log`, and the GitHub
Actions API), not from memory:

1. **What real, actually-occurred failure does it exist to catch?** No
   citation means speculative, which by this project's own rule is an
   unsanctioned constraint wearing a different hat.
2. **Has it fired correctly in actual work** — not in its own regression
   suite? Never-fired is not disqualifying; it is recorded.
3. **What is its false-positive surface** — how plausibly does it block a
   *correct* change? A gate that cries wolf gets bypassed, and a bypassed
   gate is worse than none, because it still looks like enforcement.

**Two of the three premises motivating this audit did not survive the
record, and are corrected here rather than repeated:**

- **"drift.sh produced the repository's only production bug (the mawk
  regression)."** It did not. Per ADR-0025, verified this session, the
  interval-regex defect in `drift.sh` was **latent and never fired** — the
  awks on all three runner images support intervals, and `gate.sh` stops at
  the first failing check, so `drift.sh` never even ran during the red CI
  run. What actually bricked CI was `gate.yml`'s default depth-1 checkout.
  The repository's real defect history sits elsewhere: the Windows
  drive-letter path mismatch that silently disarmed the implementer
  boundary, `grep -c` returning `"00"` and silently disabling a
  disagreement check, exec form meaning no hook ran at all (all T-005),
  four dangling devseed ids in the shipped templates and an invisible CRLF
  drift in `auditor.md` (T-008, SG-0009), and the four T-012..T-015
  defects. `drift.sh` is nonetheless the largest single component at 672
  lines, which is the premise's true half and reason enough to audit it
  sub-check by sub-check.
- **"This session's TMPDIR incident — a hand-rolled scratch probe
  truncating the real ledgers."** **No such incident is in the record.** No
  commit in this repository's history has ever deleted more than fifty
  lines from `DECISIONS.md`, `TASKS.md` or `CLAUDE.md`; both ledgers grew
  monotonically across this session (`TASKS.md` 664 → 749,
  `DECISIONS.md` 1,907 → 2,129); and the string `TMPDIR` appears in no
  document. This session ran the three sanctioned suites, the gate,
  `drift.sh` and `orient.sh`, and nothing else that writes. A finding built
  on it would fail §6's own evidence bar, which demands a named commit,
  task or session — so no finding is built on it. If it happened in a
  session outside this record, it needs recording before it can be cited.
- **"DECISIONS.md is 1,907 lines, +23% over two sessions."** Directionally
  right, one session stale, and worse than stated: it is now **2,129**.
  Note the authorship — 222 of those lines are ADR-0025 and ADR-0026, both
  written by this session. The trend this audit exists to arrest includes
  the audit's own recent output, and this entry adds to it again.

### The inventory

**Legend.** *Cited* = a real failure in the record that the mechanism exists
to catch. *Fired* = has done its job in actual work, outside its own suite.

**Gate checks 1–7**

| # | Cited incident | Fired for real | False-positive surface | Verdict |
|---|---|---|---|---|
| 1 build | none specific; §5's contract | never (devseed declares no build) | missing toolchain fails a correct change, by design | keep |
| 2 tests | none specific | never here; exercised only in scratch projects | same | keep |
| 3 lint | none specific | never here | same | keep |
| 4 working memory | ADR-0005/T-012 (its own bug, not a catch) | **never — devseed has no `src/` at all**, so it is structurally inert here | keys on `src/` only; forces a CLAUDE.md edit for any `src/` change including pure refactors | keep, never-fired |
| 5 task ledger | **T-015** — a fabricated well-formed hash passed the old format-only check | **yes** — and it is the one check with a *demonstrated* false positive: the red CI run (ADR-0025), where a correct ledger failed on all three legs because the clone was shallow | highest, now fixed at source (`fetch-depth: 0`) | keep |
| 6 spec gaps | the ambiguity rule | **never.** The whole repository contains exactly **one** live `TODO(spec)` marker (`boundary.sh`, SG-0005), and the one real marker-staleness incident (SG-0010) was in a `.md` file, which this check skips by design | negligible | keep, thinnest coverage in the system |
| 7 drift | composite — audited separately below | — | — | — |

**drift.sh, sub-check by sub-check** (672 lines total; sub-checks are not
grandfathered by the script containing them)

| Sub-check | Cited incident | Fired for real | FP surface | Verdict |
|---|---|---|---|---|
| duplication (≥12-word run) | **none.** ADR-0012 argues it from design, not from an incident; no T-012..T-015 defect was a copied-text defect | **never** | **high** — ~90 lines of awk, the largest sub-check; measures copying, not agreement (Known limit), so a legitimate long quotation trips it | **remove** |
| staleness, forward (named paths exist) | T-006's explicit criterion; CLAUDE.md describing files that no longer exist | plausibly (auditor caught CLAUDE.md staleness during T-007) | low — gitignored paths already exempted after a real FP | keep |
| staleness, reverse (dirs on disk are named) | none cited | never | moderate — any new top-level directory blocks until CLAUDE.md is edited | keep |
| budget (≤300, warn 250) | CLAUDE.md's own budget rule | **yes, currently firing** — `CLAUDE.md:257` warns on every run today | very low | keep |
| orphans, ADR/SG ids | **T-008** — four dangling devseed ids in the shipped templates, found before release | **yes** | moderate — every id in prose must resolve; `gate-regression.sh` assembles fixture ids at runtime specifically to dodge it, which is evidence of the pressure | keep |
| orphans, done-task hashes | ADR-0025 (the copies drifted) | duplicate of check 5 | same as check 5 | keep-but-simplify |
| superseded, ADR contiguity | none cited | never | low | keep |
| superseded, git-history deletion walk | **none** — no ADR has ever been deleted | **never** | moderate, and it *degrades silently*: it runs `git show <rev>:DECISIONS.md` once per revision, so cost grows with history, and in a shallow clone it passes while proving nothing | **keep-but-simplify** (drop the walk, keep contiguity) |
| hook parity (jq) | ADR-0011 — the mirror is real and its drift is invisible | never | moderate — requires `jq`; a missing `jq` fails a correct change | keep |
| agent + skill byte-parity | **SG-0009** — CRLF drift in `auditor.md` during T-008 | found by the reviewer, not by the check | **demonstrated FP mechanism**: a plain `git checkout` of a mirrored `.md` on Windows rewrites it CRLF and fails the gate while `git status` shows the tree clean. SG-0009 is still open | keep |

**Hooks, boundary, breaker, CI**

| Mechanism | Cited | Fired for real | FP surface | Verdict |
|---|---|---|---|---|
| `preflight` (Setup) | ADR-0019, T-025 | yes — installs `jq` on the ubuntu leg every run | low | keep |
| `orient` (SessionStart) | its own `grep -c` defect (T-005) | yes, every session | none — cannot block | keep |
| `boundary` (PreToolUse), path half | ADR-0007 | **yes** — blocked a real `Edit` the moment `.claude/settings.json` landed (ADR-0010) | moderate | keep |
| `boundary`, **shell-command inspection** | ADR-0013 — `tools:` cannot express "may not write this file" | **never recorded**; the one live block was an `Edit`, not a command | **high** — syntactic matching over arbitrary shell inside a 315-line script, already needing a `templates/` special-case to avoid false hits | keep, top FP risk |
| `fast-gate` (PostToolUse) | none cited | unrecorded | low — `asyncRewake`, does not block the turn | keep |
| `stop-gate` (Stop) | the load-bearing mechanism | yes, routinely | inherits every check's FP | keep |
| circuit breaker (3 blocks, then release) | ADR-0008 — today's API has no `stop_hook_active`, so an unfixable failure loops forever | never recorded | **inverted** — it exists to stop a wedged session, i.e. to prevent the bypass this audit fears | keep |
| `flush` (PreCompact) | ADR-0009 | unrecorded | none — cannot block | keep |
| `activity` (SessionEnd, SubagentStop) | ADR-0003 | yes, appends | none | keep |
| **`audit.yml`** | T-026 / ADR-0021 | **never — verified against the API: five workflow runs exist in this repository's entire history, all of them `gate`.** It cannot run: no `ANTHROPIC_API_KEY` secret, and ADR-0021 stands at *Proposed — unverified in three specific ways* | n/a — it never executes | **remove** |

### The mirrors, justified from scratch

Three mirrors exist (`.claude/agents/`, `.claude/skills/`, and the hook
wiring in `.claude/settings.json`) because an installed plugin is a copy that
does not track the working tree (ADR-0011, ADR-0014, ADR-0016). The audit
asked whether v0.1.0 and a green matrix retire that reason. They do not — and
the honest answer runs opposite to the question's expectation:

- **Declaring a version made the case stronger, not weaker.** Per ADR-0026,
  verified against the documentation, an install now moves **only when the
  version field is bumped**; before, the version was the commit SHA and an
  install moved whenever `/plugin update` was run. Dogfooding through the
  installed copy is therefore *more* stale after v0.1.0, not less.
- **The green matrix is orthogonal.** CI checks out the working tree and runs
  `gate.sh` from it. It exercises no install at all, so it says nothing about
  whether an installed copy matches this repository.
- ADR-0016's stated retirement condition — a CLI release that makes an
  install track a working tree — has not occurred.

The mirrors survive on a current reason. Their parity checks survive with
them, with the caveat ranked below.

### False-positive ranking

Most plausible blocker of a **correct** change, first:

1. **check 5 / drift's hash re-check** — the only *demonstrated* false
   positive in the repository's history: it failed a correct ledger on all
   three legs (ADR-0025). Root cause fixed; the mechanism was right.
2. **agent/skill byte-parity** — a documented FP *mechanism* that has already
   occurred once: `git checkout` on Windows silently produces CRLF and fails
   the gate against a clean-looking tree (SG-0009, open).
3. **drift duplication** — ~90 lines of awk that cannot distinguish a
   copied rule from a legitimate quotation, protecting against an incident
   that has never happened.
4. **boundary shell inspection** — syntactic matching over arbitrary shell;
   its `templates/` special-case is evidence the surface is real.
5. **superseded git-history walk** — no FP, but silent degradation in a
   shallow clone, which is the CI case.
6. **checks 1–3** — "a missing runner is a failed check" blocks a correct
   change on any machine lacking the toolchain. Deliberate (§5), and the
   most likely source of a consumer's first bad experience.
7. **staleness reverse** and **hook parity (needs jq)** — minor.

### Decision

Recorded as an inventory; the verdicts above stand as this audit's
recommendation. **Nothing is removed by this entry.** Three removals go to
the human, listed in the session summary with one-line reasons: `audit.yml`
(never ran, cannot run, looks like enforcement), drift's duplication
sub-check (no incident, never fired, highest latent FP), and drift's
git-history deletion walk (no incident, never fired, silently inert where it
matters most). Removing either drift sub-check changes §5's documented check
table and therefore requires `/amend` under §6 after approval; `audit.yml` is
not a §5 constraint and needs only approval.

Per this audit's own hard rule, **no new mechanism, check, or file was
created to resolve any finding here** — every finding resolves by deletion,
simplification, or an entry in §5's Known limits.

### Consequences

- Three mechanisms are now on record as **never having fired in real work**
  (check 4, check 6, and every drift sub-check except budget and ADR/SG
  orphans). That is not an argument for removing them — a boundary that has
  never been tested is not thereby useless — but it is the honest baseline
  for the next audit, which should ask whether the number moved.
- **This entry is itself 190 lines of the growth it measures.** The audit
  cannot resolve that; it can only decline to hide it. If the next audit
  finds DECISIONS.md past 2,500 lines, the mechanism to question is the ADR
  format itself, not any check in the inventory.
- The one *demonstrated* false positive and the one *demonstrated* FP
  mechanism (ranks 1 and 2) both come from mechanisms this audit keeps. The
  removal candidates are, in every case, mechanisms that have never fired at
  all — which is the correct shape for a subtraction audit and worth stating,
  because the temptation is to cut what recently hurt.
