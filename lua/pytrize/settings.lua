local M = {}

local warn = require("pytrize.warn").warn

---@class PytrizeSettings
---@field no_commands boolean Whether to skip creating user commands (default: false)
---@field highlight string Highlight group for virtual text (default: "LineNr")
---@field metrics boolean Show performance metrics for operations (default: false)

---@type PytrizeSettings
-- All valid setting keys (including those whose default is nil)
local valid_keys = {
    no_commands = true,
    highlight = "LineNr",
    metrics = true,
    preferred_input = true, -- 'telescope', 'fzf-lua', or nil (quickfix fallback)
}

-- defaults
M.settings = {
    no_commands = false,
    highlight = "LineNr",
    metrics = false,
    preferred_input = nil,
}

---@param opts table
M.update = function(opts)
    for k, v in pairs(opts) do
        if not valid_keys[k] then
            warn(string.format("unknown setting '%s'", k))
        else
            local current = M.settings[k]
            if current ~= nil and type(current) ~= type(v) then
                warn(string.format("invalid type for setting '%s': expected %s, got %s", k, type(current), type(v)))
            else
                M.settings[k] = v
            end
        end
    end
end

return M
