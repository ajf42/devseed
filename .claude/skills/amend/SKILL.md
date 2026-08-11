---
name: amend
description: Execute DESIGN.md §6's amendment procedure — ADR first, human approval, then the edit. Refuses to run out of order, refuses "it was slowing us down" as evidence, and applies the ratchet: a tightening proceeds, a loosening demands the full bar. Use when a rule in DESIGN.md needs to change. Does not commit.
allowed-tools: Read, Grep, Glob, Edit, Bash, Agent
---

You execute the amendment procedure in `DESIGN.md` §6, in §6's order, and you
refuse to execute it in any other order. You are the only sanctioned route to
editing `DESIGN.md`. That is not a privilege — it is a chokepoint, and the
chokepoint is the point.

`allowed-tools` above pre-approves these tools; it is **not** a boundary. Read
§6 before every run — it may have been amended since this skill was written,
and §6 wins over this file wherever they disagree.

## First: is this an amendment at all?

- **A correction** — prose catching up to the script (§5's rule), a typo, a
  broken link — needs no ADR and does not need you. Say so and stop; whoever
  found it can fix it directly.
- **Code drifted from the spec and someone wants the spec moved to match** —
  refuse outright. `precedence.md` forbids it and §6 restates it: an
  amendment is prompted by evidence the *rule* is wrong, never by the
  existence of code that violates it. This is the one edit an amendment tool
  must not make easy.
- **A change to what is permitted, required, or forbidden** — an amendment.
  Continue.

## Then: which direction does the ratchet turn?

Read the change against §6's ratchet. **Tightening** — narrowing what passes,
adding a check, extending coverage — needs no ADR. Say that plainly, apply
the edit (§5's table included if it changed, as a correction), and stop.

**Loosening** — weakening a check, widening an exemption, deleting a rule —
takes the full procedure below. If the direction is genuinely unclear, treat
it as loosening; misfiling a loosening as a tightening is the silent change
§6 exists to prevent.

## The procedure, for a loosening

1. **Interview for the ADR.** §6 names what it must contain, and you must not
   fill a hole with plausible prose:
   - the rule, **quoted as currently written** — read `DESIGN.md`, do not
     paraphrase from memory;
   - the specific incident: a commit, task, or session where the rule failed
     to catch what it exists to catch, or caught what it should not — one
     example **per failure claimed**. "It was slowing us down" fails the bar,
     and §6 says why: every gate slows you down; that is what a gate is. If
     the human cannot name an incident, the amendment is not ready — say so
     and stop. That is a correct outcome, not an obstruction.
   - the replacement, as exact text;
   - what the replacement makes harder. If the answer offered is "nothing,"
     push back once — §6 calls an all-upside amendment advocacy — and record
     a genuine cost or record that none could be named, flagged as such.
2. **Record the ADR** in `DECISIONS.md`, in the house format, via the scribe
   (the deciding and the recording stay separated, per `delegation.md`).
3. **Get explicit human approval of the recorded ADR** — a yes to the ADR as
   written, not to the general idea. No approval, no edit.
4. **Only then edit `DESIGN.md`**, applying the replacement text exactly and
   citing the ADR number at the change. Run the full gate afterward:
   `bash plugins/governed-dev/gates/gate.sh` must exit 0.

## What you never do

- **Never edit `DESIGN.md` before steps 1–3 are done.** Out of order is the
  failure mode, not a shortcut.
- **Never commit.** `/task` owns commits. Report what changed and stop.
- **Never run the emergency-bypass path.** A bypass (§6) is something a human
  does under pressure, with its trailer and its reconciliation task. It is
  not an amendment and this skill has no role in it beyond reminding whoever
  bypassed of the two obligations.
