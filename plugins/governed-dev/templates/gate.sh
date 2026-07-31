#!/usr/bin/env bash
# gate.sh -- PLACEHOLDER, deliberately not filled in. See SG-0003.
#
# The working gate lives in the plugin at gates/gate.sh and runs against
# ${CLAUDE_PROJECT_DIR}, so a consumer project needs no local copy for normal
# use. Whether CI should vendor one instead -- ${CLAUDE_PLUGIN_ROOT} does not
# resolve where the plugin is not installed -- is unresolved, and copying a
# second gate here before that is settled would create exactly the drift
# ADR-0002 flagged. Do not fill this in speculatively.
#
# PATH CONVENTION (see ../hooks/hooks.json):
#   This script inspects the CONSUMING PROJECT'S code, rooted at
#   ${CLAUDE_PROJECT_DIR}. It is LOCATED via ${CLAUDE_PLUGIN_ROOT} by the hook
#   that invokes it. Do not reverse these.
#
# Must run on both POSIX shells and Windows (Git Bash / PowerShell-invoked).
# A gate that only runs on one platform is a gate that silently does not run.
set -euo pipefail

echo "gate.sh: placeholder -- no checks defined yet (Prompt 3)" >&2
exit 0
