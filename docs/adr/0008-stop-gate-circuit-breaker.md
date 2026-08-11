# ADR-0008 — The Stop gate releases after three consecutive blocks

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

The `Stop` hook runs the full gate and blocks the turn from ending when it
fails. That is the load-bearing mechanism of the whole scaffold — the executable
form of "do not consider a task complete until all steps are done".

It also has no natural exit. Earlier versions of the hooks API passed a
`stop_hook_active` flag so a Stop hook could tell it was already the reason the
session was continuing. **Today's API has no such field** — verified against the
published reference on 2026-07-31, which documents no loop-prevention mechanism
for `Stop` at all. So a gate failure the agent cannot fix — a missing toolchain,
a spec question only the human can settle — produces an unbounded loop: block,
attempt, block, attempt, with no way out but killing the session.

**Alternatives considered:**

- **Block unconditionally, forever.** Rejected. It is the purest reading of "no
  silent degradation", but the failure it produces is not loud, it is *stuck* —
  and a tool that can wedge a session teaches its user to disable it. A gate
  that gets switched off enforces nothing, which is a worse outcome than a gate
  that escalates.
- **Track the flag ourselves from the transcript.** Rejected: it means parsing
  `transcript_path` to infer whether the last stop was hook-induced, which
  couples the hook to an undocumented file format that can change without
  notice, to reconstruct a signal the API no longer offers.
- **Block only on some checks.** Rejected: it makes "done" negotiable per check,
  and the gate is deliberately a single verdict. Any subset is a second
  definition of done that nothing records.
- **Release after one block.** Rejected: one attempt is not an attempt. Most
  gate failures are fixable by the agent on the next edit, which is exactly the
  case the hook exists to catch.

### Decision

`stop-gate.sh` keeps a per-session counter under `.claude/.hook-state/`. It
blocks on gate failure up to three consecutive times, resetting the counter on
any pass. On the fourth it stops blocking and instead emits the gate's failure
plus a `systemMessage` stating that the turn ended **unfinished** and that the
failure has outlived three attempts and is probably not the agent's to fix.

The release is made at least as loud as the block. The block text tells the
agent in advance that the counter exists and that a turn ending that way ends
unfinished, so it can stop and say so rather than burning the attempts.

### Consequences

- A turn *can* end with the gate red. That is a real hole and it is the price of
  not being able to wedge the session. It is visible in the transcript, in the
  `systemMessage`, and in `.claude/activity.jsonl`, which records `gate_result`
  on every session end.
- `3` is a judgement, not a derived number. If it proves wrong the fix is to
  change `MAX_BLOCKS` in `stop-gate.sh`, which is the single place it lives.
- The counter is session-scoped state in the project directory, so the hooks now
  write to the consumer's tree. The gate still does not — that asymmetry is
  stated in `hooks/README.md` so it is not read as an erosion of §5's
  no-side-effects rule.
- If `stop_hook_active` or an equivalent returns to the API, this counter should
  be replaced by it, and this entry superseded.
