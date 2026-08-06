# templates/ — distributable seed content

The files in this directory are **copied into a consumer project** by the
bootstrap skill. Nothing here governs devseed itself.

The mirror-image files at this repository's root — `/DESIGN.md`,
`/CLAUDE.md`, `/DECISIONS.md`, `/TASKS.md` — govern devseed's own development
and are **never copied anywhere**. The two sets have the same names and
opposite roles. Before editing a file with one of these names, check which
directory you are in.

| File | Copied to | Becomes, in the consumer project |
|---|---|---|
| `DESIGN.md` | `DESIGN.md` | That project's constitution |
| `CLAUDE.md` | `CLAUDE.md` | That project's current-state record |
| `DECISIONS.md` | `DECISIONS.md` | That project's decision log |
| `TASKS.md` | `TASKS.md` | That project's task ledger |
| `rules/*.md` | `.claude/rules/` | The rule files the shipped agents cite by path |
| `.gitignore` | `.gitignore` | Keeps generated artifacts out of the gate's view |
| `.gitattributes` | `.gitattributes` | Forces LF on `*.sh`, so scripts run off Windows |
| `gate.sh` | `gate.sh` | A documented no-op; the real gate ships in the plugin |
| **this README** | *(not copied)* | Nothing — it describes this directory, not a project |

`{{PROJECT_NAME}}` is the only substitution the four ledger skeletons expect.
The bootstrap skill copies the files and replaces it; everything else is filled
in by whoever adopts the project.

## Two rules for anything added here

**Skeletons, not finished documents.** A skeleton that arrives with opinions
already baked in is an unsanctioned constraint delivered at scale — it would
install invented rules into every project at once. Structure and prompts, not
conclusions.

**No devseed ids.** Nothing shipped from this directory may cite an `ADR-NNNN`
or `SG-NNNN` from devseed's own `DECISIONS.md`. Those ids resolve to nothing in
a consumer's ledger, and the drift guard scans every tracked file — so a
citation here fails the consumer's gate on their first commit, in a repository
they have not touched. State the reasoning in prose instead.
`scripts/bootstrap-regression.sh` enforces this.
