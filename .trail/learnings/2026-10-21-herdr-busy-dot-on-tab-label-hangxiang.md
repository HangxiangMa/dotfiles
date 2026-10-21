---
title: "herdr: busy dot on tab label (tab has no metadata)"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 9, tokens: 32127 }
touches:
  - herdr/config.toml
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/script/bash-activity-hook.sh
  - herdr/script/bash-activity-monitor.sh
---

## Decided
- herdr tabs have no metadata API (tab.* is create/list/get/focus/rename/move/close), so a tab cannot show a status icon. The monitor renames the tab to "<original> ●" while any bash pane in it is busy and restores the original when none is.
- The original label is saved once per tab in $DIR/tabs/ and restored from there. Each pane state file is "<state> <pid> <workspace> <tab>".

## Tried and ruled out
- tab.report-metadata / a tab display field: not in the API schema.
- Workspace agent_status: aggregated from agents and not writable.

## Watch out
- The tab label is the user's data. If the user renames the tab during a busy run, the restore step writes back the saved name, overwriting the rename.
- A tab label check must read `herdr tab list --workspace <ws>`, not the pane list.
- Earlier the dot was only on the pane, so the user did not see it on the tab bar. That was the gap, not a display bug.
