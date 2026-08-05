#!/usr/bin/env bash
# Check 3 -- linter and formatter are clean. Sourced by gate.sh.
CHECK="3/7 lint"
_ran=0

if [ -f .eslintrc ] || [ -f .eslintrc.json ] || [ -f .eslintrc.cjs ] || [ -f eslint.config.js ]; then
  have npx || die \
"ESLint is configured but npx is not on PATH. Install Node.js, or remove the ESLint config."
  npx --no-install eslint . >/dev/null 2>&1 || die \
"ESLint reported problems. Run 'npx eslint .' in $ROOT and fix everything it lists, then re-run the gate."
  _ran=1
fi

if [ -f ruff.toml ] || [ -f .ruff.toml ] || { [ -f pyproject.toml ] && grep -q 'ruff' pyproject.toml; }; then
  # As with pytest, a module-only install counts.
  _rf=""
  if have ruff; then
    _rf="ruff"
  elif _py="$(python_bin)" && "$_py" -m ruff --version >/dev/null 2>&1; then
    _rf="$_py -m ruff"
  fi
  [ -n "$_rf" ] || die \
"Ruff is configured but not installed (neither on PATH nor as a module). Install it ('pip install ruff'), or remove the configuration."
  $_rf check . >/dev/null 2>&1 || die \
"Ruff reported lint problems. Run '$_rf check .' in $ROOT and fix everything it lists, then re-run the gate."
  $_rf format --check . >/dev/null 2>&1 || die \
"Formatting is not clean. Run '$_rf format .' in $ROOT, then re-run the gate."
  unset _rf _py
  _ran=1
fi

[ "$_ran" = 1 ] || note "check 3 (lint): no linter configured -- nothing to run."
unset _ran
