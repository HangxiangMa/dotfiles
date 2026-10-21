#!/usr/bin/env bash
# Add the bash activity hook to ~/.bashrc, between marker lines so it can be
# found and removed later. The hook is inert outside herdr (see the hook file).
#
#   ./script/install-bashrc.sh              # add the block if missing
#   ./script/install-bashrc.sh --remove     # delete the block
#   ./script/install-bashrc.sh --dry-run    # show what would change

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/bash-activity-hook.sh"
BASHRC="${BASHRC:-$HOME/.bashrc}"
BEGIN="# >>> herdr bash-activity >>>"
END="# <<< herdr bash-activity <<<"
REMOVE=0
DRY_RUN=0

usage() {
    sed -n '2,7p' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --remove) REMOVE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [ "$REMOVE" -eq 0 ] && [ ! -f "$HOOK" ]; then
    printf 'error: missing %s\n' "$HOOK" >&2
    exit 1
fi

run() {
    printf '+ %s\n' "$*"
    [ "$DRY_RUN" -eq 1 ] || "$@"
}

has_block() {
    [ -f "$BASHRC" ] && grep -qxF "$BEGIN" "$BASHRC"
}

# Copy ~/.bashrc aside before changing it, with a timestamp suffix.
backup() {
    local bak="$BASHRC.bak-$(date +%Y%m%d-%H%M%S)"
    run cp -p "$BASHRC" "$bak"
}

# Drop the lines between the markers, inclusive, and the blank line added before
# the block. awk keeps every other line as is.
# shortcut: a file that did not end in a newline gains one after --remove, since
# the install step cannot tell that case from a normal file; bash ignores it.
strip_block() {
    awk -v b="$BEGIN" -v e="$END" '
        $0 == "" && !skip { held = $0; have = 1; next }
        $0 == b { skip = 1; have = 0; next }
        skip && $0 == e { skip = 0; next }
        skip { next }
        have { print held; have = 0 }
        { print }
        END { if (have) print held }
    ' "$BASHRC"
}

if [ "$REMOVE" -eq 1 ]; then
    if ! has_block; then
        printf 'no herdr bash-activity block in %s\n' "$BASHRC"
        exit 0
    fi
    backup
    if [ "$DRY_RUN" -eq 0 ]; then
        tmp=$(mktemp "$BASHRC.XXXXXX")
        strip_block >"$tmp"
        chmod --reference="$BASHRC" "$tmp"
        mv "$tmp" "$BASHRC"
    else
        printf '+ remove block from %s\n' "$BASHRC"
    fi
    printf 'removed herdr bash-activity block from %s\n' "$BASHRC"
    exit 0
fi

if has_block; then
    printf 'herdr bash-activity block already in %s\n' "$BASHRC"
    exit 0
fi

backup
block=$(printf '%s\n%s\n%s\n' "$BEGIN" "[ -r \"$HOOK\" ] && . \"$HOOK\"" "$END")
if [ "$DRY_RUN" -eq 0 ]; then
    printf '\n%s\n' "$block" >>"$BASHRC"
else
    printf '+ append to %s:\n%s\n' "$BASHRC" "$block"
fi
printf 'added herdr bash-activity block to %s\n' "$BASHRC"
