# Source from ~/.bashrc: . /path/to/herdr/script/bash-activity-hook.sh
# Sends "<pane> busy|idle <shell-pid>" to bash-activity-monitor.sh. DEBUG fires
# before each command and PROMPT_COMMAND when the prompt returns, so nothing polls.
case $- in *i*) ;; *) return 0 ;; esac

_herdr_activity_dir=${HERDR_BASH_ACTIVITY_DIR:-${XDG_RUNTIME_DIR:-/tmp}/herdr-bash-activity}
_herdr_activity_pane=${HERDR_PANE_ID:-pid$$}
_herdr_activity_ws=${HERDR_WORKSPACE_ID:--}
_herdr_activity_busy=

_herdr_activity_send() {
	# Write only while the monitor is alive: a FIFO open with no reader would stall the shell.
	local mon
	mon=$(cat "$_herdr_activity_dir/monitor.pid" 2>/dev/null) || return 0
	kill -0 "$mon" 2>/dev/null || return 0
	printf '%s %s %s %s\n' "$_herdr_activity_pane" "$1" "$$" "$_herdr_activity_ws" 1<>"$_herdr_activity_dir/events"
}

_herdr_activity_debug() {
	[ "$BASH_COMMAND" = _herdr_activity_prompt ] && return
	[ -n "$_herdr_activity_busy" ] && return
	_herdr_activity_busy=1
	_herdr_activity_send busy
}

_herdr_activity_prompt() {
	_herdr_activity_busy=
	_herdr_activity_send idle
}

trap '_herdr_activity_debug' DEBUG
# An exit command fires DEBUG but never returns to the prompt, so report "gone" here.
trap '_herdr_activity_send gone' EXIT
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_herdr_activity_prompt"
