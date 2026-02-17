local M = {}

local warn = require('pytrize.warn').warn
local open_file = require('pytrize.jump.util').open_file
local paths = require('pytrize.paths')
local ts_utils = require('pytrize.ts')

M.to_declaration = function()
    local fixture = vim.fn.expand('<cword>')
    if fixture == '' then
        warn('no word under cursor')
        return
    end

    local filepath = vim.api.nvim_buf_get_name(0)
    local root_dir = paths.split_at_root(filepath)
    if root_dir == nil then
        return
    end

    local fixtures = ts_utils.build_fixture_index(filepath, root_dir)
    local location = fixtures[fixture]
    if location == nil then
        warn(string.format('fixture "%s" not found', fixture))
        return
    end

    open_file(location.file)
    vim.api.nvim_win_set_cursor(0, {location.linenr, 0})
end

return M
