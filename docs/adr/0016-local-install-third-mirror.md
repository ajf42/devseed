# ADR-0016 — Local-path plugin install was tested and does not retire the mirrors; skills are a third, deliberate mirror

- **Date:** 2026-08-06
- **Status:** Accepted

### Context

ADR-0011 mirrored the hook wiring, ADR-0014 the agent roster, both because an
installed plugin pins to a commit SHA. ADR-0014 said "a third would be
evidence the pinned-install problem needs solving at its root rather than
mirrored again per artifact." Both ADRs listed "install the plugin from a
local path" as an alternative and rejected it as not reachable from the
documented flow. That premise was tested directly rather than reasoned about.

**What the test found.** `claude plugin marketplace add <path>` **is**
supported — the CLI documents "URL, path, or GitHub repo" and stores source
type `directory`. But `claude plugin install` still copies the plugin into
`~/.claude/plugins/cache/<marketplace>/<plugin>/<sha>` keyed by commit SHA,
exactly as for a GitHub source. An uncommitted working-tree edit is invisible;
`plugin update` reports "already at the latest version". A local commit — no
push, no remote at all — plus `marketplace update`, `plugin update` and a
restart does move the pin. A **non-git** source directory instead gets version
`unknown` and refreshes from the working tree on `plugin update`, but devseed
is a git repository so that branch is unavailable without deleting `.git`.

So the alternative is now reachable but does not solve the problem: it removes
the push/GitHub round trip and nothing else. The working tree is still not the
installed copy.

**Alternatives considered:**

- **Local-path install.** Reachable, but per the evidence above still
  SHA-pinned and still a copy, so it retires nothing.
- **Delete `.git` to get the non-git refresh behaviour.** Rejected: absurd for
  the repository under governance, and it would end version control on the
  thing being governed.
- **Symlink the mirrors.** Already rejected in ADR-0014 because git symlinks
  on Windows need `core.symlinks` plus developer mode and check out as plain
  text files containing a path when unavailable, failing silently.
- **Skip the mirror and accept devseed cannot run its own skills.** Rejected:
  it is the same non-dogfooding ADR-0011 and ADR-0014 both refused, and an
  unrun skill is an unverified one.

### Decision

Add `.claude/skills/` as a third mirror, and extend drift check 6 to
byte-equality it in both directions as it already does for agents. The
threshold ADR-0014 named has been crossed and the root cause was investigated
as that sentence asked; the finding is that the root fix is not available at
this layer.

### Consequences

- Three mirrored artifacts now, guarded but real.
- The pinned-install cost of omitting `version` from `plugin.json` (ADR-0001)
  is now confirmed structural rather than incidental.
- If a future CLI release makes an install track a working tree, all three
  mirrors and their guards should be retired and this entry superseded.
- Byte-equality parity on `.md` files is fragile under `core.autocrlf=true` —
  see SG-0009.
