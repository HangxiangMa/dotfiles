#!/usr/bin/env bash
# Install the repo's Herdr config and smart-splits.nvim integration.
#
#   ./script/install.sh              # symlink config + link plugin + reload
#   ./script/install.sh --copy       # copy config instead of symlinking
#   ./script/install.sh --dry-run    # show actions without changing anything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERDR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_CONFIG="$HERDR_DIR/config.toml"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
DST_CONFIG="$CONFIG_DIR/config.toml"
PLUGIN_DIR="${SMART_SPLITS_DIR:-}"
COPY=0
DRY_RUN=0

usage() {
    sed -n '2,7p' "$0"
    cat <<EOF

Options:
  --copy                  copy config.toml instead of creating a symlink
  --smart-splits-dir DIR  use this smart-splits.nvim checkout
  --dry-run               print actions without changing anything
  -h, --help              show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --copy) COPY=1 ;;
        --smart-splits-dir)
            shift
            [ "$#" -gt 0 ] || { printf '%s requires a path\n' "$1" >&2; exit 2; }
            PLUGIN_DIR="$1"
            ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if ! command -v herdr >/dev/null 2>&1; then
    printf 'error: herdr is not installed or not on PATH\n' >&2
    exit 1
fi
if [ ! -f "$SRC_CONFIG" ]; then
    printf 'error: missing %s\n' "$SRC_CONFIG" >&2
    exit 1
fi

if [ -z "$PLUGIN_DIR" ]; then
    for candidate in \
        "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/smart-splits.nvim" \
        "$HOME/.local/share/nvim/lazy/smart-splits.nvim"; do
        if [ -f "$candidate/herdr-plugin.toml" ]; then
            PLUGIN_DIR="$candidate"
            break
        fi
    done
fi
if [ -z "$PLUGIN_DIR" ] || [ ! -f "$PLUGIN_DIR/herdr-plugin.toml" ]; then
    printf 'error: smart-splits.nvim checkout not found\n' >&2
    printf '       install it with Neovim first, or pass --smart-splits-dir DIR\n' >&2
    exit 1
fi

run() {
    printf '+ %s\n' "$*"
    [ "$DRY_RUN" -eq 1 ] || "$@"
}

mkdir_cmd=(mkdir -p "$CONFIG_DIR")
run "${mkdir_cmd[@]}"

if [ "$COPY" -eq 1 ]; then
    if [ -e "$DST_CONFIG" ] || [ -L "$DST_CONFIG" ]; then
        if [ -L "$DST_CONFIG" ]; then
            run rm -f "$DST_CONFIG"
        elif cmp -s "$SRC_CONFIG" "$DST_CONFIG"; then
            printf '%s already matches the repo copy\n' "$DST_CONFIG"
        else
            backup="$DST_CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
            run mv "$DST_CONFIG" "$backup"
            run cp "$SRC_CONFIG" "$DST_CONFIG"
        fi
    else
        run cp "$SRC_CONFIG" "$DST_CONFIG"
    fi
else
    if [ -L "$DST_CONFIG" ] && [ "$(readlink "$DST_CONFIG")" = "$SRC_CONFIG" ]; then
        printf '%s already points to the repo config\n' "$DST_CONFIG"
    else
        if [ -e "$DST_CONFIG" ] || [ -L "$DST_CONFIG" ]; then
            if [ -L "$DST_CONFIG" ]; then
                run rm -f "$DST_CONFIG"
            else
                backup="$DST_CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
                run mv "$DST_CONFIG" "$backup"
            fi
        fi
        run ln -s "$SRC_CONFIG" "$DST_CONFIG"
    fi
fi

run herdr plugin link "$PLUGIN_DIR"
run herdr config check
run herdr server reload-config
printf 'Herdr config installed: %s\n' "$DST_CONFIG"
printf 'smart-splits.nvim linked: %s\n' "$PLUGIN_DIR"
