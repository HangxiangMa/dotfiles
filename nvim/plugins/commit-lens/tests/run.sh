#!/bin/bash
# commit-lens test runner.
#
# Each tests/case_*.lua is a self-contained headless-nvim test: it builds a
# throwaway git repo, drives the plugin's public API, asserts on the resulting
# extmarks, then prints "PASS <name>" and quits 0 — or writes "FAIL <name>: …" to
# stderr and quits non-zero (via :cq). This script runs each case in its own clean
# `nvim --headless -u NONE` process and reports a summary. Exit code is non-zero if
# any case fails, so it works in CI.
#
# No external test framework — matches the repo's existing shell-smoke-script
# convention (cf. nvim/script/test_install.sh). nvim and git must be on PATH.
#
# Usage:
#   tests/run.sh                 # run every case
#   tests/run.sh core async      # run only the named cases
#   NVIM_TREE_DIR=/path tests/run.sh   # point the nvim-tree case at a checkout
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# nvim is required; syntax-check + run need it.
if ! command -v nvim >/dev/null 2>&1; then
	echo "run.sh: nvim not found on PATH" >&2
	exit 1
fi
if ! command -v git >/dev/null 2>&1; then
	echo "run.sh: git not found on PATH" >&2
	exit 1
fi

# Byte-compile every Lua file first: a syntax error should fail fast and loud,
# separate from a behavioral assertion failure. luac is optional; skip if absent.
if command -v luac >/dev/null 2>&1; then
	for f in "$SCRIPT_DIR"/*.lua "$SCRIPT_DIR"/../lua/commit-lens/*.lua "$SCRIPT_DIR"/../lua/commit-lens/tree/*.lua; do
		if ! luac -p "$f"; then
			echo "run.sh: syntax error in $f" >&2
			exit 1
		fi
	done
fi

# Which cases to run: named args, or all case_*.lua.
cases=()
if [ "$#" -gt 0 ]; then
	for name in "$@"; do
		cases+=("$SCRIPT_DIR/case_$name.lua")
	done
else
	for f in "$SCRIPT_DIR"/case_*.lua; do
		cases+=("$f")
	done
fi

pass=0
fail=0
failed_names=()

for case_file in "${cases[@]}"; do
	if [ ! -f "$case_file" ]; then
		echo "run.sh: no such case: $case_file" >&2
		fail=$((fail + 1))
		failed_names+=("$(basename "$case_file")")
		continue
	fi
	name="$(basename "$case_file" .lua)"
	# -u NONE: no user config. -n: no swapfile (files may be open elsewhere).
	# The case file drives everything and quits with 0 (pass) or non-zero (fail).
	out="$(nvim --headless -n -u NONE -c "lua dofile('$case_file')" 2>&1)"
	code=$?
	if [ "$code" -eq 0 ]; then
		pass=$((pass + 1))
		# Surface the PASS/SKIP line the case printed.
		echo "$out" | grep -E "^(PASS|SKIP) " || echo "PASS $name"
	else
		fail=$((fail + 1))
		failed_names+=("$name")
		echo "----- $name FAILED -----"
		echo "$out"
		echo "------------------------"
	fi
done

echo ""
echo "commit-lens tests: $pass passed, $fail failed"
if [ "$fail" -gt 0 ]; then
	echo "failed: ${failed_names[*]}" >&2
	exit 1
fi
exit 0
