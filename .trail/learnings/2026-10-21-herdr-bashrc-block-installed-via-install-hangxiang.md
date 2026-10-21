---
title: "herdr: bashrc block installed via install.sh --bashrc (opt-in)"
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 4, tokens: 34711 }
touches:
  - herdr/script/bash-activity-hook.sh
  - herdr/script/install.sh
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
  - herdr/script/install-bashrc.sh
  - herdr/config.toml
  - herdr/script/bash-activity-monitor.sh
---

## Decided
- ~/.bashrc gets a marked block (`# >>> herdr bash-activity >>>` ... `# <<<`) that sources bash-activity-hook.sh. Added by herdr/script/install-bashrc.sh, which backs the file up first and is idempotent. `--remove` deletes the block.
- install.sh only touches bashrc with `--bashrc`, so the default install never edits a user's shell config. `--dry-run` shows the change and does not write.
- The hook returns early unless HERDR_ENV=1 and HERDR_PANE_ID are set, because its DEBUG trap affects every command in the shell.

## Tried and ruled out
- Sourcing the hook for every interactive shell: `pid$$` fallback set traps in non-herdr shells.

## Watch out
- Removing the block does not restore a file that lacked a trailing newline (one newline is added). Bash ignores it.
- The live pane used for testing (tab 4, w7:pD) disappeared mid-test. Check `pane list` before a test instead of assuming the pane exists.
