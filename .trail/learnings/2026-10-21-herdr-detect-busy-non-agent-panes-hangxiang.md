---
title: "herdr: detect busy non-agent panes (bash activity)"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 2, tokens: 65601 }
touches:
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
---

## Decided
- Herdr does not report activity for plain shell panes: `pane list` gives `agent_status: unknown` and no foreground process name. Busy detection has to poll `herdr pane process-info --pane <id>`.
- A pane is busy when `foreground_process_group_id` differs from `shell_pid`. An idle bash pane has only `/bin/bash` in the foreground group, and its pgid equals `shell_pid`.

## Tried and ruled out
- `herdr pane list` and `pane get` for activity: they expose `agent_status`, `foreground_cwd` and `terminal_title`, but not the foreground process name.

## Watch out
- Verified only on an idle bash pane. Detection during a real compile (make/ninja) is not yet confirmed.
- Background jobs (`&`, nohup) are not in the foreground group, so they are not seen as busy.
- Whether `pane report-metadata` can show a label on a plain pane is unverified. The sidebar may only show agent state.
