#!/bin/bash
# End-to-end sanity check. Runs user-level by default; pass -y to
# auto-accept sudo prompts for apt-dependent components.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
EXTRA_ARGS=("$@")

echo "=== Testing basic installation (prefix=$PREFIX) ==="
printf "N\n" | "$SCRIPT_DIR/requirements.sh" basic --prefix="$PREFIX" "${EXTRA_ARGS[@]}"

echo "=== Testing component installation ==="
components=(1 2 3 4 5 6 7 8 9 10 11)
for comp in "${components[@]}"; do
	echo "--- Testing component $comp ---"
	# Two stdin lines: the component choice, and 'N' if a secondary prompt
	# (sudo or nvim-config confirm) appears. Extra 'N's are ignored.
	printf '%s\nN\nN\n' "$comp" | "$SCRIPT_DIR/requirements.sh" component --prefix="$PREFIX" "${EXTRA_ARGS[@]}"
done

echo "=== Verifying installations ==="
export PATH="$PREFIX/bin:$PREFIX/nvim-linux-x86_64/bin:$PREFIX/nvim-linux-arm64/bin:$PATH"
for cmd in nvim lazygit yazi batgrep clangd lua-language-server fd bat; do
	if command -v "$cmd" >/dev/null 2>&1; then
		echo "[OK]   $cmd -> $(command -v "$cmd")"
	else
		echo "[MISS] $cmd not on PATH (may have required declined sudo)"
	fi
done
python3 -c "import venv" 2>/dev/null && echo "[OK]   python3 venv" || echo "[MISS] python3 venv"
python3 -c "import debugpy" 2>/dev/null && echo "[OK]   python3 debugpy" || echo "[MISS] python3 debugpy"

echo "All tests completed. Review output above for any [MISS] entries."
