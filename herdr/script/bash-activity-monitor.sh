#!/usr/bin/env bash
# Print busy/idle transitions reported by bash-activity-hook.sh, keep one state
# file per pane, and show the state as an icon on that pane (display_agent).
# Blocks on the FIFO between events, so it uses no CPU while idle.
#
#   ./script/bash-activity-monitor.sh &      # start (one per user)
#   cat "$DIR/state/<pane>"                  # busy or idle, DIR below
#   kill "$(cat "$DIR/monitor.pid")"         # stop
#
# DIR is ${HERDR_BASH_ACTIVITY_DIR:-${XDG_RUNTIME_DIR:-/tmp}/herdr-bash-activity}.

set -eu

DIR="${HERDR_BASH_ACTIVITY_DIR:-${XDG_RUNTIME_DIR:-/tmp}/herdr-bash-activity}"
EVENTS="$DIR/events"
SOURCE=bash-activity

mkdir -p "$DIR/state"
[ -p "$EVENTS" ] || mkfifo -m 600 "$EVENTS"
printf '%s\n' "$$" >"$DIR/monitor.pid"
trap 'rm -f "$DIR/monitor.pid"; exit 0' EXIT HUP INT TERM

# herdr may be unreachable (server stopped, or not inside herdr); a failed push
# must not stop the monitor.
push_pane() {
	if [ -n "$2" ]; then
		herdr pane report-metadata "$1" --source "$SOURCE" --display-agent "$2" >/dev/null 2>&1 || true
	else
		herdr pane report-metadata "$1" --source "$SOURCE" --clear-display-agent >/dev/null 2>&1 || true
	fi
}

# tab bars have no metadata, so the busy dot goes in front of the tab label, as
# the sidebar does ("● name"). The original label is saved once per tab and
# restored when no bash pane in that tab is busy any more.
TABS="$DIR/tabs"
mkdir -p "$TABS"

# Prints "<tab_id> <agent>", with "-" for a plain shell pane.
pane_info() {
	herdr pane get "$1" 2>/dev/null | python3 -I -c '
import json, sys
p = json.load(sys.stdin)["result"]["pane"]
print(p["tab_id"], p.get("agent") or "-")' 2>/dev/null || true
}

# Each state file holds "<state> <pid> <workspace> <tab>".
tab_busy() {
	local f s t
	for f in "$DIR"/state/*; do
		[ -f "$f" ] || continue
		read -r s _ _ t <"$f" || continue
		[ "$s" = busy ] && [ "$t" = "$1" ] && return 0
	done
	return 1
}

push_tab() {
	local tab=$1 pane=$2 state=$3 saved="$TABS/${1//[:\/]/_}" label
	if [ "$state" = busy ]; then
		[ -f "$saved" ] || { label=$(herdr tab list --workspace "${tab%%:*}" 2>/dev/null |
			python3 -I -c '
import json, sys
t = [t for t in json.load(sys.stdin)["result"]["tabs"] if t["tab_id"] == sys.argv[1]][0]
print(t["label"])' "$tab" 2>/dev/null) || return 0
			printf '%s' "$label" >"$saved"; }
		herdr tab rename "$tab" "● $(cat "$saved")" >/dev/null 2>&1 || true
	elif [ -f "$saved" ] && ! tab_busy "$tab"; then
		herdr tab rename "$tab" "$(cat "$saved")" >/dev/null 2>&1 || true
		rm -f "$saved"
	fi
}

while :; do
	# Opening the FIFO blocks until a hook writes; EOF after the writer closes
	# brings us back to the outer loop, which reopens it.
	while read -r pane state pid ws; do
		if [ "$state" = gone ]; then
			# The pane may already be closed, so take its tab from the saved state.
			tab=$(awk 'NR==1{print $4}' "$DIR/state/$pane" 2>/dev/null || true)
			rm -f "$DIR/state/$pane"
			push_pane "$pane" ""
		else
			read -r tab agent <<<"$(pane_info "$pane")" || true
			[ "$agent" != - ] || agent=
			printf '%s %s %s %s\n' "$state" "$pid" "$ws" "$tab" >"$DIR/state/$pane"
			# Agent panes keep herdr's own name, so only plain shell panes get the icon.
			# The tab dot applies to every pane; idle clears both.
			[ -n "$agent" ] || push_pane "$pane" "$([ "$state" = busy ] && printf '●')"
		fi
		[ -n "$tab" ] && push_tab "$tab" "$pane" "$state"
		printf '%s %s %s\n' "$(date '+%T.%3N')" "$pane" "$state"
	done <"$EVENTS"
done
