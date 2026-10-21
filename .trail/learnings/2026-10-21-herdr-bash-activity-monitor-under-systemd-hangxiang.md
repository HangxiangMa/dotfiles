---
title: herdr bash-activity monitor under systemd user service
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 1, tokens: 5377 }
touches:
  - herdr/script/install.sh
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/systemd/herdr-bash-activity.service
---

## Decided
- --monitor links the unit into $HOME/.config/systemd/user, not $XDG_CONFIG_HOME/systemd/user. The user manager does not inherit XDG_CONFIG_HOME from the shell, so it only reads $HOME/.config.
- The unit sets Environment=PATH (includes ~/.local/bin, where herdr lives) and XDG_CONFIG_HOME, so herdr finds the socket.

## Tried and ruled out
- Linking into $XDG_CONFIG_HOME/systemd/user: enable --now failed with "Unit file herdr-bash-activity.service does not exist". systemd-analyze --user unit-paths listed $HOME/.config/systemd/user, not the shell's directory.

## Watch out
- The monitor's herdr calls swallow errors (2>/dev/null || true). With a bare PATH the service ran with no pane icon, no tab dot and no error. After changing the unit, check /proc/<pid>/environ and do a busy run.
- The PATH and XDG_CONFIG_HOME in the unit are this host's paths.
