# templates/ — distributable seed content

Everything in this directory is **copied into a consumer project** by the
bootstrap skill (built in Prompt 7). Nothing here governs devseed itself.

The mirror-image files at this repository's root — `/DESIGN.md`,
`/CLAUDE.md`, `/DECISIONS.md`, `/TASKS.md` — govern devseed's own development
and are **never copied anywhere**. The two sets have the same names and
opposite roles. Before editing a file with one of these names, check which
directory you are in.

| File | Filled in by | Becomes, in the consumer project |
|---|---|---|
| `DESIGN.md` | Prompt 2 | That project's constitution |
| `CLAUDE.md` | Prompt 2 | That project's current-state record |
| `DECISIONS.md` | Prompt 2 | That project's decision log |
| `TASKS.md` | Prompt 2 | That project's task ledger |
| `gate.sh` | Prompt 3 | That project's blocking check |

These are skeletons, not finished documents. A skeleton that arrives with
opinions already baked in is an unsanctioned constraint delivered at scale —
it would install invented rules into every project at once. Structure and
prompts, not conclusions.
