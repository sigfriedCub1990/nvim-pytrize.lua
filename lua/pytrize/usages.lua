local M = {}

local warn = require("pytrize.warn").warn
local paths = require("pytrize.paths")
local ts_helpers = require("pytrize.ts_helpers")
local utils = require("pytrize.utils")

local find_all_usages = function(fixture_name, root_dir)
    local py_files = ts_helpers.find_python_files(root_dir, fixture_name)
    local items = {}

    for _, filepath in ipairs(py_files) do
        utils.with_buf(filepath, function(bufnr)
            local positions = ts_helpers.find_fixture_references(bufnr, fixture_name)
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

            for _, pos in ipairs(positions) do
                table.insert(items, {
                    filename = filepath,
                    lnum = pos.row + 1,
                    col = pos.col_start + 1,
                    text = lines[pos.row + 1] or "",
                })
            end
        end)
    end

    return items
end

M.show_usages = function()
    local fixture_name = vim.fn.expand("<cword>")
    if fixture_name == "" then
        warn("no word under cursor")
        return
    end

    local filepath = vim.api.nvim_buf_get_name(0)
    local root_dir = paths.split_at_root(filepath)
    if root_dir == nil then
        return
    end

    local items = find_all_usages(fixture_name, root_dir)

    if #items == 0 then
        warn(string.format('no usages found for fixture "%s"', fixture_name))
        return
    end

    vim.fn.setqflist(items, "r")
    vim.cmd("copen")
end

-- Internal exports for testing
M._find_fixture_references = ts_helpers.find_fixture_references
M._find_all_usages = find_all_usages

return M
