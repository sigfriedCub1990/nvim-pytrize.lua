local M = {}

local split_once = require("pytrize.strings").split_once
local warn = require("pytrize.warn").warn
local get_nodeids_path = require("pytrize.paths").get_nodeids_path

local function get_raw_nodeids(rootdir)
    local nodeids_path = get_nodeids_path(rootdir)

    if vim.fn.filereadable(nodeids_path) ~= 1 then
        warn(string.format("Nodeids file not found: %s\nHave you run pytest?", nodeids_path))
        return {}
    end

    local ok_read, content = pcall(vim.fn.readfile, nodeids_path)
    if not ok_read then
        warn(string.format("Failed to read nodeids file: %s", nodeids_path))
        return {}
    end

    local ok_json, result = pcall(vim.fn.json_decode, content)
    if not ok_json then
        warn(string.format("Failed to parse nodeids JSON: %s", nodeids_path))
        return {}
    end

    return result
end

M.parse_raw = function(raw_nodeid)
    local file
    local func_name
    local rest
    local param_start_idx
    file, rest = split_once(raw_nodeid, "::", { plain = true })
    if rest == nil then
        -- no file
        file = nil
        rest = raw_nodeid
        param_start_idx = 0
    else
        param_start_idx = file:len() + 2
    end
    func_name, rest = split_once(rest, "[", { plain = true })
    if rest == nil then
        return
    end
    param_start_idx = param_start_idx + func_name:len() + 1

    -- local params, _ = split_once(rest, ']', {plain = true, right = true})
    return {
        file = file,
        func_name = func_name,
        params = rest,
        param_start_idx = param_start_idx + 1,
    }
end

M.get = function(rootdir)
    local nodeids = {}
    for _, raw_nodeid in ipairs(get_raw_nodeids(rootdir)) do
        local nodeid = M.parse_raw(raw_nodeid)
        if nodeid ~= nil then
            if nodeid.file == nil then
                warn("node id has no file")
                return {}
            end
            if nodeids[nodeid.file] == nil then
                nodeids[nodeid.file] = {}
            end
            if nodeids[nodeid.file][nodeid.func_name] == nil then
                nodeids[nodeid.file][nodeid.func_name] = {}
            end
            table.insert(nodeids[nodeid.file][nodeid.func_name], nodeid.params)
        end
    end
    return nodeids
end

return M
