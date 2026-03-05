local M = {}

M.open_file = function(file)
    -- vim.fn.execute() wraps :redir internally, suppressing the C-level
    -- file-info message ("path" NL, NB) that :edit emits. vim.cmd.edit()
    -- and :silent do not reliably suppress it.
    vim.fn.execute("edit " .. vim.fn.fnameescape(file))
end

return M
