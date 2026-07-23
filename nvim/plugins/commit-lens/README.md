# commit-lens.nvim

Annotate your **current** code with the lines that belong to a chosen set of
git commits — as an independent, magenta highlight layer that coexists with
gitsigns. Built for the workflow of *"I need to make targeted edits based on
what these particular commits changed."*

Marks show up in three places at once, all driven by the same `git blame`:

- **buffer** — a magenta `│` sign + line tint + line-number highlight on every
  line that (still) belongs to a chosen commit;
- **file tree** — a magenta git-commit glyph () before the name of every
  touched file *and its ancestor directories* (so collapsed folders show it too);
  supported managers live behind per-manager adapters (**nvim-tree** and
  **neo-tree** ship today);
- **neominimap** — magenta marks on the minimap for the same lines.

## Why not just gitsigns / diffview?

- **diffview** (`:DiffviewFileHistory`) shows changes in a *separate* buffer —
  fragmentary, not overlaid on the code you're editing.
- **gitsigns' `change_base`** can only hold **one** diff base and diffs the
  working tree against it, so your own new edits get mixed in with the commit's
  changes. It's a per-file mode switch.

commit-lens instead runs `git blame` and marks the lines whose commit is in
your chosen set. That means:

- **multiple commits at once** (union of their surviving lines);
- your later edits are **not** misattributed to those commits — blame only
  claims lines that genuinely belong to them, so there's no location confusion;
- a **private extmark namespace** that layers cleanly over gitsigns.

## Usage

| Command / key | What it does |
| --- | --- |
| `:CommitLens <sha> [<sha>…]` | Activate the lens for one or more commits (short SHA / `HEAD~2` / tag all work). |
| `:CommitLens` (no args) | Pick commits with a **fzf-lua** `git_commits` picker — `<Tab>` multi-selects. |
| `:CommitLensClear` | Turn the lens off everywhere. |
| `:CommitLensToggle` | Toggle the lens: off if on; else re-activate the last chosen set (no re-pick); else open the picker. |
| `:CommitLensFiles` | List the touched files (**fzf-lua**, with preview + open; falls back to quickfix). |
| `]h` / `[h` | Jump to the next / previous marked **block** (a contiguous run of marked lines), not line-by-line. |

In this config the commands are also under `<leader>gm` (see
`lua/plugin/ui/which-key.lua`): `<leader>gmm` activate, `<leader>gmc` clear,
`<leader>gmt` toggle, `<leader>gmf` list files.

### Typical flow

1. `<leader>gmm` (or `:CommitLens <sha> <sha>`) — the lines those commits still
   own light up magenta in the buffer, the minimap, and the file tree.
2. `]h` / `[h` to jump between the changed regions.
3. Edit the code. Lines you add drop out of the lens automatically (they belong
   to the working tree, not the commits) and gitsigns' green/red takes over
   those — the two stay aligned.
4. `<leader>gmc` when done.

## Install (outside this repo)

It's a normal Neovim plugin. With lazy.nvim:

```lua
{
  "youruser/commit-lens.nvim", -- or dir = "/path/to/commit-lens"
  cmd = { "CommitLens", "CommitLensClear", "CommitLensFiles" },
  keys = { "]h", "[h" },
  config = function()
    require("commit-lens").setup()
  end,
}
```

The file-tree and neominimap integrations are **opt-in wiring** on the host
config's side (they can't be enabled from inside this plugin):

- **nvim-tree** — nvim-tree consumes a Decorator *class*, which must live in the
  manager's own `renderer.decorators` list, so commit-lens can't attach it after
  the fact — add it yourself, keeping the full default list (nvim-tree drops the
  builtins if you override the list):

  ```lua
  renderer = {
    decorators = {
      "Git", "Open", "Hidden", "Modified", "Bookmark", "Diagnostics", "Copied",
      require("commit-lens.tree.nvim-tree").decorator,
      "Cut",
    },
  },
  ```

  commit-lens then drives the tree's redraw automatically whenever the touched
  set changes (see **File-tree adapters** below). `require("commit-lens.tree-decorator")`
  still works as a back-compat alias for the class.

