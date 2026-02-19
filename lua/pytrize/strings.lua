local M = {}

M.split_once = function(str, sep, kwargs)
    if kwargs.right then
        kwargs.right = false
        local second, first = M.split_once(str:reverse(), sep:reverse(), kwargs)
        return first:reverse(), second:reverse()
    end
    local fragments = vim.split(str, sep, kwargs)
    local first = table.remove(fragments, 1)
    local second
    if #fragments > 0 then
        second = table.concat(fragments, sep)
    else
        second = nil
    end
    return first, second
end

return M
