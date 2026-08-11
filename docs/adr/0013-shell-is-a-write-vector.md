# ADR-0013 — The shell is a write vector; the boundary inspects commands, not just paths

- **Date:** 2026-08-05
- **Status:** Accepted

### Context

`boundary.sh` was wired at `PreToolUse` with the matcher
`Edit|Write|NotebookEdit`. The implementer's `tools:` allowlist includes `Bash`.

Those two facts do not compose. The hook reads `.tool_input.file_path`, which a
`Bash` call does not carry, so the boundary evaluated an empty path, matched
none of its ledger patterns, and **allowed**. `echo x >> DECISIONS.md` was never
a tool it watched. The load-bearing denial in ADR-0007 — the implementer cannot
write `DECISIONS.md` — held for three tools and was absent for a fourth that
reaches the same files.

This was not a bug in the sense of a mistake in logic. It is what happens when a
`tools:` list and a hook matcher are written at different times by different
reasoning, and nothing forces them to be checked against each other. Recorded
here rather than fixed quietly because the class matters more than the instance.

**Alternatives considered:**

- **Drop `Bash` from the implementer and grant a narrower `Bash(pytest:*)`.**
  **Not available.** This was the preferred option on inspection, and it does
  not exist. The `tools:` frontmatter field accepts exact tool names,
  `mcp__<server>` patterns, and `Agent(<type>)`; the parenthesised scoping
  syntax is documented only for `Agent`, and only for an agent running as the
  main thread. `Bash(pytest:*)` is `permissions.allow` syntax from
  `settings.json`, which is session-scoped rather than agent-scoped. There is no
  per-agent `permissions` field. `permissionMode` exists but is a mode, not a
  rule list, and is **ignored for plugin subagents** — which these are, along
  with the per-agent `hooks` and `mcpServers` fields. Verified against the
  subagent reference on 2026-08-05.
- **Drop `Bash` from the implementer entirely.** Rejected: the implementer's
  defining discipline is writing a failing test and *confirming it fails for the
  right reason*, which requires running it. An implementer that cannot execute
  anything cannot do test-first work, and would have to report results it never
  observed — trading a governance hole for a much worse honesty hole.
- **Parse the command and deny only writes into ledger paths.** Rejected as the
  primary test, in favour of the broader one below. Deciding which token in a
  shell command is a redirect target means reasoning about quoting, `eval`,
  heredocs, and command substitution. Every way of getting that wrong fails
  *open*, and a boundary that fails open is not a boundary.
- **Accept the hole and document it.** Rejected. ADR-0007 states that until the
  hook exists the boundary is documentation and `CLAUDE.md` must not describe it
  as enforced. A boundary enforced for three tools out of four is worse than a
  known-absent one: it reads as complete.

### Decision

`boundary.sh` inspects `.tool_input.command` and the `PreToolUse` matcher gains
`Bash|PowerShell`, in both `hooks.json` and the `.claude/settings.json` mirror.

Two predicates, deliberately blunt:

- **The implementer** is denied any shell command that *names* `DESIGN.md`,
  `DECISIONS.md` or `TASKS.md` — not merely one that writes to them. It holds
  `Read` and `Grep` for looking at those files, so over-blocking the shell costs
  it nothing it needs, and "names it" is a predicate that can be evaluated
  correctly where "writes to it" cannot.
- **The read-only agents** (spec-guardian, reviewer, auditor) are denied any
  command containing a shell-level write construct: a redirect other than to
  `/dev/null`, the usual file-mutating commands, or a state-changing `git`
  subcommand.

`PowerShell` is matched although no agent is granted it, because it is in the
built-in set a background subagent retains and a future roster change could
grant it without anyone revisiting this hook.

### Consequences

- **The shell check is syntactic and stops the expedient route, not a determined
  one.** `D=DECI; echo x >> ${D}SIONS.md` defeats it, as does any indirection
  through a variable, a glob, or a program's own file handling. This is stated
  in the hook, in `delegation.md`, and here, because a partial mitigation
  presented as complete is the failure mode this repository exists to prevent.
  The threat model ADR-0007 names is the agent that takes the cheap way out of a
  spec wall, not an adversary.
- **The capability boundary carries the weight the syntactic one cannot.** The
  scribe and spec-guardian hold no shell at all. That is not a matcher and
  cannot be outwitted, and it is why their `tools:` lists matter more than any
  hook.
- **Read-only agents lose benign shell writes.** An auditor cannot write a
  report to a file, and a reviewer cannot `git stash` to test a revert. Accepted:
  both return prose, and the alternative is a carve-out that has to be right
  about which writes are benign.
- **False positives are possible and are denials, not silent passes.** A `>` in
  a quoted string or a filename containing `TASKS.md` will block. Erring closed
  at an enforcement point is the correct direction, and the deny message names
  the command so the agent can rephrase.
- **The `PreToolUse` matcher now differs from `PostToolUse`'s**, which stays
  `Edit|Write|NotebookEdit` — the fast gate should not run on every shell
  command. Drift check 6 compares the two wirings against each other, not the
  two events, so this asymmetry is intentional and unguarded.
- **This coupling has no guard.** Nothing checks that an agent's `tools:` list
  and `boundary.sh` agree about which tools can write. The next tool granted to
  an agent could reopen exactly this hole, and the only thing standing in the
  way is the `*)` branch denying agents the hook does not recognise — which does
  not help when the agent *is* recognised and the tool is not. Recorded as a
  known gap rather than solved here.
