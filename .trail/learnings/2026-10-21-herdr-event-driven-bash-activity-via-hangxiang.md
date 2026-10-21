---
title: "herdr: event-driven bash activity via FIFO (report-agent expires in ~1s)"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 7, tokens: 88570 }
touches:
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/script/bash-activity-hook.sh
  - herdr/script/bash-activity-monitor.sh
  - herdr/bash-activity.sh
---

## Decided
- Bash activity is pushed, not polled: a DEBUG trap sends "busy" before a command and PROMPT_COMMAND sends "idle" at the prompt. EXIT sends "gone". The hook writes to a FIFO and the monitor blocks on `read`, so it uses 0 CPU while idle (measured 0 ticks over 3s).
- The writer opens the FIFO with `1<>` (read-write), so it never blocks when no monitor runs. The hook also checks the monitor pid first.
- Files: herdr/script/bash-activity-hook.sh (sourced from ~/.bashrc) and herdr/script/bash-activity-monitor.sh (per-pane state files under $XDG_RUNTIME_DIR/herdr-bash-activity/state).

## Tried and ruled out
- `pane report-agent --state=working` from bash: herdr expires the state about 1s later, so a long compile cannot be shown. Also registers the pane as an agent named "bash".
- `pane report-metadata`: only `--title` parses in this herdr build. `--state-label`, `--display-agent` and `--source=...` form all fail with "unknown option". Setting the title overrides the agent's own title, which breaks claude's osc_title_working rule.
- OSC title as a busy signal: visible in `pane list` but collides with agent titles.
- netlink proc connector: bind returns EPERM for non-root.

## Watch out
- Not wired into ~/.bashrc and not shown in the herdr sidebar. Only the state files are updated.
- `exit` on the same line as a command fires DEBUG but never returns to the prompt, so the EXIT trap is the only thing that clears it.
- Background jobs (`&`) and commands run from a subshell are not seen.
- shellcheck is not installed on this host, so the scripts were only checked with `bash -n` and manual runs.
