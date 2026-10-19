#!/usr/bin/env bash
# Restart the Herdr server without losing each pane's working directory.
# Herdr saves the cwd of a pane's root process, so a `cd` made in a nested
# shell is lost. This reads the deepest shell's cwd from /proc, writes it into
# session.json between stop and start, then starts the server again.
#
#   ./script/restart.sh                    # default session, asks first
#   ./script/restart.sh --session NAME     # named session
#   ./script/restart.sh --yes              # skip the confirmation prompt
#   ./script/restart.sh --dry-run          # print the cwd patch, change nothing
#
# Stopping the server kills every pane's process.

set -euo pipefail

SESSION=""
ASSUME_YES=0
DRY_RUN=0
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr"

usage() {
    sed -n '2,11p' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --session)
            shift
            [ "$#" -gt 0 ] || { printf '%s requires a name\n' "$1" >&2; exit 2; }
            SESSION="$1"
            ;;
        --yes) ASSUME_YES=1 ;;
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

HERDR=(herdr)
STATE_DIR="$CONFIG_DIR"
if [ -n "$SESSION" ]; then
    HERDR=(herdr --session "$SESSION")
    STATE_DIR="$CONFIG_DIR/sessions/$SESSION"
fi
SESSION_FILE="$STATE_DIR/session.json"

if [ ! -f "$SESSION_FILE" ]; then
    printf 'error: missing %s (nothing to patch)\n' "$SESSION_FILE" >&2
    exit 1
fi

LIVE_JSON="$(mktemp)"
trap 'rm -f "$LIVE_JSON"' EXIT

# Write {pane_id: cwd} for every live pane to $LIVE_JSON. For each pane, take
# the cwd of the deepest shell under the pane's root process, since that is
# the shell the user is typing into.
python3 - "$LIVE_JSON" "${HERDR[@]}" <<'EOF'
import json, os, subprocess, sys

out, herdr = sys.argv[1], sys.argv[2:]
SHELLS = {"bash", "zsh", "fish", "sh", "tcsh", "csh", "ksh"}

def herdr_json(*args):
    return json.loads(subprocess.run([*herdr, *args], check=True,
                                     capture_output=True, text=True).stdout)

def children(pid):
    kids = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            stat = open(f"/proc/{entry}/stat").read()
        except OSError:
            continue
        # comm is in parentheses and may contain spaces; ppid follows it.
        if int(stat.rsplit(")", 1)[1].split()[1]) == pid:
            kids.append(int(entry))
    return kids

def comm(pid):
    return open(f"/proc/{pid}/comm").read().strip()

def shell_cwd(root_pid, fallback):
    best, best_depth = None, -1
    stack = [(root_pid, 0)]
    while stack:
        pid, depth = stack.pop()
        if depth > 0 and comm(pid) in SHELLS and depth > best_depth:
            best, best_depth = pid, depth
        stack.extend((kid, depth + 1) for kid in children(pid))
    if best is None:
        return fallback
    return os.readlink(f"/proc/{best}/cwd")

result = {}
for pane in herdr_json("pane", "list")["result"]["panes"]:
    pane_id = pane["pane_id"]
    try:
        info = herdr_json("pane", "process-info", "--pane", pane_id)
        root = info["result"]["process_info"]["shell_pid"]
        result[pane_id] = shell_cwd(root, pane["cwd"])
    except (subprocess.CalledProcessError, OSError, KeyError):
        result[pane_id] = pane["cwd"]
with open(out, "w") as f:
    json.dump(result, f)
for pane_id, cwd in result.items():
    print(pane_id, cwd)
EOF
printf '\n'

if [ "$DRY_RUN" -eq 1 ]; then
    printf 'dry run: no changes made\n'
    exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
    printf 'This stops the Herdr server and kills all pane processes. Continue? [y/N] '
    read -r answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) printf 'aborted\n'; exit 1 ;;
    esac
fi

"${HERDR[@]}" server stop
# Herdr writes session.json while shutting down; wait until it is done.
for _ in $(seq 1 50); do
    if ! "${HERDR[@]}" status server 2>/dev/null | grep -q 'status: running'; then
        break
    fi
    sleep 0.2
done

BACKUP="$SESSION_FILE.bak-$(date +%Y%m%d-%H%M%S)"
cp "$SESSION_FILE" "$BACKUP"

# session.json keys panes by internal number; public_pane_numbers maps that
# number to the ws:pN id used by the live pane list.
python3 - "$SESSION_FILE" "$LIVE_JSON" <<'EOF'
import json, sys
path, live_path = sys.argv[1], sys.argv[2]
live = json.load(open(live_path))
data = json.load(open(path))
patched = 0
for ws in data["workspaces"]:
    numbers = ws["public_pane_numbers"]
    for tab in ws["tabs"]:
        for key, pane in tab["panes"].items():
            pane_id = f"{ws['id']}:p{numbers[key]}"
            if pane_id not in live or pane.get("cwd") == live[pane_id]:
                continue
            print(f"{pane_id}: {pane.get('cwd')} -> {live[pane_id]}")
            pane["cwd"] = live[pane_id]
            patched += 1
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print(f"patched {patched} pane cwd value(s)")
EOF

# Start detached so the server outlives this script's terminal.
nohup "${HERDR[@]}" server >> "$STATE_DIR/herdr-server.out" 2>&1 &
disown
sleep 2
"${HERDR[@]}" status server | grep -q 'status: running' \
    || { printf 'error: server did not start, see %s\n' "$STATE_DIR/herdr-server.out" >&2; exit 1; }
printf 'Herdr server restarted with patched pane cwds\n'
