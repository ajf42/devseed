# ADR-0036 — `templates/DESIGN.md` seeds §5 and §6 rather than prompting for them

- **Date:** 2026-09-09
- **Status:** Accepted

### Context

The shipped `templates/DESIGN.md` left every section as a prompting comment,
on ADR-0002's rule that a template arriving with opinions installs an
unsanctioned constraint into every project at once. For §6 that produced a
deadlock, observed live on the first real bootstrap:

- the template's own header says changes to the file go through §6 and
  nothing else;
- `skills/amend/SKILL.md` executes §6 in §6's order and refuses otherwise;
- §6 shipped as a comment ending "Until this section is written, there is no
  sanctioned path for editing this document";
- and writing §6 is itself a change to the file.

So the only sanctioned route to editing `DESIGN.md` required §6, and writing
§6 required editing `DESIGN.md`. Bootstrap had correctly disclosed two of its
own inferences and pointed at §6 to overturn them, and §6 was empty.

§5 has the same shape one step removed. It describes the contract the shipped
`gate.sh` already enforces — exit 0/2 never 1, no side effects, a check that
cannot run is a failed check, CI parity, the seven checks and the conventions
they depend on. Left blank, the section documents nothing while the gate goes
on enforcing all of it, which is the drift `precedence.md` exists to detect,
shipped by default.

The distinction ADR-0002 was actually protecting is **opinion versus
mechanism**. A default build rule is an opinion and must not ship. The
procedure `/amend` implements and the contract `gate.sh` implements are
mechanism: they are already true of every project that installs the plugin,
and writing them down is description, not imposition.

**Alternatives considered:**

- **Interview for §6 during bootstrap.** Rejected: it produces a second
  amendment procedure per project, hand-written, with no maintainer, diverging
  from the skill that actually runs it — the same argument bootstrap already
  makes about not generating a second `gate.sh`. It also asks the human to
  invent governance before they have written a line of the project.
- **Drop §6's chokepoint from the shipped header** so an empty §6 is not a
  deadlock. Rejected: it removes the mechanism instead of supplying it, and
  `/amend` would still refuse.
- **Seed §5 whole, including build rules.** Rejected: what a given project's
  build must satisfy is exactly the opinion ADR-0002 forbids shipping. §5 is
  therefore split — contract seeded, project's own rules prompted.

### Decision

`templates/DESIGN.md` ships §5 and §6 filled in, each opening with a note
saying why it arrives seeded and that a project rewriting it takes on keeping
the shipped skill and gate in step. §5's second half, "This project's build
rules", stays a prompted slot. `bootstrap/SKILL.md` is told not to interview
for either section, and — separately — to record a spec-gap entry for **every**
section it leaves skeletal, naming what the section does not say and what is
unenforced or unreachable while it stays empty. `bootstrap-regression.sh`
gains section 8, asserting the seeded text against the *seeded project* rather
than against `templates/`, and its assertions were verified to fail on a
blanked §6 before being accepted.

### Consequences

- **A consumer inherits procedure text they did not write**, in a voice that
  is not theirs, and may not read it as carefully as text they authored. This
  is the real cost, and it is the reason the two sections open by saying they
  are seeded and why.
- **Two copies of the amendment procedure now exist** — devseed's own §6 and
  the shipped one — differing deliberately (ids, dates and incidents stripped),
  so byte equality cannot guard them. This is the SG-0011 problem extended
  from the rule files to a template section, with the same mitigation: hand
  maintenance, and a note at the point of contact.
- Silence in a skeletal section now costs a spec-gap entry, so an unanswered
  section is distinguishable from a settled one. That is more ceremony at
  bootstrap than before, deliberately.
- `templates/DESIGN.md` roughly triples in length. A longer template is
  read less carefully; the mitigation is that the added text is the part a
  consumer is least expected to edit.
