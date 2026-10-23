---
title: "herdr: busy dot stuck on agent panes after claude starts from bash"
author: Hangxiang
date: 2026-10-23
branch: main
cost: { minutes: 45, tokens: 19655 }
touches:
  - herdr/script/bash-activity-monitor.sh
---

## Decided
- Every busy event starts a watcher for its pane, not only busy agent panes. A claude started at the prompt reports busy while the pane is still plain, so the old rule never watched it.
- The watcher polls `agent get` for up to 30s until the pane hosts an agent, clears the icon there, then reports idle at detection and at each turn end, and busy when the next turn starts.
- Idle clears the icon on every pane, so an agent pane that got `●` while plain is cleared on its next idle.
- At startup the monitor starts a watcher for each busy state left by the previous run.

## Tried and ruled out
- `events.wait` on pane_agent_status_changed / pane_agent_detected: times out on a plain pane, so it cannot wait for an agent to appear.
- `events.subscribe` (pane.updated, pane.agent_detected): acknowledged, but no event arrived in 90s while an agent pane was working.
- `agent wait` on a plain pane: fails at once with agent_not_found.

## Watch out
- `trail check` flags the new comments against the Oct 21 learnings (report-agent, pane labels, HERDR_ENV). The diff makes none of those calls; the matches are on the words pane and agent.
- An agent started more than 30s after its busy event is not watched (shortcut comment in the script).
- Under set -e, a loop whose last command is a false `[ ] && ...` returns 1 and can end the caller. Keep such lines out of the last position in a loop body.
