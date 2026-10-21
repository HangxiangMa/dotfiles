---
title: pyenv component in nvim requirements.sh
author: Hangxiang
date: 2026-10-21
branch: main
cost: { minutes: 6, tokens: 110834 }
touches:
  - nvim/script/requirements.sh
  - nvim/script/test_install.sh
---

## Decided
- pyenv is component 12 in nvim/script/requirements.sh, wired like python3-venv: menu, select_component, install_all, cmd_migrate --with-deps, the setup custom checklist, and test_install.sh.
- install_pyenv clones into $PYENV_ROOT, defaulting to $WORKSPACE/.pyenv so it stays off the quota'd $HOME. An existing install at that path is reused, not updated.
- The rc lines are written idempotently: PYENV_ROOT and PATH via write_env_to_rc and append_path_to_rc, and the eval'd `pyenv init` via append_pyenv_init_to_rc. The init is an `if` block, not `cmd && eval`, so a sourced rc still exits 0 when pyenv is absent.

## Tried and ruled out
- Checking for pyenv at ~/.pyenv, $WORKSPACE/.pyenv, PYENV_ROOT, /opt, /usr/local and linuxbrew: none existed on the dev host, so the install path was verified only in a temp HOME/WORKSPACE sandbox.

## Watch out
- The installer does not install pyenv's build dependencies (libssl, zlib, readline, sqlite, etc.), so `pyenv install <ver>` can still fail on a fresh host.
- The `pyenv init` line is matched by the literal text `pyenv init`, so keep that wording stable or re-runs will append a duplicate.
