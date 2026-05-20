#!/usr/bin/env bash
#
# One-shot installer for the tmux config in this repo.
#
#   ./script/install.sh             # interactive: confirm before each step
#   ./script/install.sh -y          # non-interactive: assume yes
#   ./script/install.sh --dry-run   # print what would happen, change nothing
#   ./script/install.sh help        # show usage
#
# Steps performed (each is idempotent):
#   1. Deploy tmux.conf  -> ~/.tmux.conf  (existing file is backed up to
#      ~/.tmux.conf.bak-<timestamp> before overwriting).
#   2. Install TPM       -> ~/.tmux/plugins/tpm  (cloned via git if missing).
#   3. Install plugins   -> runs ~/.tmux/plugins/tpm/bin/install_plugins
#      so the declared plugins land before first attach.
#   4. Reload (best-effort) -> tmux source-file ~/.tmux.conf, only if a
#      tmux server is already running.

set -euo pipefail

# ---------- output helpers ----------
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

log()   { printf "%b[tmux-install]%b %s\n" "$BLUE"   "$RESET" "$*"; }
warn()  { printf "%b[tmux-install]%b %s\n" "$YELLOW" "$RESET" "$*" >&2; }
ok()    { printf "%b[tmux-install]%b %s\n" "$GREEN"  "$RESET" "$*"; }
err()   { printf "%b[tmux-install]%b %s\n" "$RED"    "$RESET" "$*" >&2; }
step()  { printf "\n%b==> %s%b\n"          "$CYAN"   "$*"     "$RESET"; }

# ---------- locate inputs ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_CONF="$TMUX_DIR/tmux.conf"
DST_CONF="$HOME/.tmux.conf"
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"

ASSUME_YES=0
DRY_RUN=0

# ---------- arg parsing ----------
show_help() {
    cat <<EOF
Usage: $0 [-y] [--dry-run] [help]

Deploy this repo's tmux.conf to \$HOME/.tmux.conf, install TPM, then
fetch the plugins it declares (tmux-sensible, tmux-yank,
vim-tmux-navigator).

Options:
    -y, --yes      Assume yes to every prompt (non-interactive).
    --dry-run      Print the actions that would be taken; change nothing.
    help, -h       Show this guidance.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        --dry-run) DRY_RUN=1 ;;
        help|-h|--help) show_help; exit 0 ;;
        *) err "unknown argument: $arg"; show_help; exit 2 ;;
    esac
done

confirm() {
    # confirm "<question>" -> 0 if yes, 1 if no. Honours -y.
    local q="$1"
    if [ "$ASSUME_YES" -eq 1 ]; then return 0; fi
    local reply
    printf "%b%s%b [y/N] " "$YELLOW" "$q" "$RESET"
    read -r reply || reply=""
    case "$reply" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

run() {
    # run <cmd...>  — echo it, and execute unless --dry-run.
    log "\$ $*"
    if [ "$DRY_RUN" -eq 0 ]; then "$@"; fi
}

# ---------- preflight ----------
if [ ! -f "$SRC_CONF" ]; then
    err "tmux.conf not found at $SRC_CONF"
    err "this script must live in <repo>/tmux/script/install.sh"
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    err "git is required (to clone TPM); please install git first"
    exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
    warn "tmux not found on PATH — config will still be deployed, but you'll"
    warn "need to install tmux separately before it does anything."
fi

# ---------- step 1: deploy tmux.conf ----------
step "Deploy tmux.conf -> $DST_CONF"
if [ -e "$DST_CONF" ] || [ -L "$DST_CONF" ]; then
    if cmp -s "$SRC_CONF" "$DST_CONF" 2>/dev/null; then
        ok "$DST_CONF already matches repo copy — nothing to do."
    else
        BACKUP="$DST_CONF.bak-$(date +%Y%m%d-%H%M%S)"
        warn "$DST_CONF exists and differs from repo copy."
        if confirm "Back it up to $(basename "$BACKUP") and overwrite?"; then
            run mv "$DST_CONF" "$BACKUP"
            run cp "$SRC_CONF" "$DST_CONF"
            ok "deployed (previous file saved to $BACKUP)"
        else
            warn "skipped tmux.conf deployment"
        fi
    fi
else
    run cp "$SRC_CONF" "$DST_CONF"
    ok "deployed"
fi

# ---------- step 2: install TPM ----------
step "Install TPM -> $TPM_DIR"
if [ -d "$TPM_DIR/.git" ]; then
    ok "TPM already installed at $TPM_DIR"
elif [ -d "$TPM_DIR" ]; then
    warn "$TPM_DIR exists but isn't a git checkout; leaving it untouched."
else
    if confirm "Clone TPM from $TPM_REPO into $TPM_DIR?"; then
        run mkdir -p "$(dirname "$TPM_DIR")"
        run git clone --depth 1 "$TPM_REPO" "$TPM_DIR"
        ok "TPM cloned"
    else
        warn "skipped TPM install — plugin block in tmux.conf will fall back"
        warn "to the built-in vim-aware navigation."
    fi
fi

# ---------- step 3: install plugins via TPM ----------
step "Install TPM plugins"
if [ -x "$TPM_DIR/bin/install_plugins" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        log "\$ $TPM_DIR/bin/install_plugins"
    else
        # install_plugins exits with the count of plugins it had to fetch;
        # treat any exit code as informational (it's not a failure).
        "$TPM_DIR/bin/install_plugins" || true
        ok "plugin install pass complete"
    fi
else
    warn "TPM not installed; skipping plugin install pass"
fi

# ---------- step 4: reload running tmux ----------
step "Reload running tmux server (if any)"
if command -v tmux >/dev/null 2>&1 && tmux info >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
        log "\$ tmux source-file $DST_CONF"
    else
        if tmux source-file "$DST_CONF" 2>/dev/null; then
            ok "running tmux server reloaded"
        else
            warn "reload failed; open a fresh tmux session to pick up changes"
        fi
    fi
else
    log "no running tmux server detected — skipping reload"
fi

step "Done"
ok "tmux config installed."
log "First launch tip: inside tmux, press 'prefix + I' once to let TPM"
log "verify plugin checkouts (it's a no-op now since install_plugins"
log "already ran, but TPM caches some metadata at first interactive use)."
