local M = {}

M.open_file = function(file)
    local saved = vim.o.shortmess
    vim.opt.shortmess:append("F")
    vim.cmd("edit " .. file)
    vim.o.shortmess = saved
end

return M
