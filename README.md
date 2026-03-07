# Pytrize

## Short summary

Helps navigating pytest fixtures by providing jump to declaration, rename, and find usages commands, using `treesitter`.

## What does the plugin do?

- **Jump to fixture definition** — jump to the declaration of the fixture under the cursor.
  Done by calling `PytrizeJumpFixture`.
  Alternatively `lua require('pytrize.api').jump_fixture()`.
  See [Jump to fixture](#jump-to-fixture) below.
- **Rename fixture** — rename the fixture under the cursor across the project.
  Done by calling `PytrizeRenameFixture`.
  Alternatively `lua require('pytrize.api').rename_fixture()`.
  See [Rename fixture](#rename-fixture) below.
- **Find fixture usages** — find all usages of the fixture under the cursor across the project.
  Done by calling `PytrizeFixtureUsages`.
  Alternatively `lua require('pytrize.api').fixture_usages()`.
  See [Fixture usages](#fixture-usages) below.

## Installation

For example using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
  'sigfriedcub1990/nvim-pytrize.lua',
  version = '*',
  ft = 'python', -- Load only for python files
  opts = {
    -- metrics = true, -- uncomment to log timing info for jump and rename
    -- preferred_input = 'fzf-lua', -- uncomment to use fzf-lua for fixture usages
  },
  -- uncomment if you want to lazy load
  -- cmd = {'PytrizeJumpFixture', 'PytrizeRenameFixture', 'PytrizeFixtureUsages'},
}
```

## Configuration

`require("pytrize").setup` takes an optional table of settings which currently have the default values:

```lua
{
  no_commands = false,
  highlight = 'LineNr',
  metrics = false,
  preferred_input = nil,
}
```

where:

- `no_commands` can be set to `true` and the user commands won't be declared.
- `highlight` defines the highlighting used for virtual text.
- `metrics` when set to `true`, logs timing information via `vim.notify` after each jump-to-fixture and rename operation. Useful for understanding performance in large projects. The jump reports total time and index-build time; the rename reports total, grep, scoping (fixture resolution), and apply time.
- `preferred_input` which method to use for displaying results (if installed). Currently `'fzf-lua'` is supported — when set, fixture usages are displayed in an [`fzf-lua`](https://github.com/ibhagwan/fzf-lua) picker instead of the quickfix list. When `nil` (the default), results go to the quickfix list.

## Jump to fixture

To jump to the declaration of a fixture under the cursor, do `PytrizeJumpFixture`:
![pytrize_fixture](https://user-images.githubusercontent.com/23341710/145707800-dcd49ae2-8fb1-46cc-8895-ed78ee5365b9.gif)

## Rename fixture

To rename the fixture under the cursor, do `PytrizeRenameFixture`.

![rename_fixture](https://github.com/user-attachments/assets/93bd2db7-7294-4d6c-921d-53c794cac9f9)

## Fixture usages

To find all usages of the fixture under the cursor, do `PytrizeFixtureUsages`.

![fixture_usages](https://github.com/user-attachments/assets/167eb4bd-58a1-48fc-a19c-64168172aa85)

Results are loaded into Neovim's quickfix list and the quickfix window is opened automatically.
Each entry shows the file, line, and the line content where the fixture is used — as a parameter, a body reference, or inside `@pytest.mark.usefixtures(...)`. The fixture definition itself is excluded from the results.

### fzf-lua

When `preferred_input = 'fzf-lua'` is set and [`fzf-lua`](https://github.com/ibhagwan/fzf-lua) is installed, fixture usages (`PytrizeFixtureUsages`) are displayed in an fzf picker with a built-in previewer. Supported actions:

- `Enter` — open file
- `ctrl-s` — open in horizontal split
- `ctrl-v` — open in vertical split
- `ctrl-t` — open in new tab

If `fzf-lua` is not installed, results fall back to the quickfix list.
