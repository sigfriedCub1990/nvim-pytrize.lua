local M = {}

M.min = function(a, b)
    if a <= b then
        return a
    else
        return b
    end
end

M.max = function(a, b)
    if a >= b then
        return a
    else
        return b
    end
end

--- Temporarily load a Python buffer for `filepath`, call `fn(bufnr)`, then
--- clean up if the buffer was not already loaded.  Autocommands are suppressed
--- during the load so that LSP clients (and other plugins) do not attach to
--- ephemeral buffers.
---
--- @param filepath string   Absolute path to a Python file.
--- @param fn fun(bufnr: integer): any   Callback that receives the buffer number.
--- @param opts? { force_delete?: boolean }   Options for cleanup (default: force_delete = false).
--- @return any  The return value of `fn`.
M.with_buf = function(filepath, fn, opts)
    opts = opts or {}
    local existing_bufnr = vim.fn.bufnr(filepath)
    local was_loaded = existing_bufnr ~= -1 and vim.fn.bufloaded(existing_bufnr) == 1

    local bufnr = vim.fn.bufadd(filepath)
    if not was_loaded then
        local saved_eventignore = vim.o.eventignore
        vim.o.eventignore = "all"
        vim.fn.bufload(bufnr)
        vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })
        vim.o.eventignore = saved_eventignore
    end

    local result = fn(bufnr)

    if not was_loaded then
        vim.api.nvim_buf_delete(bufnr, { force = opts.force_delete or false })
    end

    return result
end

return M
