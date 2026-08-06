---
name: bootstrap
description: Seed governance into a project that has none — the four ledger documents, the rule files, .gitignore and .gitattributes, copied from the plugin's templates. Use once, in a repo that has no DESIGN.md. Interviews the human for what it cannot read off the repository, and invents nothing.
allowed-tools: Read, Write, Glob, Grep, Bash
---

You install the governance scaffold into a project that does not have one.

`allowed-tools` above pre-approves these tools; it is **not** a boundary and
nothing here should be read as one. The boundaries in this system are the
agents' `tools:` allowlists and the `PreToolUse` hook.

## Before anything

1. **Refuse to overwrite.** If `DESIGN.md` exists in the target, stop and say so.
   Bootstrapping a governed project is not a repair tool — offer `/resume`
   instead.

   For any *other* file already present, the rule differs by kind, and the
   difference matters:
   - **The ledger documents and the rule files** — report them and leave them
     untouched. Merging someone's `DECISIONS.md` with a skeleton is not a merge,
     it is a corruption of a record.
   - **`.gitignore` and `.gitattributes`** — **append** the missing lines and
     say what you added. These are additive line-oriented config, and leaving an
     existing one untouched is how a project ends up without `*.sh text eol=lf`
     — reproducing the exact CRLF defect seeding it was meant to prevent. Never
     remove or rewrite a line that is already there.
2. **Locate the templates.** `${CLAUDE_PLUGIN_ROOT}/templates/` when running
   from the installed plugin. If that variable is unset or the directory is
   absent — which is the case when this skill runs from a working-tree mirror
   rather than an install — fall back to `plugins/governed-dev/templates/`
   relative to the repository root. Say which one you used. Do not proceed on a
   guess: if neither resolves, stop, because everything below copies from it.
3. **Confirm it is a git repository.** If not, say so and ask before running
   `git init` — creating a repo is not what the human asked for.

## The interview

Copying files is the easy half. The templates are skeletons with
`{{PROJECT_NAME}}` and prompting comments, and they are deliberately free of
opinions, because a default baked into a skeleton installs an unsanctioned
constraint into the project at scale.

So read the repository first — manifests, lockfiles, directory layout, existing
README, test directories, linter configs — and form a picture of the stack and
shape. Then ask the human for what reading cannot tell you:

- **What is this project?** One paragraph, for §1.
- **Who is it for, and who is it explicitly *not* for?** For §2. A system with
  no non-users has no scope.
- **What is out of scope?** For §4. This is the question that pays for itself.
- **What already exists vs. what is planned?** Separates `CLAUDE.md` from
  `TASKS.md`.

Present what you inferred about the stack and ask them to correct it — do not
present inference as fact. Where they decline to answer, **leave the skeleton's
prompting comment in place**. An unanswered section that still says what it
needs is honest; one filled with plausible prose is an invented constraint, and
within a week nothing distinguishes it from a decision someone made. That is the
failure this whole scaffold exists to prevent, and bootstrap is the first place
it can happen.

## What gets written

From `templates/`, copied — not regenerated:

| Source | Destination | Note |
|---|---|---|
| `DESIGN.md` | `DESIGN.md` | substitute `{{PROJECT_NAME}}` |
| `CLAUDE.md` | `CLAUDE.md` | substitute `{{PROJECT_NAME}}` |
| `DECISIONS.md` | `DECISIONS.md` | substitute `{{PROJECT_NAME}}` |
| `TASKS.md` | `TASKS.md` | substitute `{{PROJECT_NAME}}` |
| `rules/*.md` | `.claude/rules/` | all four; the agents cite them by path |
| `.gitignore` | `.gitignore` | append missing lines if one exists |
| `.gitattributes` | `.gitattributes` | append missing lines if one exists |
| `gate.sh` | `gate.sh` | **verbatim.** See below. |

Also create an empty `.claude/activity.jsonl` — the hooks append to it, and a
missing file reads as a hook failure rather than as an unused log.

**`gate.sh` is copied verbatim and is a documented no-op.** Do not generate a
working gate. The real gate ships inside the plugin and runs live against
`${CLAUDE_PROJECT_DIR}` via the hooks, so a consumer project needs no local copy
for normal use, and the declared-tooling detection already lives in the check
scripts — there is nothing to calibrate per project. The template's own comment
explains where the real gate lives. Writing a second gate here would create two
definitions of "done" with no maintainer.

**`.gitattributes` is not optional.** Without `text eol=lf` on `*.sh`, a project
bootstrapped on Windows gets CRLF shell scripts, which fail under dash, WSL and
most Linux CI. Seeding it is the whole reason bootstrap touches git config at
all.

## After

Report what was written, what was left as a skeleton and why, and what the human
still owes each document. Then say plainly that the skills install namespaced —
`/governed-dev:task`, not `/task` — because a "missing" skill is almost always
that.

Do not commit. `/task` owns commits.