- **neo-tree** — override just the built-in `name` component (no renderer-list
  edits — neo-tree deep-merges components by name but replaces renderer *lists*
  wholesale, so touching only `name` is the version-robust hook):

  ```lua
  require("neo-tree").setup({
    filesystem = {
      components = {
        name = require("commit-lens.tree.neo-tree").name_component,
      },
    },
  })
  ```

  The override delegates to neo-tree's own `name` (keeping root/dir/git-status
  colours) and, only for a touched node, returns a two-segment `[glyph, name]`
  in the accent colour.

- **neominimap** — register the handler via its public custom-handler API:

  ```lua
  vim.g.neominimap = {
    handlers = (function()
      local ok, h = pcall(require, "commit-lens.minimap-handler")
      return ok and { h } or {}
    end)(),
    -- …rest of your neominimap config…
  }
  ```

Both integrations are safe-required, so a missing plugin never breaks startup.

## Configuration

`setup(opts)` merges over the defaults:

```lua
require("commit-lens").setup({
  sign_text     = "│",        -- buffer sign glyph (magenta via CommitLensSign)
  accent        = "#FF5FD7",  -- the one accent colour used everywhere
  line_blend    = 0.12,       -- accent→Normal-bg blend for the line tint
  priority      = 10,         -- buffer extmark/sign priority (gitsigns=6)
  max_lines     = 100000,     -- skip buffers larger than this
  skip_filetypes = { bigfile = true },
  blame_args    = { "-w", "-M" }, -- flags spliced into every `git blame` (see below)
  blame_jobs    = 8,          -- max concurrent `git blame` procs for the tree set
  render_jobs   = 8,          -- max concurrent `git blame` procs for buffer marks
  edit_debounce = 400,        -- ms; re-blame after edits (scaled up for big files)
  tree = { managers = "auto" }, -- file-tree integration (see below)
})
```

### `blame_args` — what counts as "belonging to" a commit

Every `git blame` (both the buffer marks and the tree file set) has `blame_args`
spliced in right after `blame`. The default `{ "-w", "-M" }` widens attribution to
survive cosmetic reshaping:

- **`-w`** ignores whitespace-only changes, so a line the commit introduced that
  was later merely **re-indented** still counts as the commit's.
- **`-M`** detects **moves within a file**, so a block the commit added and that was
  later relocated elsewhere in the same file is still attributed to it.

`-C` (detect copies/moves **across** files in the same commit) is left out of the
default: it is markedly slower on large files and tends to over-attribute. Opt in
with `blame_args = { "-w", "-M", "-C" }` if your workflow splits files a lot.

### File-tree adapters

The tree layer is a small registry (`lua/commit-lens/tree.lua`) that fans a
redraw out to per-manager **adapters**. `setup({ tree = { … } })` controls it:

```lua
tree = {
  managers = "auto",           -- drive every *loaded* supported manager (default)
  -- managers = { "nvim-tree" }, -- or restrict to a list
  -- managers = {},              -- or disable the tree layer entirely
  icon = "",                   -- the marker glyph (U+F417)
}
```

`"auto"` re-checks which managers are loaded on every refresh, so a manager that
loads lazily *after* commit-lens still gets driven. **nvim-tree** and
**neo-tree** ship adapters today; the adapter contract (`name` / `detect` /
`refresh`, optional `attach` for buffer-style managers like oil/mini.files,
optional `setup_hint`) is documented at the top of `tree.lua` so more slot in
without touching core.

### Highlight groups (override in your colorscheme; all `default = true`)

| Group | Role |
| --- | --- |
| `CommitLensSign` | magenta fg — buffer sign, tree glyph/name, minimap |
| `CommitLensLine` | line background tint (accent blended onto Normal bg) |
| `CommitLensNr` | line-number highlight on marked lines |

## Design notes / gotchas

Kept here so future-me doesn't re-discover them the hard way:

