local M = {}

local ts = vim.treesitter
local warn = require("pytrize.warn").warn
local paths = require("pytrize.paths")
local ts_utils = require("pytrize.ts")

local function find_python_files(root_dir, name)
    return vim.fn.systemlist(string.format('grep -rl --include="*.py" "%s" "%s"', vim.fn.escape(name, '"\\'), root_dir))
end

local function get_param_name_node(param_node)
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

local function find_body_references(body_node, fixture_name, bufnr)
    local positions = {}

    local function walk_body(node, shadowed)
        if shadowed then
            return
        end

        local node_type = node:type()

        if node_type == "function_definition" then
            local params_node = node:field("parameters")[1]
            if params_node then
                local re_declares = false
                for child in params_node:iter_children() do
                    local name_node = get_param_name_node(child)
                    if name_node and ts.get_node_text(name_node, bufnr) == fixture_name then
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
            if ts.get_node_text(node, bufnr) == fixture_name then
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

-- Find usage positions (parameters, body references, usefixtures strings)
-- Does NOT include fixture definitions.
local find_usage_positions = function(bufnr, fixture_name)
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
                    local name_node = get_param_name_node(child)
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
                        for _, pos in ipairs(find_body_references(body_node, fixture_name, bufnr)) do
                            table.insert(positions, pos)
                        end
                    end
                end
            end
        end

        -- Case B: @pytest.mark.usefixtures("fixture_name") strings
        if node_type == "call" then
            local func = node:field("function")[1]
            if func and func:type() == "attribute" then
                if ts.get_node_text(func, bufnr) == "pytest.mark.usefixtures" then
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

local find_all_usages = function(fixture_name, root_dir)
    local py_files = find_python_files(root_dir, fixture_name)
    local items = {}

    for _, filepath in ipairs(py_files) do
        local existing_bufnr = vim.fn.bufnr(filepath)
        local was_loaded = existing_bufnr ~= -1 and vim.fn.bufloaded(existing_bufnr) == 1

        local bufnr = vim.fn.bufadd(filepath)
        if not was_loaded then
            vim.fn.bufload(bufnr)
        end

        vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })

        local positions = find_usage_positions(bufnr, fixture_name)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        for _, pos in ipairs(positions) do
            table.insert(items, {
                filename = filepath,
                lnum = pos.row + 1,
                col = pos.col_start + 1,
                text = lines[pos.row + 1] or "",
            })
        end

        if not was_loaded then
            vim.api.nvim_buf_delete(bufnr, { force = false })
        end
    end

    return items
end

M.show_usages = function()
    local fixture_name = vim.fn.expand("<cword>")
    if fixture_name == "" then
        warn("no word under cursor")
        return
    end

    local filepath = vim.api.nvim_buf_get_name(0)
    local root_dir = paths.split_at_root(filepath)
    if root_dir == nil then
        return
    end

    local items = find_all_usages(fixture_name, root_dir)

    if #items == 0 then
        warn(string.format('no usages found for fixture "%s"', fixture_name))
        return
    end

    vim.fn.setqflist(items, "r")
    vim.cmd("copen")
end

-- Internal exports for testing
M._find_usage_positions = find_usage_positions
M._find_all_usages = find_all_usages

return M
