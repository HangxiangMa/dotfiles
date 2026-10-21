---
title: "bash-activity icon must not replace an agent pane's name"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 4, tokens: 102609 }
touches:
  - herdr/script/bash-activity-monitor.sh
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/script/install.sh
  - herdr/systemd/herdr-bash-activity.service
---

## Decided
- The monitor sets the pane icon only on plain shell panes (no agent from pane get). Agent panes keep herdr's own name. The tab dot still applies to every pane.

## Tried and ruled out
- Icon on every pane: the bash shell stays busy while Claude runs, so --display-agent ● replaced the claude label on an agent pane (seen on w8:p4).

## Watch out
- Clear a stale ● with: herdr pane report-metadata <pane> --source bash-activity --clear-display-agent
- Restart herdr-bash-activity.service after editing the monitor.