- **blame is the single source of truth.** Buffer marks, the tree file set, and
  the minimap all key off the same blame result, so a file marked in the tree
  always has surviving lines when you open it. Files a commit *touched* but
  whose changes were later fully overwritten are **not** marked (they have no
  surviving line) — that's intentional, not a bug. Pure-deletion commits
  likewise have nothing to mark; use diffview for those.
- **tree vs buffer blame source.** The buffer marks blame the *buffer contents*
  (`--contents -`, so unsaved edits are reflected), while the tree file set blames
  the *on-disk* file. For a file with unsaved changes the two can briefly diverge
  (the tree may mark a file whose buffer, once opened, has no surviving line, or
  vice-versa) until you save and the next re-blame reconciles them. Same commit
  set, same flags — just different inputs.
- **async + cached — *everything*, including activation.** Blame runs via
  `vim.system` (never blocks the UI) and is cached per buffer by
  `(commit-set version, changedtick)`. A monotonic `M.version` supersedes
  in-flight blames after an activate/clear so stale results are dropped
  (race-free). Activation is async too: `:CommitLens <rev…>` resolves each rev
  with async `git rev-parse` and gathers the tree candidate set with async
  `git show` — no synchronous git on the main thread anywhere. A **second**
  token, `activate_seq`, guards the resolution phase: it is bumped synchronously
  on every activate **and clear**, so a rapid second `:CommitLens` (or a
  `:CommitLensClear`) issued while resolution is still in flight deterministically
  supersedes/cancels the first (the first never commits, and a clear-during-resolve
  never re-enables the lens). `M.version` is bumped only at the *commit point*
  (after resolution succeeds), so a failed or superseded resolution never tears
  down the currently-rendered session.
- **one blame per (buffer, version, tick).** Opening a file fires both
  `BufReadPost` and `BufWinEnter`; a `pending` claim keyed by `(version, tick)`
  collapses that double-fire into a single blame. A global `render_jobs` cap (with
  a small FIFO queue) bounds the aggregate when many buffers open at once (session
  restore, `:bufdo`, a big quickfix) so it can't spawn one `git blame` per buffer
  simultaneously. The short-circuit compares against the **live** `buf_cache`
  (not a snapshot captured at render entry) so two different-tick blames landing
  out of order can't skip a needed repaint.
- **edits re-blame (debounced).** `TextChanged`/`TextChangedI` trigger a
  debounced re-blame so marks + minimap track live edits. Debounce scales with
  file size (400ms small → up to 1600ms for ~20k-line files). If the recomputed
  hits are identical, the whole repaint is **short-circuited** (no extmark
  reset, no minimap refresh) — editing an unrelated region costs nothing.
- **extmarks are the source of truth for *position*.** Both `]h`/`[h`
  navigation and the neominimap handler fold the buffer's *live* extmarks into
  blocks via `M.get_blocks(bufnr)` — never a snapshot table. Neovim auto-shifts
  extmarks as you insert/delete lines, so the marks are already in the right
  place the instant you edit; the minimap realigns at neominimap's own repaint
  cadence (~200ms) instead of lagging the debounced blame (up to 1.6s + blame
  time on a big file). The background re-blame only revises *membership* (a
  line you just typed isn't the commit's, so it later drops out) — repositioning
  is free and needs no blame.
