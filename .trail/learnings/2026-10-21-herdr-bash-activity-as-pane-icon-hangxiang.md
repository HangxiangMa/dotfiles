---
title: "herdr: bash activity as pane icon only (workspace token and tab bar removed)"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 2, tokens: 22885 }
touches:
  - herdr/config.toml
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/script/bash-activity-hook.sh
  - herdr/script/bash-activity-monitor.sh
---

## Decided
- Show bash activity only on the pane that runs it: `pane report-metadata --display-agent ●` when busy, `--clear-display-agent` when idle. Nothing is written to the workspace.
- Removed the workspace BASH token, the sidebar `$BASH` row and the `tab_bar_right` status command. All three were window-wide, so a busy pane in one workspace showed up in another.

## Tried and ruled out
- Workspace-level summary (BASH token + tab bar): visible in every workspace, so it was the source of the cross-workspace leak the user reported.
- Pane text label `bash busy/idle`: replaced by the icon.

## Watch out
- Restarting the monitor does not clear labels or tokens that the old version wrote. Clear them with `pane report-metadata <id> --source bash-activity --clear-display-agent` (and `workspace report-metadata <ws> --clear-token BASH`).
- When testing in a pane, check the input line first. Leftover text from an earlier `pane run` gets concatenated (`sleep 30sleep 8`) and the command fails immediately, which looks like the hook not firing.
- `herdr pane get` cwd can lag after `cd`; trust `process-info` foreground cwd.
