---
title: "herdr: tab busy dot goes before the label, matching sidebar state_icon"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 4, tokens: 5984 }
touches:
  - herdr/config.toml
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/script/bash-activity-hook.sh
  - herdr/script/bash-activity-monitor.sh
---

## Decided
- The busy dot on a tab label is "● <original>" (dot first), matching the sidebar where state_icon comes before the workspace name. The earlier "<original> ●" form is replaced.

## Watch out
- The saved original name is restored on idle, so a rename made during a busy run is lost.
