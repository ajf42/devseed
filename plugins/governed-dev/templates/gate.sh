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
# Bash, and on Windows that means Git Bash -- a stated prerequisite (DESIGN.md
# §3, ADR-0006). A gate that only runs on one platform silently does not run.
#
# Deliberately NOT `set -e`: with -e a failed command exits 1, and Claude Code
# treats exit 1 as a non-blocking error and proceeds anyway. A gate that returns
# 1 is a gate that does nothing. Control exit codes explicitly -- 0 pass, 2 fail.
set -uo pipefail

echo "gate.sh: placeholder -- the working gate ships in the plugin at gates/" >&2
exit 0
