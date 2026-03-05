local M = {}

local settings = require("pytrize.settings").settings

local NS_ID = vim.api.nvim_create_namespace("pytrize")

--- Clear all pytrize extmarks from a buffer.
---@param bufnr integer Buffer number (0 for current)
M.clear = function(bufnr)
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    vim.api.nvim_buf_clear_namespace(bufnr, NS_ID, 0, -1)
end

--- Set a virtual text extmark.
---@param opts { bufnr: integer, row: integer, text: string }
M.set = function(opts)
    local bufnr = opts.bufnr
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    vim.api.nvim_buf_set_extmark(bufnr, NS_ID, opts.row, 0, {
        virt_text = { { opts.text, settings.highlight } },
    })
end

return M
