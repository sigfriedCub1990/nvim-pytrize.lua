local M = {}

M.open_file = function(file)
    vim.fn.execute("edit " .. vim.fn.fnameescape(file))
end

return M