- **priorities are layered.** In the *buffer*, commit-lens sign priority is 10
  (> gitsigns' 6) so the historical mark shows. On the *minimap* it's
  deliberately **1** (< gitsigns' 6) so your live gitsigns green/red covers the
  historical marks where you're actively editing.
- **colour choice.** Magenta `#FF5FD7`, not orange — the config's orange
  `#D19A66` collides exactly with onedark's `@type.builtin` and sits next to
  struct/type yellow `#E5C07B`, which made minimap dots unreadable. Magenta is
  unused by gitsigns / diagnostics / type highlights.
- **glyphs are decoupled.** Buffer uses `│` (aligns with gitsigns' bar, told
  apart by colour); the tree uses the nf-oct git-commit glyph  (U+F417).
  Both are written as **explicit UTF-8 byte escapes** in source (`"\226\148\130"`,
  `"\239\144\151"`) because the PUA codepoint was silently lost to empty string
  during earlier edits, which then broke sign registration.
- **tree passthrough.** `M.tree_dirs` holds every ancestor directory of a
  touched file, so collapsed parents are marked. The nvim-tree adapter snapshots
  the tree render-context (`tree_files`/`tree_dirs` + icon/hl) once per render
  (constructor) and does a plain table lookup per node, instead of `require()`
  per node — matters for big trees.
- **tree glue is adapter-shaped.** Managers integrate in two ways, which decides
  what can be automatic: *render-pipeline injection* (nvim-tree Decorator,
  neo-tree component) must be placed into the manager's own setup by the host —
  commit-lens can only drive the redraw; *buffer + extmark* (oil, mini.files)
  lets an adapter self-wire an autocmd and paint extmarks. The registry's
  `refresh()` re-evaluates `detect()` each call, so lazy-loaded managers are
  still driven, and `.decorator` is resolved lazily so requiring the adapter
  before nvim-tree loads doesn't permanently cache a nil class.
- **attribution follows `blame_args`.** The default `{ "-w", "-M" }` keeps
  re-indented and within-file-moved lines attributed to their commit (see the
  `blame_args` section above). Turn it off (`blame_args = {}`) to get git's stock
  "who last touched this exact byte" behaviour instead.

## Health

Run `:checkhealth commit-lens` to verify the setup. Because the three integrations
(nvim-tree / neo-tree / neominimap) are all **host-side wiring** you add yourself,
the health check is the fastest way to answer *"why isn't the mark showing up?"*.
It reports:

- **git** on `$PATH` (+ version);
- the resolved **config** (accent, `blame_args`, `blame_jobs`/`render_jobs`, …);
- whether **fzf-lua** is available (warns, doesn't error — the picker is optional);
- for each **file-tree** manager that is loaded, a reminder of the wiring snippet
  (`setup_hint`) so a missing decorator/component is easy to spot and fix;
- whether the **neominimap** handler is registered in `vim.g.neominimap.handlers`.

## Tests

`tests/run.sh` runs a small headless-nvim suite (no external test framework — each
`tests/case_*.lua` drives the plugin under `nvim --headless -u NONE`, asserts on the
resulting extmarks, and quits non-zero on failure):

```sh
nvim/plugins/commit-lens/tests/run.sh            # all cases
nvim/plugins/commit-lens/tests/run.sh core async # only named cases
```

Cases cover core marking + the short-circuit, `blame_args` (`-w -M` keeps a
re-indented line attributed), in-flight **dedup** (the double-fire launches one
blame), async-activate **last-wins** + **clear-during-resolution**, the toggle
round-trip, and `:checkhealth`. The **nvim-tree** case runs against an installed
checkout (discovered on the lazy data dir, or `NVIM_TREE_DIR=…`) and **skips**
cleanly if none is found, so the suite still passes on a bare machine.

## Files

- `lua/commit-lens/init.lua` — core: blame, render, cache, commands, navigation.
- `lua/commit-lens/tree.lua` — file-tree adapter registry: config, refresh
  dispatch, the shared read-only render context.
- `lua/commit-lens/tree/nvim-tree.lua` — the nvim-tree adapter (Decorator class
  on `.decorator`, plus `detect`/`refresh`).
- `lua/commit-lens/tree/neo-tree.lua` — the neo-tree adapter (`name` component
  override on `.name_component`, plus `detect`/`refresh`).
- `lua/commit-lens/tree-decorator.lua` — back-compat alias for the nvim-tree
  Decorator class.
- `lua/commit-lens/minimap-handler.lua` — neominimap custom handler.
- `lua/commit-lens/health.lua` — `:checkhealth commit-lens` provider.
- `tests/` — headless-nvim test suite (`run.sh` + `case_*.lua` + `helpers.lua`).
