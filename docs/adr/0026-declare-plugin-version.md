# ADR-0026 — `plugin.json` declares `version`, superseding ADR-0001 on the distribution question only

- **Date:** 2026-08-11
- **Status:** Accepted

### Context

devseed is being prepared for people other than its author to install. Three
things blocked that; this ADR covers the second. ADR-0001 decided:

> `plugin.json` deliberately **omits `version`**. For a solo,
> actively-iterated tool, every commit being the current version is the right
> default. A version string gets pinned only once another project depends on
> stability across a specific release — at which point the need is real
> rather than anticipated.

That condition has now been met, on ADR-0001's own terms: the need is real
rather than anticipated. Nothing about the reasoning was wrong; the
circumstance it was conditioned on changed.

**The mechanics, checked against the plugin documentation rather than
assumed** — because the premise this change was requested under is partly
inverted, and recording an inverted premise as rationale would install a
false belief in the log that later work would reason from. Claude Code
resolves a plugin's version from the first of: `plugin.json`'s `version`,
the marketplace entry's `version`, then **the git commit SHA of the plugin's
source** — which covers devseed, whose marketplace entry uses a relative-path
source in a git-hosted marketplace. From there:

| | Update behaviour | Documented as best for |
|---|---|---|
| **Omit `version`** (state before this ADR) | users get updates whenever the source's resolved commit changes | internal/team plugins under active development |
| **Set `version`** (this ADR) | users get updates **only when the field is bumped**; pushing commits without bumping has no effect and `/plugin update` reports "already at the latest version" | published plugins with stable release cycles |

So the widely-held reading in this repository — that omitting `version` is
what makes an install "go stale silently", and that declaring one fixes it —
is backwards about the fix. Under SHA versioning a user who runs
`/plugin update` converges on the current commit. Under an explicit version,
a user who runs `/plugin update` gets **nothing** until the maintainer bumps
the field. What the repository actually observed (ADR-0011: an install pinned
eleven commits behind, `gates/` empty) is real, but its cause is that nobody
ran the update — third-party marketplaces have auto-update **off** by
default — not that the SHA scheme freezes anything permanently.

The change is still right, for the reason ADR-0001 named rather than the one
in circulation: a published tool needs a version that is a **claim**, not a
moving target. "0.1.0" names what a given install contains, survives a force-
push, gives release notes and a tag something to hang off, and lets someone
else say which devseed they are running. Auto-tracking `main` is the correct
default for a solo tool and the wrong one for a shared one — a colleague
whose gate silently changes behaviour mid-week has no way to attribute the
change.

**Alternatives considered:**

- **Keep omitting `version`.** Rejected: it optimizes for the author, who
  can read git log, at the expense of every other installer, who cannot
  distinguish "the plugin changed" from "my project changed".
- **Put the version in the marketplace entry instead** of `plugin.json`.
  Rejected: `plugin.json` wins where both are set, so the marketplace entry
  would be a second copy with no maintainer — the failure mode
  [`ledger.md`](.claude/rules/ledger.md) exists to prevent, in a manifest.
- **Start at `1.0.0`.** Rejected: `0.x` communicates that the interface may
  still move, which is true — the consumer half of SG-0003 is open and
  `templates/gate.sh` is still a placeholder.
- **Adopt an explicit version *and* keep publishing from `main`.** Not
  rejected so much as named as the residual duty: see the first consequence.

### Decision

`plugins/governed-dev/.claude-plugin/plugin.json` declares
`"version": "0.1.0"`. The marketplace entry stays versionless so there is one
copy of the fact. ADR-0001 is superseded **only** on the version-omission
paragraph; its plugin/governance split, directory layout, and the reasoning
behind them are untouched and remain in force.

This is a distribution decision, not a constraint change. `DESIGN.md` states
no rule about the manifest's version field, and no gate check reads it —
verified by grep across `gates/`, `hooks/` and `scripts/` — so §6's
amendment procedure does not apply and no ratchet is engaged. The prose
passages in `README.md`, `CLAUDE.md` and `.claude/settings.json` that
describe the omission as deliberate become false on this commit and are
corrected in the same commit, per §5's rule that prose catches up to reality.

### Consequences

- **A duty is created that did not exist before: an unbumped commit reaches
  nobody.** Every release now requires bumping the field, and forgetting is
  silent in the direction that matters — users stay on 0.1.0 indefinitely
  while `main` moves. This is strictly more maintainer obligation than the
  scheme it replaces, and it is the price of a version that means something.
- The three mirrors (ADR-0011, ADR-0014, ADR-0016) become **more** necessary,
  not less: the installed copy now moves only on version bumps, so devseed
  dogfooding through the installed plugin would be staler than before. Their
  rationale is unchanged and their retirement condition (ADR-0016: a CLI
  release that makes an install track a working tree) is unaffected.
- `claude plugin validate --strict` **has not been run.** The `claude` CLI is
  not installed on the machine this change was made on, so the claim that
  `--strict` becomes usable once a version is declared is *unverified* and is
  recorded as such rather than asserted. `CLAUDE.md` says so; T-035 carries
  the verification as an open follow-up. A claim about a check that nobody
  ran is exactly what check 5 exists to reject in the ledger, and it does not
  become acceptable in prose.
- No `CHANGELOG.md` yet. The documentation recommends one alongside explicit
  versions; it is deliberately not created here, since an empty changelog is
  a maintenance obligation with no content. It becomes worth adding at the
  first bump — the first moment it would have something to say.
