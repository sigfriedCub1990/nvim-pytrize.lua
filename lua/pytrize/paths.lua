local M = {}

local warn = require('pytrize.warn').warn

local root_markers = {
    '.pytest_cache',
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'pytest.ini',
    'tox.ini',
    '.git',
}

local function is_root_dir(dir)
    for _, marker in ipairs(root_markers) do
        if vim.fn.finddir(marker, dir) ~= '' or vim.fn.findfile(marker, dir) ~= '' then
            return true
        end
    end
    return false
end

local function join_path(fragments)
    if #fragments == 1 and fragments[1] == '' then
        return '/'
    else
        return table.concat(fragments, '/')
    end
end

-- TODO better way to do this? (windows support?)
M.split_at_root = function(file)
    local dir_fragments = vim.fn.split(file, '/', 1)
    local rel_file_fragments = {}
    while #dir_fragments > 0 do
        table.insert(rel_file_fragments, 1, table.remove(dir_fragments, #dir_fragments))
        local dir = join_path(dir_fragments)
        if is_root_dir(dir) then
            return dir, join_path(rel_file_fragments)
        end
    end
    warn("couldn't find the pytest root dir")
end

M.get_conftest_chain = function(filepath, root_dir)
    local dir = vim.fn.fnamemodify(filepath, ':h')
    local chain = {}

    -- Walk from root_dir down to the file's directory.
    -- Build the list of directories from root to file dir, then check each for conftest.py.
    local dirs = {}
    local current = dir
    while #current >= #root_dir do
        table.insert(dirs, 1, current)
        local parent = vim.fn.fnamemodify(current, ':h')
        if parent == current then
            break
        end
        current = parent
    end

    for _, d in ipairs(dirs) do
        local conftest = d .. '/conftest.py'
        if vim.fn.filereadable(conftest) == 1 then
            table.insert(chain, conftest)
        end
    end

    return chain
end

M.get_nodeids_path = function(rootdir)
    return join_path{rootdir, '.pytest_cache', 'v', 'cache', 'nodeids'}
end

return M
