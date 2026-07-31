#!/usr/bin/env bash
# gate.sh -- placeholder. Prompt 3 fills this in.
#
# Copied into a consumer project as its blocking check.
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
