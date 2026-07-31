#!/usr/bin/env bash
# Check 1 -- the code builds. Sourced by gate.sh.
CHECK="1/6 build"

if [ -f package.json ] && grep -q '"build"[[:space:]]*:' package.json; then
  have npm || die \
"package.json declares a build script but npm is not on PATH. Install Node.js, or remove the build script. A declared build that cannot run is a failure, not a skip."
  npm run build >/dev/null 2>&1 || die \
"The build failed. Run 'npm run build' in $ROOT, fix every error it prints, then re-run the gate."

elif [ -f Makefile ] && grep -qE '^build:' Makefile; then
  have make || die \
"Makefile declares a 'build' target but make is not on PATH. Install make, or remove the target."
  make build >/dev/null 2>&1 || die \
"The build failed. Run 'make build' in $ROOT, fix every error it prints, then re-run the gate."

elif [ -f pyproject.toml ] || [ -f setup.py ]; then
  PY="$(python_bin)" || die \
"This is a Python project (pyproject.toml/setup.py present) but no working python interpreter was found. Install Python, or remove the manifest."
  if [ -d src ]; then
    "$PY" -m compileall -q src >/dev/null 2>&1 || die \
"Python sources under src/ do not compile. Run 'python -m compileall src' in $ROOT, fix the syntax errors, then re-run the gate."
  else
    note "check 1 (build): Python project with no src/ -- nothing to compile."
  fi

else
  note "check 1 (build): no build declared -- nothing to run."
fi
