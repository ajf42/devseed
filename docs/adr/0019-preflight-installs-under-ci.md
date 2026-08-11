# ADR-0019 — `preflight.sh` installs under CI, still only reports on a

developer machine

- **Date:** 2026-08-11
- **Status:** Proposed — built, not yet run in anger; revisit if this is wrong

### Context

Prompt 8 (T-025) asks the `Setup` hook to *install* dependencies, not merely
detect them, "so a fresh clone or a CI container becomes gate-ready in one
command." The existing `preflight.sh` only ever reported and advised. The
prompt does not say whether install-on-detect should also apply to an
interactive developer session, and that is not a neutral gap: a Setup hook
that silently runs a package manager on someone's own machine is a materially
different act than the same behaviour inside a disposable CI container nobody
is sitting at.

**Alternatives considered:**

- **Install everywhere, CI or not.** Rejected: `Setup` fires on `claude
  --init-only` and `-p --init`, both explicit developer-invoked actions, but
  "explicit" is not the same as "consented to a package manager write." A
  human running `--init-only` to prepare a project has not necessarily agreed
  to `sudo apt-get install`, and the existing report-and-advise behaviour
  already works and is tested.
- **Never auto-install; require a human to run the printed command.**
  Rejected: it satisfies safety but not the prompt's actual ask — "a CI
  container becomes gate-ready in one command" specifically names the
  unattended case Prompt 8 wants solved.
- **Install only under `$CI`.** Chosen. `$CI` is a convention GitHub Actions,
  GitLab CI, and most other CI systems already set, so no new signal needed
  inventing, and it draws the line exactly where "disposable, unattended
  container" stops being true.

### Decision

`preflight.sh` installs `jq` via `apt-get` when `$CI` is set and `apt-get` is
on `PATH`; otherwise it reports and advises, unchanged from before. Verifying
the test runner and linter are present is delegated to `gate.sh --fast`
rather than re-implemented, so "what counts as declared tooling" has exactly
one definition (checks 1–3), not two drifting copies.

### Consequences

- Non-Linux CI runners (or ones without `apt-get`) fall back to report-only,
  silently — `have apt-get` is the only gate on the install path. Untested
  against anything but a GitHub Actions `ubuntu-latest` runner.
- `preflight.sh` now runs the full declared build/test/lint on every `Setup`
  event, not just a presence probe. Heavier than "present," but avoids a
  second, narrower detection implementation. Revisit if this makes `--init`
  noticeably slow on a real project with a real suite.
- `git` and bash-on-PATH stay report-only in every environment; Prompt 8 named
  installation for "jq, the test runner, and the linter," not for `git`
  itself.
