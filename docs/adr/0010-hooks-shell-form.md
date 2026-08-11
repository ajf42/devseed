# ADR-0010 — Hooks are registered in shell form, not exec form

- **Date:** 2026-07-31
- **Status:** Accepted

### Context

Hook commands can be written two ways. **Exec form** sets an `args` array and
spawns the command directly with no shell, so every argument is passed verbatim
— a project path containing spaces cannot split, and no quoting is needed.
**Shell form** passes a command string to a shell, which tokenizes it; the
harness uses Git Bash for this on Windows.

Exec form is the documented recommendation wherever a path placeholder appears,
and it was what T-005 built first. It does not work here.

Exec form resolves `command` against `PATH`. On this machine Git Bash is
installed at `C:\Program Files\Git\bin\bash.exe` and `bash` does **not** resolve
on `PATH` — confirmed by `Get-Command bash` returning nothing. Under exec form
every hook would fail to spawn: no gate, no boundary, no orientation, and no
error attributable to any of them. ADR-0006 established Git Bash as a Windows
prerequisite but said nothing about `PATH`, and the two are not the same claim.

This is the failure mode the whole project is built against. A gate that cannot
run fails loudly by design; a hook whose command cannot be spawned does not run,
enforces nothing, and announces nothing.

**Alternatives considered:**

- **Keep exec form and add `C:\Program Files\Git\bin` to `PATH`.** Rejected as
  the primary fix: it makes correct operation depend on a machine setting no
  file in the repository can assert, and it fails silently again on the next
  machine. It remains a fine thing to do, but it cannot be the mechanism.
- **Keep exec form with an absolute `command` path to `bash.exe`.** Rejected:
  correct on exactly one machine, broken on every other and on POSIX entirely.
- **Ship both and let one win.** Rejected: matching hooks are deduplicated by
  command string, not by intent, so both would run — two gates per turn, and
  two `Stop` hooks racing to block.

### Decision

Shell form, with `"shell": "bash"` set explicitly and every path placeholder
wrapped in double quotes. This applies to both `plugins/governed-dev/hooks/`
`hooks.json` and devseed's own `.claude/settings.json` (ADR-0011).

The quoting recovers what exec form was wanted for: a project path containing
spaces still cannot split. `"shell": "bash"` keeps the harness from falling back
to PowerShell on Windows, where these bash scripts would not run.

**Verified live, unintentionally and conclusively.** Immediately after
`.claude/settings.json` was written in shell form, the `PreToolUse` boundary
hook fired on the very next `Edit` and blocked it — proving the wiring resolves
Git Bash without `PATH`, and that the boundary enforces.

### Consequences

- **SG-0006 is resolved by this entry.** The gap asked whether exec form's
  narrowing of ADR-0006 was acceptable. It was not; the narrowing is gone.
- A project path containing a `$`, a backtick or an apostrophe can still break
  shell form where exec form would not have. That is a far rarer condition than
  "Git Bash is not on `PATH`", and unlike it, it fails visibly.
- `preflight.sh` lost its bash-on-`PATH` check. Under shell form the condition
  cannot arise — if the script is running, bash was found — and a check that
  cannot fail reads as coverage while providing none.
- `hooks.json` carries this reasoning in `_CONVENTION_SHELL_FORM`, because the
  next reader's instinct will be to "fix" it back to the documented default.
