local M = {}

local ts = vim.treesitter
local warn = require("pytrize.warn").warn
local paths = require("pytrize.paths")
local ts_utils = require("pytrize.ts")
local ts_helpers = require("pytrize.ts_helpers")
local utils = require("pytrize.utils")

local function hrtime()
    return (vim.uv or vim.loop).hrtime()
end
local function ms(t)
    return string.format("%.1fms", t / 1e6)
end

local function get_fixture_name()
    return vim.fn.expand("<cword>")
end

local find_rename_positions = function(bufnr, old_name)
    local ok = pcall(function()
        vim.treesitter.language.inspect("python")
    end)
    if not ok then
        warn("Python treesitter parser not installed - cannot rename fixture")
        return nil
    end

    local positions = {}

    -- Case A: Fixture definitions (rename the def name itself)
    for _, def in ipairs(ts_utils.get_fixture_defs(bufnr)) do
        if def.name == old_name then
            local row, col_start, _, col_end = def.name_node:range()
            table.insert(positions, { row = row, col_start = col_start, col_end = col_end })
        end
    end

    -- Case B & C: Consumer parameters, body references, usefixtures strings
    local refs = ts_helpers.find_fixture_references(bufnr, old_name)
    for _, pos in ipairs(refs) do
        table.insert(positions, pos)
    end

    return positions
end

local apply_renames = function(bufnr, positions, new_name)
    table.sort(positions, function(a, b)
        if a.row ~= b.row then
            return a.row > b.row
        end
        return a.col_start > b.col_start
    end)

    for _, pos in ipairs(positions) do
        vim.api.nvim_buf_set_text(bufnr, pos.row, pos.col_start, pos.row, pos.col_end, { new_name })
    end

    return #positions
end

local function rename(old_name, new_name)
    if old_name == new_name then
        warn(string.format('New name is the same as old name: "%s"', old_name))
        return
    end

    local current_file = vim.api.nvim_buf_get_name(0)
    local root_dir = paths.split_at_root(current_file)
    if root_dir == nil then
        return
    end

    ts_utils.clear_scan_cache()
    local t0 = hrtime()

    local py_files = ts_helpers.find_python_files(root_dir, old_name)
    if #py_files == 0 then
        warn(string.format('No Python files contain "%s"', old_name))
        return
    end

    local t_grep = hrtime()

    -- First pass: determine which files to process. Only rename in files where
    -- the fixture resolves to the current file (not shadowed by a closer definition).
    local files_to_process = {}
    for _, filepath in ipairs(py_files) do
        if filepath == current_file then
            table.insert(files_to_process, filepath)
        else
            local index = ts_utils.build_fixture_index(filepath, root_dir)
            local resolved = index[old_name]
            if resolved and resolved.file == current_file then
                table.insert(files_to_process, filepath)
            end
        end
    end

    local t_scope = hrtime()

    local total_replacements = 0
    local files_changed = 0

    for _, filepath in ipairs(files_to_process) do
        local abort = false
        utils.with_buf(filepath, function(bufnr)
            local positions = find_rename_positions(bufnr, old_name)
            if positions == nil then
                abort = true
                return
            end

            if #positions > 0 then
                local count = apply_renames(bufnr, positions, new_name)
                total_replacements = total_replacements + count
                files_changed = files_changed + 1

                vim.api.nvim_buf_call(bufnr, function()
                    vim.cmd("write")
                end)
            end
        end)
        if abort then
            return
        end
    end

    local t_end = hrtime()

    if total_replacements == 0 then
        warn(string.format('No fixture references found for "%s"', old_name))
    else
        local msg = string.format(
            'Pytrize: Renamed "%s" -> "%s" in %d file(s) (%d occurrence(s))',
            old_name,
            new_name,
            files_changed,
            total_replacements
        )
        if require("pytrize.settings").settings.metrics then
            msg = msg
                .. string.format(
                    "\n  total=%s  grep=%s  scoping=%s  apply=%s",
                    ms(t_end - t0),
                    ms(t_grep - t0),
                    ms(t_scope - t_grep),
                    ms(t_end - t_scope)
                )
        end
        vim.notify(msg, vim.log.levels.INFO)
    end
end

M.rename_fixture = function()
    local old_name = get_fixture_name()
    if old_name == "" then
        warn("No word under cursor")
        return
    end

    vim.ui.input({ prompt = string.format('Rename fixture "%s" to: ', old_name) }, function(new_name)
        if new_name == nil or new_name == "" then
            return
        end
        rename(old_name, new_name)
    end)
end

-- Internal exports for testing
M._find_rename_positions = find_rename_positions
M._apply_renames = apply_renames
M._rename = rename

return M
