#!/usr/bin/env bash
# Install the repo's Herdr config and smart-splits-backend-herdr integration.
#
#   ./script/install.sh              # symlink config + link plugin + reload
#   ./script/install.sh --copy       # copy config instead of symlinking
#   ./script/install.sh --bashrc     # also add the bash activity hook to ~/.bashrc
#   ./script/install.sh --monitor    # also run the bash activity monitor as a user service
#   ./script/install.sh --dry-run    # show actions without changing anything

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERDR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_CONFIG="$HERDR_DIR/config.toml"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
DST_CONFIG="$CONFIG_DIR/config.toml"
PLUGIN_DIR="${SMART_SPLITS_DIR:-}"
COPY=0
BASHRC=0
MONITOR=0
DRY_RUN=0

usage() {
    sed -n '2,7p' "$0"
    cat <<EOF

Options:
  --copy                  copy config.toml instead of creating a symlink
  --bashrc                add the bash activity hook block to ~/.bashrc
  --monitor               run the bash activity monitor as a systemd user service
  --smart-splits-dir DIR  use this smart-splits-backend-herdr checkout
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
        --bashrc) BASHRC=1 ;;
        --monitor) MONITOR=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# The monitor unit is rendered under $WORKSPACE. Refuse before changing anything
# if it is unset, or the unit would point at paths under the root directory.
if [ "$MONITOR" -eq 1 ] && { [ -z "${WORKSPACE:-}" ] || [ "$WORKSPACE" = / ] || [ ! -d "$WORKSPACE" ]; }; then
    printf 'WARNING: $WORKSPACE is %s; refusing --monitor and making no changes.\n' "${WORKSPACE:-unset}" >&2
    printf '         Set WORKSPACE (e.g. export WORKSPACE=$HOME) in your shell rc and re-run.\n' >&2
    exit 1
fi

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
        "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/smart-splits-backend-herdr" \
        "$HOME/.local/share/nvim/lazy/smart-splits-backend-herdr"; do
        if [ -f "$candidate/herdr-plugin.toml" ]; then
            PLUGIN_DIR="$candidate"
            break
        fi
    done
fi
if [ -z "$PLUGIN_DIR" ] || [ ! -f "$PLUGIN_DIR/herdr-plugin.toml" ]; then
    printf 'error: smart-splits-backend-herdr checkout not found\n' >&2
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
printf 'smart-splits-backend-herdr linked: %s\n' "$PLUGIN_DIR"

if [ "$BASHRC" -eq 1 ]; then
    bashrc_args=()
    [ "$DRY_RUN" -eq 1 ] && bashrc_args+=(--dry-run)
    "$SCRIPT_DIR/install-bashrc.sh" "${bashrc_args[@]}"
fi

if [ "$MONITOR" -eq 1 ]; then
    UNIT_TMPL="$HERDR_DIR/systemd/herdr-bash-activity.service.in"
    # The user manager does not inherit XDG_CONFIG_HOME from the shell, so it reads $HOME/.config.
    UNIT_DIR="$HOME/.config/systemd/user"
    UNIT_DST="$UNIT_DIR/herdr-bash-activity.service"
    MON_PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/herdr-bash-activity/monitor.pid"

    # Render the template into a real file (not a symlink) so paths follow $WORKSPACE on this host.
    # shortcut: values are substituted into sed as-is, so a path containing '|' or '&' breaks the unit.
    render_unit() {
        sed -e "s|@WORKSPACE@|$WORKSPACE|g" \
            -e "s|@MONITOR@|$HERDR_DIR/script/bash-activity-monitor.sh|" \
            "$UNIT_TMPL" >"$UNIT_DST"
    }

    run mkdir -p "$UNIT_DIR"
    [ -L "$UNIT_DST" ] && run rm -f "$UNIT_DST"
    run render_unit
    printf 'rendered %s with WORKSPACE=%s\n' "$UNIT_DST" "$WORKSPACE"
    run systemctl --user daemon-reload

    # A monitor started by hand would hold the FIFO, so stop it before the service starts.
    if [ -f "$MON_PID_FILE" ] && ! systemctl --user is-active --quiet herdr-bash-activity.service; then
        manual_pid=$(cat "$MON_PID_FILE" 2>/dev/null || true)
        if [ -n "$manual_pid" ] && kill -0 "$manual_pid" 2>/dev/null; then
            run kill "$manual_pid"
            # Wait for it to exit so the FIFO is free before the service opens it.
            if [ "$DRY_RUN" -eq 0 ]; then
                for _ in 1 2 3 4 5 6 7 8 9 10; do
                    kill -0 "$manual_pid" 2>/dev/null || break
                    sleep 0.2
                done
            fi
        fi
    fi
    run systemctl --user enable --now herdr-bash-activity.service
fi
