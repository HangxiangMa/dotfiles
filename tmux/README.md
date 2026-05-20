# Configure tmux

A small, opinionated tmux config plus a one-shot installer.

## What's in `tmux.conf`

- **Vi-style copy mode** — `prefix + [` (or `prefix + Esc`) → `v` start
  selection → `C-v` toggle rectangle → `y` yank to system clipboard. Works
  with or without plugins.
- **TPM + plugins** (auto-loaded when `~/.tmux/plugins/tpm` exists):
  - `tmux-plugins/tmux-sensible` — sane defaults (escape-time, focus-events,
    history-limit, etc).
  - `christoomey/vim-tmux-navigator` — `C-h/j/k/l` jumps between tmux panes
    *and* vim splits seamlessly.
  - `tmux-plugins/tmux-yank` — system-clipboard integration for `y`.
- **Vim-aware fallback** — if TPM isn't installed, the conf still wires up a
  hand-rolled `C-h/j/k/l` smart-navigation as a fallback so the same keys
  work on a fresh machine.
- **Quality-of-life bindings** — windows/panes start at index 1,
  `renumber-windows on`, `prefix + r` reloads the conf, `prefix + |` /
  `prefix + -` split with current cwd, status line shows hostname + session
  name (handy for SSH).

> [!NOTE]
> `allow-passthrough on` (used by yazi image preview) is gated behind a
> tmux-version check; on tmux < 3.3 it's silently skipped instead of
> raising `invalid option`.

## One-shot install

```bash
cd dotfiles/tmux
./script/install.sh           # interactive — confirms before each step
./script/install.sh -y        # non-interactive
./script/install.sh --dry-run # show planned actions, change nothing
```

The installer is idempotent. It will:

1. Copy `tmux.conf` to `~/.tmux.conf` (existing file is moved aside to
   `~/.tmux.conf.bak-<timestamp>` first).
2. Clone TPM into `~/.tmux/plugins/tpm` if missing.
3. Run TPM's `install_plugins` so yank / navigator land before you ever
   attach a session.
4. `source-file` the new conf into a running tmux server, if one is up.

## After install

- `prefix + I` — TPM plugin install/refresh (rare; the installer already did
  this once)
- `prefix + r` — reload `~/.tmux.conf`
