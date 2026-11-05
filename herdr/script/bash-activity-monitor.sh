#!/usr/bin/env bash
# Print busy/idle transitions reported by bash-activity-hook.sh, keep one state
# file per pane, and show the state as an icon on that pane (display_agent).
# Blocks on the FIFO between events, so it uses no CPU while idle.
#
# A command running in a plain pane shows busy only while the pane produces output
# (see watch_output). The hook brackets the command; the output decides the dot.
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
# Polls (about one a second) without pane output before a running command shows idle.
QUIET_SECS=3
# run/<pane>: a hook-started command is still running in the pane.
# output/<pane>: pid of the output watcher for that pane.
RUN="$DIR/run"
OUT="$DIR/output"

mkdir -p "$DIR/state" "$RUN" "$OUT"
[ -p "$EVENTS" ] || mkfifo -m 600 "$EVENTS"
printf '%s\n' "$$" >"$DIR/monitor.pid"
trap 'kill $(jobs -p) 2>/dev/null; rm -f "$DIR/monitor.pid"; exit 0' EXIT HUP INT TERM

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

# An agent keeps its shell busy for the whole session, and a claude started at the
# prompt reports busy before herdr sees the agent, so every hook busy event starts a
# watcher for its pane. The watcher waits for the agent, then reports the agent's
# own turns (busy while it works, idle when it stops), since the shell reports only
# the start and end of the session. It runs in the background, one per pane.
WATCH="$DIR/watch"
mkdir -p "$WATCH"

watch_agent() {
	local pane=$1 i=0
	# Poll until the pane hosts an agent, while the command is still running (run marker).
	# herdr's events.wait cannot match agent detection, so this is the only polling.
	# shortcut: an agent that starts more than 30s after its busy event is not watched, upgrade if claude starts that late.
	while ! herdr agent get "$pane" >/dev/null 2>&1; do
		i=$((i + 1))
		if [ "$i" -gt 30 ] || [ ! -f "$RUN/$pane" ]; then
			rm -f "$WATCH/$pane"
			return 0
		fi
		sleep 1
	done
	# The busy shell may have set the icon while the pane was still plain; agent panes keep herdr's name.
	push_pane "$pane" ""
	# Idle first: it clears the busy shell that started the agent. Then one busy and
	# one idle per turn. The loop ends when the pane is no longer an agent.
	while :; do
		herdr agent wait "$pane" --until idle --until done --until blocked >/dev/null 2>&1 || break
		printf '%s idle 0 -\n' "$pane" 1<>"$EVENTS"
		herdr agent wait "$pane" --until working >/dev/null 2>&1 || break
		printf '%s busy 0 -\n' "$pane" 1<>"$EVENTS"
	done
	rm -f "$WATCH/$pane"
	printf '%s idle 0 -\n' "$pane" 1<>"$EVENTS"
}

start_watch() {
	local pane=$1
	[ -f "$WATCH/$pane" ] && kill -0 "$(cat "$WATCH/$pane")" 2>/dev/null && return 0
	watch_agent "$pane" &
	printf '%s\n' "$!" >"$WATCH/$pane"
}

# A plain pane's running command shows busy while the pane produces output. herdr's
# pane revision is a counter that moves with output and stays still for an idle
# shell or a silent program such as nvim. The watcher sends "active" when the
# revision moves after a quiet spell, and "quiet" after QUIET_SECS polls (one a second)
# without a change. It stops when an agent appears in the pane: watch_agent reports
# that pane from then on.
watch_output() {
	local pane=$1 spid=$2 sws=$3 info rev last= still=0 quiet=0
	while sleep 1; do
		info=$(herdr pane get "$pane" 2>/dev/null) || info=
		case $info in *'"agent":"'*) return 0 ;; esac
		rev=$(printf '%s' "$info" | grep -o '"revision":[0-9]*' || true)
		if [ "$rev" != "$last" ]; then
			last=$rev still=0
			if [ "$quiet" = 1 ]; then
				quiet=0
				printf '%s active %s %s\n' "$pane" "$spid" "$sws" 1<>"$EVENTS"
			fi
		elif [ "$quiet" = 0 ] && [ $((still += 1)) -ge "$QUIET_SECS" ]; then
			quiet=1
			printf '%s quiet %s %s\n' "$pane" "$spid" "$sws" 1<>"$EVENTS"
		fi
	done
}

start_output() {
	local pane=$1
	stop_output "$pane"
	watch_output "$@" &
	printf '%s\n' "$!" >"$OUT/$pane"
}

stop_output() {
	local f=$OUT/$1
	[ -f "$f" ] || return 0
	kill "$(cat "$f")" 2>/dev/null || true
	rm -f "$f"
}

# Watchers do not survive a monitor restart. A busy state left by a previous monitor
# gets its run marker, watch_agent and output watcher back.
for f in "$DIR"/state/*; do
	[ -f "$f" ] || continue
	if [ "$(cut -d' ' -f1 "$f")" = busy ]; then
		pane=${f##*/}
		read -r _ spid sws _ <"$f"
		: >"$RUN/$pane"
		start_watch "$pane"
		start_output "$pane" "$spid" "$sws"
	fi
done

while :; do
	# Opening the FIFO blocks until a hook writes; EOF after the writer closes
	# brings us back to the outer loop, which reopens it.
	while read -r pane state pid ws; do
		if [ "$state" = gone ]; then
			# The pane may already be closed, so take its tab from the saved state.
			stop_output "$pane"
			rm -f "$RUN/$pane"
			tab=$(awk 'NR==1{print $4}' "$DIR/state/$pane" 2>/dev/null || true)
			rm -f "$DIR/state/$pane"
			push_pane "$pane" ""
		else
			# Output events come from watch_output; they count only while a command runs.
			if [ "$state" = active ] || [ "$state" = quiet ]; then
				[ -f "$RUN/$pane" ] || continue
			fi
			read -r tab agent <<<"$(pane_info "$pane")" || true
			[ "$agent" != - ] || agent=
			case $state in
				active|quiet)
					# An agent's turns are reported by watch_agent, not by output.
					[ -z "$agent" ] || continue
					if [ "$state" = active ]; then state=busy; else state=idle; fi
					;;
				busy|idle)
					# Hook events carry the shell pid and bracket the command; watch_agent sends pid 0.
					if [ "$pid" != 0 ]; then
						if [ "$state" = busy ]; then
							: >"$RUN/$pane"
							if [ -z "$agent" ]; then start_output "$pane" "$pid" "$ws"; fi
							# A busy pane may turn into an agent, so every hook busy event gets a watcher.
							start_watch "$pane"
						else
							rm -f "$RUN/$pane"
							stop_output "$pane"
						fi
					fi
					;;
			esac
			printf '%s %s %s %s\n' "$state" "$pid" "$ws" "$tab" >"$DIR/state/$pane"
			# Agent panes keep herdr's own name, so a busy shell only gets the icon on a plain
			# pane. Idle clears it on every pane, including one that became an agent while busy.
			if [ "$state" = idle ] || [ -z "$agent" ]; then
				push_pane "$pane" "$([ "$state" = busy ] && printf '●')"
			fi
		fi
		[ -n "$tab" ] && push_tab "$tab" "$pane" "$state"
		printf '%s %s %s\n' "$(date '+%T.%3N')" "$pane" "$state"
	done <"$EVENTS"
done
