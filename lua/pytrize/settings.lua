local M = {}

local warn = require("pytrize.warn").warn

---@class PytrizeSettings
---@field no_commands boolean Whether to skip creating user commands (default: false)
---@field highlight string Highlight group for virtual text (default: "LineNr")
---@field metrics boolean Show performance metrics for operations (default: false)

---@type PytrizeSettings
M.settings = {
    no_commands = false,
    highlight = "LineNr",
    metrics = false,
}

---@param opts table
M.update = function(opts)
    for k, v in pairs(opts) do
        if M.settings[k] == nil then
            warn(string.format("unknown setting '%s'", k))
        else
            local expected = type(M.settings[k])
            local actual = type(v)
            if expected ~= actual then
                warn(string.format("invalid type for setting '%s': expected %s, got %s", k, expected, actual))
            else
                M.settings[k] = v
            end
        end
    end
end

return M
