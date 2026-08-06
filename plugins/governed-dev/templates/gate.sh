#!/usr/bin/env bash
# gate.sh -- PLACEHOLDER, deliberately not filled in.
#
# The working gate ships inside the governed-dev plugin and runs against
# ${CLAUDE_PROJECT_DIR} via the hooks, so this project needs no local copy for
# normal use. Its checks detect your build, tests and linter from evidence in
# the repository -- a package.json build script, a tests/ directory, a linter
# config -- so there is nothing to calibrate here per project.
#
# Whether CI should vendor a copy instead is a separate, open question:
# ${CLAUDE_PLUGIN_ROOT} does not resolve where the plugin is not installed, so
# CI either vendors the gate or installs the plugin first. Filling this in
# before that is decided would create a second definition of "done" with no
# maintainer, drifting from the real one from the day it was written.
#
# PATH CONVENTION (see the plugin's hooks/hooks.json):
#   A gate inspects THIS PROJECT'S code, rooted at ${CLAUDE_PROJECT_DIR}. It is
#   LOCATED via ${CLAUDE_PLUGIN_ROOT} by the hook that invokes it. Do not
#   reverse these -- both reversals fail silently.
#
# Bash, and on Windows that means Git Bash -- a stated prerequisite. A gate that
# only runs on one platform is a gate that silently does not run.
#
# Deliberately NOT `set -e`: with -e a failed command exits 1, and Claude Code
# treats exit 1 as a non-blocking error and proceeds anyway. A gate that returns
# 1 is a gate that does nothing. Control exit codes explicitly -- 0 pass, 2 fail.
set -uo pipefail

echo "gate.sh: placeholder -- the working gate ships in the plugin at gates/" >&2
exit 0
