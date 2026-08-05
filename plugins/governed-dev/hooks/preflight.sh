#!/usr/bin/env bash
#
# preflight.sh -- Setup. Checks that the things these hooks depend on are
# actually present, at install time, loudly.
#
# The dependency that matters is jq. Without it boundary.sh cannot read
# agent_type and blocks every write, and stop-gate.sh cannot emit a block
# reason. Discovering that at the moment a boundary should have fired is the
# worst time to discover it, so it is reported here instead.
#
# Setup cannot block -- its exit code is reported, not enforced. That is the
# whole reason this is a preflight and not a guard: the guarding is done by the
# hooks themselves, each of which fails loudly on its own terms. This exists so
# the failure is legible before it is expensive.
HOOK_NAME="Setup/preflight"
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FAIL=0

if ! have jq; then
  FAIL=1
  { printf 'MISSING: jq\n\n'
    hook_jq_advice
    printf '\nUntil jq is installed:\n'
    printf '  - boundary.sh blocks every Edit and Write, because it cannot tell\n'
    printf '    which agent is writing and will not guess at an enforcement point\n'
    printf '  - stop-gate.sh blocks the end of every turn\n'
    printf '  - orient.sh cannot brief a new session\n'
    printf '  - activity.sh writes no audit records\n\n'
  } >&2
fi

if ! have git; then
  FAIL=1
  printf 'MISSING: git. Every hook here reads repository state; none can work without it.\n\n' >&2
fi

GATE="$(hook_gate)"
if [ ! -f "$GATE" ]; then
  FAIL=1
  { printf 'MISSING: the gate, expected at %s\n' "$GATE"
    printf 'The Stop and PostToolUse hooks have nothing to run. A check that cannot\n'
    printf 'run is a failed check, so both will block rather than skip.\n\n'
  } >&2
fi

# Windows only. hooks.json invokes every script as `bash <path>` in exec form,
# which spawns bash directly with no shell to find it -- so bash must be on
# PATH, not merely installed. ADR-0006 made Git Bash a prerequisite; exec form
# narrows that to bash-on-PATH, and an unmet narrowing means the hooks never run
# at all rather than failing. See SG-0006.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    if ! have bash; then
      FAIL=1
      { printf 'WARNING: bash is not on PATH.\n'
        printf 'These hooks are registered as `bash <script>`; if the harness cannot\n'
        printf 'resolve bash on PATH, none of them run and nothing says so. Add Git\n'
        printf 'Bash to PATH, e.g. C:\\Program Files\\Git\\bin.\n\n'
      } >&2
    fi
    ;;
esac

if [ "$FAIL" = 0 ]; then
  hook_note "preflight passed: jq, git and the gate are all present."
  exit 0
fi

printf 'governed-dev preflight failed. The hooks are installed but will not all\n' >&2
printf 'work until the above is fixed. Setup cannot block, so this is a report.\n' >&2
exit 2
