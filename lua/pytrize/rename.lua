local M = {}

local ts = vim.treesitter
local warn = require("pytrize.warn").warn
local paths = require("pytrize.paths")
local ts_utils = require("pytrize.ts")
local utils = require("pytrize.utils")

local function hrtime()
    return (vim.uv or vim.loop).hrtime()
end
local function ms(t)
    return string.format("%.1fms", t / 1e6)
end

local function get_fixture_name()
    return vim.fn.expand("<cword>")
end

local function find_python_files(root_dir, name)
    local result =
        vim.fn.systemlist(string.format('grep -rl --include="*.py" "%s" "%s"', vim.fn.escape(name, '"\\'), root_dir))
    return result
end

local function get_param_name_node(param_node)
    local t = param_node:type()
    if t == "identifier" then
        return param_node
    elseif t == "default_parameter" or t == "typed_default_parameter" then
        return param_node:field("name")[1]
    elseif t == "typed_parameter" then
        -- typed_parameter has no 'name' field; the identifier is the first named child
        local first = param_node:named_child(0)
        if first and first:type() == "identifier" then
            return first
        end
    end
    return nil
end

local function get_param_names(parameters_node, bufnr)
    local names = {}
    for child in parameters_node:iter_children() do
        local name_node = get_param_name_node(child)
        if name_node then
            table.insert(names, ts.get_node_text(name_node, bufnr))
        end
    end
    return names
end

local function find_body_references(body_node, old_name, bufnr)
    local positions = {}

    local function walk_body(node, shadowed)
        if shadowed then
            return
        end

        local node_type = node:type()

        if node_type == "function_definition" then
            local params_node = node:field("parameters")[1]
            if params_node then
                local param_names = get_param_names(params_node, bufnr)
                local re_declares = false
                for _, p in ipairs(param_names) do
                    if p == old_name then
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
            if ts.get_node_text(node, bufnr) == old_name then
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

local find_rename_positions = function(bufnr, old_name)
    local ok = pcall(function()
        vim.treesitter.language.inspect("python")
    end)
    if not ok then
        warn("Python treesitter parser not installed - cannot rename fixture")
        return nil
    end

    local parser = ts.get_parser(bufnr, "python")
    local tree = parser:parse()[1]
    local root = tree:root()

    local positions = {}

    -- Case A: Fixture definitions
    for _, def in ipairs(ts_utils.get_fixture_defs(bufnr)) do
        if def.name == old_name then
            local row, col_start, _, col_end = def.name_node:range()
            table.insert(positions, { row = row, col_start = col_start, col_end = col_end })
        end
    end

    ts_utils.walk(root, function(node)
        local node_type = node:type()

        -- Case B: Fixture consumer
        if node_type == "function_definition" then
            local params_node = node:field("parameters")[1]
            if params_node then
                local found_param_node = nil
                for child in params_node:iter_children() do
                    local name_node = get_param_name_node(child)
                    if name_node and ts.get_node_text(name_node, bufnr) == old_name then
                        found_param_node = name_node
                        break
                    end
                end

                if found_param_node then
                    local row, col_start, _, col_end = found_param_node:range()
                    table.insert(positions, { row = row, col_start = col_start, col_end = col_end })

                    local body_node = node:field("body")[1]
                    if body_node then
                        local body_refs = find_body_references(body_node, old_name, bufnr)
                        for _, pos in ipairs(body_refs) do
                            table.insert(positions, pos)
                        end
                    end
                end
            end
        end

        -- Case C: @pytest.mark.usefixtures("old_name") string arguments
        if node_type == "call" then
            local func = node:field("function")[1]
            if func and func:type() == "attribute" then
                local func_text = ts.get_node_text(func, bufnr)
                if func_text == "pytest.mark.usefixtures" then
                    local args = node:field("arguments")[1]
                    if args then
                        for child in args:iter_children() do
                            if child:type() == "string" then
                                -- Find the string_content child which holds the text without quotes
                                for schild in child:iter_children() do
                                    if schild:type() == "string_content" then
                                        if ts.get_node_text(schild, bufnr) == old_name then
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

local apply_renames = function(bufnr, positions, new_name)
    table.sort(positions, function(a, b)
        if a.row ~= b.row then
            return a.row > b.row
        end
        return a.col_start > b.col_start
    end)

    for _, pos in ipairs(positions) do
        vim.api.nvim_buf_set_text(bufnr, pos.row, pos.col_start, pos.row, pos.col_end, { new_name })
    end

    return #positions
end

local function rename(old_name, new_name)
    if old_name == new_name then
        warn(string.format('New name is the same as old name: "%s"', old_name))
        return
    end

    local current_file = vim.api.nvim_buf_get_name(0)
    local root_dir = paths.split_at_root(current_file)
    if root_dir == nil then
        return
    end

    ts_utils.clear_scan_cache()
    local t0 = hrtime()

    local py_files = find_python_files(root_dir, old_name)
    if #py_files == 0 then
        warn(string.format('No Python files contain "%s"', old_name))
        return
    end

    local t_grep = hrtime()

    -- First pass: determine which files to process. Only rename in files where
    -- the fixture resolves to the current file (not shadowed by a closer definition).
    local files_to_process = {}
    for _, filepath in ipairs(py_files) do
        if filepath == current_file then
            table.insert(files_to_process, filepath)
        else
            local index = ts_utils.build_fixture_index(filepath, root_dir)
            local resolved = index[old_name]
            if resolved and resolved.file == current_file then
                table.insert(files_to_process, filepath)
            end
        end
    end

    local t_scope = hrtime()

    local total_replacements = 0
    local files_changed = 0

    for _, filepath in ipairs(files_to_process) do
        local abort = false
        utils.with_buf(filepath, function(bufnr)
            local positions = find_rename_positions(bufnr, old_name)
            if positions == nil then
                abort = true
                return
            end

            if #positions > 0 then
                local count = apply_renames(bufnr, positions, new_name)
                total_replacements = total_replacements + count
                files_changed = files_changed + 1

                vim.api.nvim_buf_call(bufnr, function()
                    vim.cmd("write")
                end)
            end
        end)
        if abort then
            return
        end
    end

    local t_end = hrtime()

    if total_replacements == 0 then
        warn(string.format('No fixture references found for "%s"', old_name))
    else
        local msg = string.format(
            'Pytrize: Renamed "%s" -> "%s" in %d file(s) (%d occurrence(s))',
            old_name,
            new_name,
            files_changed,
            total_replacements
        )
        if require("pytrize.settings").settings.metrics then
            msg = msg
                .. string.format(
                    "\n  total=%s  grep=%s  scoping=%s  apply=%s",
                    ms(t_end - t0),
                    ms(t_grep - t0),
                    ms(t_scope - t_grep),
                    ms(t_end - t_scope)
                )
        end
        vim.notify(msg, vim.log.levels.INFO)
    end
end

M.rename_fixture = function()
    local old_name = get_fixture_name()
    if old_name == "" then
        warn("No word under cursor")
        return
    end

    vim.ui.input({ prompt = string.format('Rename fixture "%s" to: ', old_name) }, function(new_name)
        if new_name == nil or new_name == "" then
            return
        end
        rename(old_name, new_name)
    end)
end

-- Internal exports for testing
M._find_rename_positions = find_rename_positions
M._apply_renames = apply_renames
M._rename = rename

return M
