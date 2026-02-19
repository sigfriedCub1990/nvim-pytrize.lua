local M = {}

M.reverse = function(lst)
    local reversed = {}
    for _, entry in ipairs(lst) do
        table.insert(reversed, 1, entry)
    end
    return reversed
end

M.list_map = function(func, iterable)
    local new = {}
    for _, v in ipairs(iterable) do
        table.insert(new, func(v))
    end
    return new
end

return M
