#!/usr/bin/env bash
# Install the repo's Herdr config and smart-splits-backend-herdr integration.
#
#   ./script/install.sh              # symlink config + link plugin + reload
#   ./script/install.sh --copy       # copy config instead of symlinking
#   ./script/install.sh --bashrc     # also add the bash activity hook to ~/.bashrc
#   ./script/install.sh --monitor    # also run the bash activity monitor as a user service
#   ./script/install.sh --dry-run    # show actions without changing anything
#   ./script/install.sh --herdr-base workspace   # if herdr is missing, install it under $WORKSPACE
#
# If the herdr TUI is not on PATH, it is installed first with herdr.dev's
# installer. Where it goes is chosen like the nvim XDG layout:
#   home       $HOME/.local/bin          (default)
#   workspace  $WORKSPACE/.local/bin     (avoids $HOME quotas)
#   custom     any directory you give
# Without --herdr-base, an interactive run asks; a non-interactive run uses home.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERDR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_CONFIG="$HERDR_DIR/config.toml"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
DST_CONFIG="$CONFIG_DIR/config.toml"
PLUGIN_DIR="${SMART_SPLITS_DIR:-}"
HERDR_INSTALL_URL="https://herdr.dev/install.sh"
HERDR_BASE=""          # home | workspace | custom; empty means ask (tty) or home
HERDR_CUSTOM_DIR=""
HERDR_INSTALL_DIR=""
COPY=0
BASHRC=0
MONITOR=0
DRY_RUN=0

usage() {
    sed -n '2,/^$/p' "$0"
    cat <<EOF

Options:
  --copy                  copy config.toml instead of creating a symlink
  --bashrc                add the bash activity hook block to ~/.bashrc
  --monitor               run the bash activity monitor as a systemd user service
  --smart-splits-dir DIR  use this smart-splits-backend-herdr checkout
  --herdr-base CHOICE     where to install herdr if missing: home, workspace or custom
  --herdr-custom-dir DIR  install herdr into DIR (implies --herdr-base custom)
  --dry-run               print actions without changing anything
  -h, --help              show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --copy) COPY=1 ;;
        --smart-splits-dir)
            shift
            [ "$#" -gt 0 ] || { printf -- '--smart-splits-dir requires a path\n' >&2; exit 2; }
            PLUGIN_DIR="$1"
            ;;
        --herdr-base)
            shift
            [ "$#" -gt 0 ] || { printf -- '--herdr-base requires home, workspace or custom\n' >&2; exit 2; }
            case "$1" in
                home|workspace|custom) HERDR_BASE="$1" ;;
                *) printf 'unknown --herdr-base choice: %s\n' "$1" >&2; exit 2 ;;
            esac
            ;;
        --herdr-custom-dir)
            shift
            [ "$#" -gt 0 ] || { printf -- '--herdr-custom-dir requires a path\n' >&2; exit 2; }
            HERDR_BASE=custom
            HERDR_CUSTOM_DIR="$1"
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

err() { printf 'error: %s\n' "$*" >&2; }

# Ask where the herdr TUI should go. Only runs on a terminal with no --herdr-base.
choose_herdr_base() {
    local choice=""
    printf 'herdr is not on PATH. Install the herdr TUI to:\n'
    printf '  1) $HOME/.local/bin (default)\n'
    printf '  2) $WORKSPACE/.local/bin (WORKSPACE=%s)\n' "${WORKSPACE:-unset}"
    printf '  3) a custom directory\n'
    printf 'choice [1]: '
    read -r choice
    case "${choice:-1}" in
        1) HERDR_BASE=home ;;
        2) HERDR_BASE=workspace ;;
        3)
            HERDR_BASE=custom
            printf 'directory: '
            read -r HERDR_CUSTOM_DIR
            ;;
        *) err "invalid choice: $choice"; exit 2 ;;
    esac
}

# Resolve HERDR_BASE to HERDR_INSTALL_DIR, the directory the installer writes to.
resolve_herdr_install_dir() {
    case "$HERDR_BASE" in
        home)
            HERDR_INSTALL_DIR="$HOME/.local/bin"
            ;;
        workspace)
            if [ -z "${WORKSPACE:-}" ] || [ "$WORKSPACE" = / ] || [ ! -d "$WORKSPACE" ]; then
                err "\$WORKSPACE is ${WORKSPACE:-unset}; set it or pick another --herdr-base"
                exit 1
            fi
            HERDR_INSTALL_DIR="$WORKSPACE/.local/bin"
            ;;
        custom)
            if [ -z "$HERDR_CUSTOM_DIR" ]; then
                err "custom herdr directory is empty"
                exit 1
            fi
            case "$HERDR_CUSTOM_DIR" in
                "~"/*) HERDR_INSTALL_DIR="$HOME/${HERDR_CUSTOM_DIR#"~/"}" ;;
                *) HERDR_INSTALL_DIR="$HERDR_CUSTOM_DIR" ;;
            esac
            ;;
    esac
}

# Make sure the herdr TUI is on PATH before any config is touched.
ensure_herdr() {
    if command -v herdr >/dev/null 2>&1; then
        return 0
    fi
    if [ -z "$HERDR_BASE" ]; then
        if [ -t 0 ]; then
            choose_herdr_base
        else
            HERDR_BASE=home
        fi
    fi
    resolve_herdr_install_dir

    printf '+ curl -fsSL %s | HERDR_INSTALL_DIR=%s sh\n' "$HERDR_INSTALL_URL" "$HERDR_INSTALL_DIR"
    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi
    if ! curl -fsSL "$HERDR_INSTALL_URL" | HERDR_INSTALL_DIR="$HERDR_INSTALL_DIR" sh; then
        err "herdr install failed (see $HERDR_INSTALL_URL)"
        exit 1
    fi
    # Later steps (plugin link, config check, reload) run herdr from this shell.
    local was_on_path=0
    case ":$PATH:" in
        *":$HERDR_INSTALL_DIR:"*) was_on_path=1 ;;
    esac
    PATH="$HERDR_INSTALL_DIR:$PATH"
    export PATH
    if ! command -v herdr >/dev/null 2>&1; then
        err "herdr installed to $HERDR_INSTALL_DIR but is still not runnable"
        exit 1
    fi
    if [ "$was_on_path" -eq 0 ]; then
        printf 'note: %s is not on PATH in your shell rc; add:\n' "$HERDR_INSTALL_DIR"
        printf '      export PATH="%s:$PATH"\n' "$HERDR_INSTALL_DIR"
    fi
}

ensure_herdr

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
# No running server is fine: herdr reads the config when it next starts.
if [ "$DRY_RUN" -eq 1 ]; then
    run herdr server reload-config
elif ! herdr server reload-config >/dev/null 2>&1; then
    printf 'note: no herdr server running; config applies on next start\n'
fi
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
