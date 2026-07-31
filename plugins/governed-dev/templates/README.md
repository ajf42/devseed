# templates/ — distributable seed content

Everything in this directory is **copied into a consumer project** by the
bootstrap skill (built in Prompt 7). Nothing here governs devseed itself.

The mirror-image files at this repository's root — `/DESIGN.md`,
`/CLAUDE.md`, `/DECISIONS.md`, `/TASKS.md` — govern devseed's own development
and are **never copied anywhere**. The two sets have the same names and
opposite roles. Before editing a file with one of these names, check which
directory you are in.

| File | Status | Becomes, in the consumer project |
|---|---|---|
| `DESIGN.md` | skeleton ready | That project's constitution |
| `CLAUDE.md` | skeleton ready | That project's current-state record |
| `DECISIONS.md` | skeleton ready | That project's decision log |
| `TASKS.md` | skeleton ready | That project's task ledger |
| `gate.sh` | placeholder (T-004) | That project's blocking check |

`{{PROJECT_NAME}}` is the only substitution these skeletons expect. The
bootstrap skill (T-008) copies the files and replaces it; everything else is
filled in by whoever adopts the project.

These are skeletons, not finished documents. A skeleton that arrives with
opinions already baked in is an unsanctioned constraint delivered at scale —
it would install invented rules into every project at once. Structure and
prompts, not conclusions.
