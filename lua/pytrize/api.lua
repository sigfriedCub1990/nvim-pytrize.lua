local M = {}

--- Clear pytrize virtual text from buffer.
---@param bufnr? integer Buffer number (0 or nil for current buffer)
M.clear = function(bufnr)
    local marks = require("pytrize.marks")
    marks.clear(bufnr or 0)
end

--- Set pytrize virtual text for parametrize entries in buffer.
---@param bufnr? integer Buffer number (0 or nil for current buffer)
M.set = function(bufnr)
    local cs = require("pytrize.call_spec")
    local marks = require("pytrize.marks")
    bufnr = bufnr or 0
    marks.clear(bufnr)
    local call_specs_per_func = cs.get_calls(bufnr)
    if call_specs_per_func == nil then
        return
    end
    for _, call_specs in pairs(call_specs_per_func) do
        for _, call_spec in ipairs(call_specs) do
            for _, entry_spec in ipairs(call_spec.entries) do
                local entry_row = entry_spec.node:start()
                marks.set({
                    bufnr = bufnr,
                    text = entry_spec.id,
                    row = entry_row,
                })
                for _, item_spec in ipairs(entry_spec.items) do
                    local item_row = item_spec.node:start()
                    if item_row ~= entry_row then
                        marks.set({
                            bufnr = bufnr,
                            text = item_spec.id,
                            row = item_spec.node:start(),
                        })
                    end
                end
            end
        end
    end
end

--- Jump to the parametrize entry declaration under cursor.
M.jump = function()
    local jump = require("pytrize.jump")

    jump.to_param_declaration()
end

--- Jump to fixture definition under cursor.
M.jump_fixture = function()
    local jump = require("pytrize.jump")

    jump.to_fixture_declaration()
end

--- Rename fixture under cursor across the project.
M.rename_fixture = function()
    local rename = require("pytrize.rename")

    rename.rename_fixture()
end

--- Show all usages of fixture under cursor in quickfix list.
M.fixture_usages = function()
    local usages = require("pytrize.usages")

    usages.show_usages()
end

return M
