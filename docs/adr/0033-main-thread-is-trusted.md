# ADR-0033 — The main session thread is trusted; the roster binds delegated work

- **Date:** 2026-09-09
- **Status:** Accepted

### Context

Two layers enforce the agent roster. An agent's `tools:` allowlist decides
which tools it holds. `hooks/boundary.sh` at `PreToolUse` decides which files
it may touch, by reading `agent_type` from the hook event. Inside a subagent
the field reads `governed-dev:implementer` and so on; on the main
conversation thread — where the human types and where `/task` itself runs —
the field is absent, and `boundary.sh` has always allowed in that case. SG-0005
recorded this as an assumption needing a human decision, since it is the line
that decides whether the roster is enforcement or theatre.

What that means in practice: under `/task` the four loop agents are real
subagents, and the implementer genuinely cannot write `DESIGN.md`,
`DECISIONS.md`, `TASKS.md` or `docs/adr/`. In plain chat the main thread is
the implementer, and nothing stops it rewriting `DESIGN.md` to clear a spec
wall. What binds every thread regardless is the verification layer: the Stop
gate runs the full gate at every turn end and the fast gate on every source
edit. "Done" is universal; "who may write which record" is subagent-only.

**Alternatives considered:**

- **Deny by default when `agent_type` is absent.** Rejected: it makes the
  project unwritable outside a subagent, so every consumer's first edit is
  blocked with no route through.
- **Infer a role for the main thread**, e.g. from a state file `/task` writes
  while it runs, so `boundary.sh` can deny main-thread ledger writes during a
  task. Not rejected on merit — it is the plausible next step — but it is new
  mechanism with no incident behind it (ADR-0027's bar), and the main thread
  holds `Bash` and could remove the file. Filed as a follow-up task rather
  than built here.
- **Leave SG-0005 open.** Rejected: the one file every consumer's hooks run
  would ship with a `TODO(spec)` marker on its most important line, and the
  README's claim of "mechanism rather than prose" would be arguable at first
  contact.

### Decision

The main thread is the human's proxy and is trusted. The roster binds
delegated work. The separation of duties this system is built on is obtained
by running `/task`, which delegates to bound subagents; it is not obtained by
working in plain chat, and nothing here pretends otherwise. SG-0005 is
resolved; the marker in `boundary.sh` becomes a comment citing this entry.

### Consequences

- The "mechanism, not prose" claim is scoped, and the README's "What this
  does not do" paragraph stays. A session doing implementer work on the main
  thread can still rewrite the spec.
- The task-mode state file is the recorded route to narrowing this later,
  and it would be a tightening under §6's ratchet.
