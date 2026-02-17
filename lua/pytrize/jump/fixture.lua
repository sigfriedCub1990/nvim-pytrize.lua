local M = {}

local warn = require('pytrize.warn').warn
local open_file = require('pytrize.jump.util').open_file
local paths = require('pytrize.paths')
local ts_utils = require('pytrize.ts')

local function hrtime() return (vim.uv or vim.loop).hrtime() end
local function ms(t) return string.format('%.1fms', t / 1e6) end

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

    local t0 = hrtime()
    local fixtures = ts_utils.build_fixture_index(filepath, root_dir)
    local t_index = hrtime()

    local location = fixtures[fixture]
    if location == nil then
        warn(string.format('fixture "%s" not found', fixture))
        return
    end

    open_file(location.file)
    vim.api.nvim_win_set_cursor(0, {location.linenr, 0})

    if require('pytrize.settings').settings.metrics then
        local total = hrtime() - t0
        local index = t_index - t0
        vim.notify(string.format(
            'Pytrize jump: total=%s  index=%s',
            ms(total), ms(index)
        ), vim.log.levels.INFO)
    end
end

return M
