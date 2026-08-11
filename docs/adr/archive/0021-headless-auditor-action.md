# ADR-0021 — Headless auditor runs via `anthropics/claude-code-action`, prompted rather than flagged into identity

- **Date:** 2026-08-11
- **Status:** Proposed — unverified in three specific ways, named below;
  revisit before trusting this workflow to actually run

### Context

T-026 asks for a scheduled, unattended run of the auditor agent. Research
(via the `claude-code-guide` subagent) found an official
`anthropics/claude-code-action`, and confirmed **no CLI or Action flag exists
to make a headless run assume a specific pre-defined subagent's identity** —
the only mechanism is prompting normally and trusting Claude to delegate via
its own Task tool, exactly what an interactive session already does when
`task/SKILL.md` says "invoke [the auditor] directly."

**Alternatives considered:**

- **Wait until subagent-identity invocation is confirmed possible**, rather
  than ship something resting on an unverified mechanism. Rejected for this
  pass: Prompt 8 asked for the workflow, and the same trust-the-prompt
  mechanism already underlies every other headless/interactive invocation of
  the auditor in this repository — this is not a weaker guarantee than what
  already exists, just a newly *unattended* instance of the same one.
- **Raw `claude -p` CLI instead of the official Action**, for direct control
  over output capture. Rejected for this pass: the exact flags (`-p` output
  format, permission-skip mechanism, npm package name) were not confirmed
  before this work paused, and fabricating exact CLI syntax into a CI file
  that will not be exercised until the next scheduled run is worse than using
  the confirmed, documented Action entrypoint.

### Decision

`.github/workflows/audit.yml` uses `anthropics/claude-code-action@v1` with a
prompt that restates the auditor's own brief and a `claude_args` tool
allowlist (`Read,Grep,Glob,Bash`) as defense in depth alongside the prompt
itself — belt and suspenders, not a hard boundary, since no hard boundary is
available headlessly.

### Consequences — three things to verify before trusting this workflow

1. **No `ANTHROPIC_API_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`) secret exists yet.**
   The workflow references `secrets.ANTHROPIC_API_KEY` and will fail closed
   until one is added — not silently invented here.
2. **`steps.auditor.outputs.result` is a guess** at the Action's output field
   name, not confirmed against its actual documented outputs. If wrong, the
   job summary posts empty rather than failing loudly — worth an explicit
   check the first time this runs.
3. **Whether `$GITHUB_STEP_SUMMARY` is reachable from inside the Action's own
   sandboxed tool calls is unconfirmed.** Written to avoid depending on the
   answer — the Action's result becomes a step output, and a separate plain
   shell step does the appending — but if the Action's actual output shape
   differs from (2), both problems compound.

Also open, structurally rather than as a bug: GitHub disables scheduled
workflows after 60 days of repository inactivity. `workflow_dispatch` is
wired as a manual fallback; nothing in this file prevents the schedule itself
from going quiet.
