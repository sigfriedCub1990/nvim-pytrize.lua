local M = {}

--- Temporarily load a Python buffer for `filepath`, call `fn(bufnr)`, then
--- clean up if the buffer was not already loaded.  Autocommands are suppressed
--- during the load so that LSP clients (and other plugins) do not attach to
--- ephemeral buffers.
---
---@param filepath string   Absolute path to a Python file.
---@param fn fun(bufnr: integer): any   Callback that receives the buffer number.
---@param opts? { force_delete?: boolean }   Options for cleanup.
---@return any  The return value of `fn`.
M.with_buf = function(filepath, fn, opts)
    opts = opts or {}
    local existing_bufnr = vim.fn.bufnr(filepath)
    local was_loaded = existing_bufnr ~= -1 and vim.api.nvim_buf_is_loaded(existing_bufnr)

    local bufnr = vim.fn.bufadd(filepath)
    if not was_loaded then
        local saved_eventignore = vim.o.eventignore
        vim.o.eventignore = "all"
        -- vim.fn.execute() wraps :redir internally, suppressing the
        -- C-level file-info message ("path" NL, NB) that bufload emits.
        vim.fn.execute("call bufload(" .. bufnr .. ")")
        vim.bo[bufnr].filetype = "python"
        vim.o.eventignore = saved_eventignore
    end

    local ok, result = pcall(fn, bufnr)

    if not was_loaded and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = opts.force_delete or false })
    end

    if not ok then
        error(result)
    end

    return result
end

return M
