#!/usr/bin/env bash
# Check 7 -- structural drift between the ledger documents and the repository.
# Sourced by gate.sh.
#
# The logic lives in drift.sh, not here, because T-006 requires it to be
# runnable on its own (CI, T-009) and because it accumulates every finding
# rather than dying on the first -- a drift report is only useful whole. This
# file is the adapter: run it as a subprocess, pass its output through, and
# turn its exit code into the gate's.
CHECK="7/7 drift"

if [ ! -f "$HERE/drift.sh" ]; then
  die "drift.sh is missing from $HERE. The gate is incomplete; restore it rather than skipping."
fi

bash "$HERE/drift.sh" || exit 2
