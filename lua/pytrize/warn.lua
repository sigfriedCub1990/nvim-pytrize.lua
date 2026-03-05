local M = {}

M.warn = function(msg)
    vim.notify(string.format("Pytrize: %s", msg), vim.log.levels.WARN)
end

return M
