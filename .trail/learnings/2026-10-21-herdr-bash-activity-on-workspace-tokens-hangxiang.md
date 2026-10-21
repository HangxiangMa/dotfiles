---
title: "herdr: bash activity on workspace tokens, pane labels and tab bar"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 9, tokens: 131535 }
touches:
  - herdr/config.toml
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/script/bash-activity-hook.sh
  - herdr/script/bash-activity-monitor.sh
  - herdr/script/bash-activity-status.sh
---

## Decided
- Workspace side: monitor pushes `BASH=busy|idle` with `herdr workspace report-metadata`. Config shows it with `rows = [["state_icon", "workspace"], ["$BASH"]]` under `[ui.sidebar.spaces]`.
- Pane side: monitor pushes `display_agent = "bash busy|idle"` with `herdr pane report-metadata`. `show_agent_labels_on_pane_borders = true` shows it on the border.
- Tab bar: `tab_bar_right = [{ type = "command", ... }]` runs herdr/script/bash-activity-status.sh every 2s and prints "bash: N busy (labels)" or "bash: idle".
- Workspace state is busy while any of its bash panes is busy. Monitor scans state files for this.
- End-to-end checked in a temp workspace: the pane label, BASH token and status line all went busy during `sleep 3`, then idle.

## Tried and ruled out
- `report-metadata --source herdr:x`: the colon was not the cause. The CLI wants PANE/WORKSPACE id FIRST, then `--source`. Putting the id last gives "unknown option".
- `--state-label`, `--token NAME=VALUE` with `=` form: parse failures in this build. Use `--token NAME=VALUE` after the id.
- `tab_bar_right` placed after `[ui.sidebar.spaces]` is parsed as a key of that section and ignored. Keep `[ui.sidebar.spaces]` at the end of config.toml.

## Watch out
- Live config reloaded with `herdr server reload-config` (no diagnostics). config.toml is a symlink into this repo.
- The command entry uses an absolute repo path because herdr runs it with /bin/sh -c and does not expand ~.
- Not wired into ~/.bashrc yet (user asked to hold). Without the hook and running monitor, the tab bar shows "bash: idle" and no labels change.
- The monitor is not started automatically. Background jobs (&) and subshells are not seen.
