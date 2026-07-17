# commit-lens.nvim

Annotate your **current** code with the lines that belong to a chosen set of
git commits — as an independent, magenta highlight layer that coexists with
gitsigns. Built for the workflow of *"I need to make targeted edits based on
what these particular commits changed."*

Marks show up in three places at once, all driven by the same `git blame`:

- **buffer** — a magenta `│` sign + line tint + line-number highlight on every
  line that (still) belongs to a chosen commit;
- **nvim-tree** — a magenta git-commit glyph () before the name of every
  touched file *and its ancestor directories* (so collapsed folders show it too);
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
| `:CommitLensFiles` | List the touched files (**fzf-lua**, with preview + open; falls back to quickfix). |
| `]h` / `[h` | Jump to the next / previous marked **block** (a contiguous run of marked lines), not line-by-line. |

In this config the commands are also under `<leader>gm` (see
`lua/plugin/ui/which-key.lua`): `<leader>gmm` activate, `<leader>gmc` clear,
`<leader>gmf` list files.

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

The nvim-tree and neominimap integrations are **opt-in wiring** on the host
config's side (they can't be enabled from inside this plugin):

- **nvim-tree** — add the decorator to `renderer.decorators`, keeping the full
  default list (nvim-tree drops the builtins if you override the list):

  ```lua
  renderer = {
    decorators = {
      "Git", "Open", "Hidden", "Modified", "Bookmark", "Diagnostics", "Copied",
      require("commit-lens.tree-decorator"),
      "Cut",
    },
  },
  ```

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
  blame_jobs    = 8,          -- max concurrent `git blame` procs for the tree set
  edit_debounce = 400,        -- ms; re-blame after edits (scaled up for big files)
})
```

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
- **async + cached.** Blame runs via `vim.system` (never blocks the UI) and is
  cached per buffer by `(commit-set version, changedtick)`. A monotonic
  `M.version` supersedes in-flight blames after an activate/clear so stale
  results are dropped (race-free).
- **edits re-blame (debounced).** `TextChanged`/`TextChangedI` trigger a
  debounced re-blame so marks + minimap track live edits. Debounce scales with
  file size (400ms small → up to 1600ms for ~20k-line files). If the recomputed
  hits are identical, the whole repaint is **short-circuited** (no extmark
  reset, no minimap refresh) — editing an unrelated region costs nothing.
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
  touched file, so collapsed parents are marked. The decorator snapshots
  `tree_files`/`tree_dirs` once per render (constructor) and does a plain table
  lookup per node, instead of `pcall(require)` per node — matters for big trees.

## Files

- `lua/commit-lens/init.lua` — core: blame, render, cache, commands, navigation.
- `lua/commit-lens/tree-decorator.lua` — nvim-tree Decorator class.
- `lua/commit-lens/minimap-handler.lua` — neominimap custom handler.
