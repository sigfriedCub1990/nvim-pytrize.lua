local M = {}

local ts = vim.treesitter

--- Get the identifier node from a function parameter node.
--- Handles plain identifiers, default parameters, typed parameters, etc.
---@param param_node TSNode
---@return TSNode|nil
M.get_param_name_node = function(param_node)
    local t = param_node:type()
    if t == "identifier" then
        return param_node
    elseif t == "default_parameter" or t == "typed_default_parameter" then
        return param_node:field("name")[1]
    elseif t == "typed_parameter" then
        local first = param_node:named_child(0)
        if first and first:type() == "identifier" then
            return first
        end
    end
    return nil
end

--- Get parameter names from a parameters node.
---@param parameters_node TSNode
---@param bufnr integer
---@return string[]
M.get_param_names = function(parameters_node, bufnr)
    local names = {}
    for child in parameters_node:iter_children() do
        local name_node = M.get_param_name_node(child)
        if name_node then
            table.insert(names, ts.get_node_text(name_node, bufnr))
        end
    end
    return names
end

--- Find all references to `name` inside a function body, respecting shadowing
--- by nested function definitions that re-declare the same parameter name.
---@param body_node TSNode
---@param name string
---@param bufnr integer
---@return table[] positions Array of {row, col_start, col_end}
M.find_body_references = function(body_node, name, bufnr)
    local positions = {}

    local function walk_body(node, shadowed)
        if shadowed then
            return
        end

        local node_type = node:type()

        if node_type == "function_definition" then
            local params_node = node:field("parameters")[1]
            if params_node then
                local param_names = M.get_param_names(params_node, bufnr)
                local re_declares = false
                for _, p in ipairs(param_names) do
                    if p == name then
                        re_declares = true
                        break
                    end
                end
                for child in node:iter_children() do
                    walk_body(child, re_declares)
                end
                return
            end
        end

        if node_type == "identifier" then
            if ts.get_node_text(node, bufnr) == name then
                local parent = node:parent()
                if parent then
                    local parent_type = parent:type()
                    if parent_type == "attribute" then
                        local attr_field = parent:field("attribute")[1]
                        if attr_field and attr_field:id() == node:id() then
                            goto continue
                        end
                    end
                    if parent_type == "keyword_argument" then
                        local name_field = parent:field("name")[1]
                        if name_field and name_field:id() == node:id() then
                            goto continue
                        end
                    end
                end
                local row, col_start, _, col_end = node:range()
                table.insert(positions, { row = row, col_start = col_start, col_end = col_end })
            end
            ::continue::
        end

        for child in node:iter_children() do
            walk_body(child, false)
        end
    end

    walk_body(body_node, false)
    return positions
end

--- Find positions of fixture consumer parameters, body references, and
--- @pytest.mark.usefixtures string arguments in a buffer.
---@param bufnr integer
---@param fixture_name string
---@return table[] positions Array of {row, col_start, col_end}
M.find_fixture_references = function(bufnr, fixture_name)
    local ts_utils = require("pytrize.ts")

    local ok = pcall(function()
        vim.treesitter.language.inspect("python")
    end)
    if not ok then
        return {}
    end

    local parser = ts.get_parser(bufnr, "python")
    local tree = parser:parse()[1]
    local root = tree:root()

    local positions = {}

    ts_utils.walk(root, function(node)
        local node_type = node:type()

        -- Case A: fixture consumers (parameter + body refs)
        if node_type == "function_definition" then
            local params_node = node:field("parameters")[1]
            if params_node then
                local found_param_node = nil
                for child in params_node:iter_children() do
                    local name_node = M.get_param_name_node(child)
                    if name_node and ts.get_node_text(name_node, bufnr) == fixture_name then
                        found_param_node = name_node
                        break
                    end
                end

                if found_param_node then
                    local row, col_start, _, col_end = found_param_node:range()
                    table.insert(positions, { row = row, col_start = col_start, col_end = col_end })

                    local body_node = node:field("body")[1]
                    if body_node then
                        local body_refs = M.find_body_references(body_node, fixture_name, bufnr)
                        for _, pos in ipairs(body_refs) do
                            table.insert(positions, pos)
                        end
                    end
                end
            end
        end

        -- Case B: @pytest.mark.usefixtures("fixture_name") string arguments
        if node_type == "call" then
            local func = node:field("function")[1]
            if func and func:type() == "attribute" then
                local func_text = ts.get_node_text(func, bufnr)
                if func_text == "pytest.mark.usefixtures" then
                    local args = node:field("arguments")[1]
                    if args then
                        for child in args:iter_children() do
                            if child:type() == "string" then
                                for schild in child:iter_children() do
                                    if schild:type() == "string_content" then
                                        if ts.get_node_text(schild, bufnr) == fixture_name then
                                            local row, col_start, _, col_end = schild:range()
                                            table.insert(
                                                positions,
                                                { row = row, col_start = col_start, col_end = col_end }
                                            )
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    return positions
end

--- Grep for Python files containing `name` under `root_dir`.
---@param root_dir string
---@param name string
---@return string[]
M.find_python_files = function(root_dir, name)
    return vim.fn.systemlist(
        string.format('grep -rl --include="*.py" "%s" "%s"', vim.fn.escape(name, '"\\'), root_dir)
    )
end

return M
