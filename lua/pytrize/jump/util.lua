local M = {}

M.open_file = function(file)
    vim.cmd("silent edit " .. file)
end

return M
