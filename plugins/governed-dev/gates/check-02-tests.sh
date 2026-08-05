#!/usr/bin/env bash
# Check 2 -- the test suite passes. Sourced by gate.sh.
CHECK="2/7 tests"

if [ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json; then
  have npm || die \
"package.json declares a test script but npm is not on PATH. Install Node.js. A declared test suite that cannot run is a failure, not a skip."
  npm test >/dev/null 2>&1 || die \
"Tests failed. Run 'npm test' in $ROOT, fix the failing tests, then re-run the gate."

elif [ -d tests ] || [ -d test ]; then
  # pytest is often installed as a module without a PATH entry. Both count;
  # treating the module-only install as "missing" would block a working setup.
  _pt=""
  if have pytest; then
    _pt="pytest"
  elif _py="$(python_bin)" && "$_py" -m pytest --version >/dev/null 2>&1; then
    _pt="$_py -m pytest"
  fi
  [ -n "$_pt" ] || die \
"A tests/ directory exists but pytest is not installed (neither on PATH nor as a module). Install it ('pip install pytest'). A test suite that cannot run is a failed check -- silent degradation is exactly what this gate exists to prevent."
  $_pt -q >/dev/null 2>&1 || die \
"Tests failed. Run '$_pt' in $ROOT, fix the failures, then re-run the gate."
  unset _pt _py

else
  note "check 2 (tests): no test suite found -- nothing to run."
fi
