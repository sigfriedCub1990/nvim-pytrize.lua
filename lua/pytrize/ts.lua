local M = {}

local ts = vim.treesitter

M.walk = function(node, callback)
  callback(node)
  for child in node:iter_children() do
    M.walk(child, callback)
  end
end

M.is_fixture_decorator = function(node, bufnr)
  local node_type = node:type()
  if node_type == 'attribute' then
    return ts.get_node_text(node, bufnr) == 'pytest.fixture'
  elseif node_type == 'call' then
    local func = node:field('function')[1]
    if func and func:type() == 'attribute' then
      return ts.get_node_text(func, bufnr) == 'pytest.fixture'
    end
  end
  return false
end

M.get_fixture_defs = function(bufnr)
  local parser = ts.get_parser(bufnr, 'python')
  local tree = parser:parse()[1]
  local root = tree:root()

  local defs = {}

  M.walk(root, function(node)
    if node:type() ~= 'decorated_definition' then
      return
    end

    local has_fixture_decorator = false
    for child in node:iter_children() do
      if child:type() == 'decorator' then
        for dchild in child:iter_children() do
          if M.is_fixture_decorator(dchild, bufnr) then
            has_fixture_decorator = true
            break
          end
        end
      end
    end

    if has_fixture_decorator then
      local func = node:field('definition')[1]
      if func and func:type() == 'function_definition' then
        local name_node = func:field('name')[1]
        if name_node then
          -- Detect enclosing class (decorated_definition → block → class_definition)
          local class_start, class_end
          local parent = node:parent()
          if parent and parent:type() == 'block' then
            local grandparent = parent:parent()
            if grandparent and grandparent:type() == 'class_definition' then
              local cs, _, ce, _ = grandparent:range()
              class_start = cs + 1  -- 1-indexed
              class_end = ce + 1
            end
          end
          table.insert(defs, {
            name = ts.get_node_text(name_node, bufnr),
            name_node = name_node,
            func_node = func,
            class_start = class_start,
            class_end = class_end,
          })
        end
      end
    end
  end)

  return defs
end

local scan_cache = {}

M.clear_scan_cache = function()
  scan_cache = {}
end

M.scan_fixtures = function(filepath)
  if scan_cache[filepath] then
    return scan_cache[filepath]
  end

  local existing_bufnr = vim.fn.bufnr(filepath)
  local was_loaded = existing_bufnr ~= -1 and vim.fn.bufloaded(existing_bufnr) == 1

  local bufnr = vim.fn.bufadd(filepath)
  if not was_loaded then
    vim.fn.bufload(bufnr)
  end

  vim.api.nvim_set_option_value('filetype', 'python', { buf = bufnr })

  local ok, defs = pcall(M.get_fixture_defs, bufnr)

  if not was_loaded then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if not ok then
    return {}
  end

  local fixtures = {}
  for _, def in ipairs(defs) do
    local row, col = def.func_node:start()
    local entry = {
      file = filepath,
      linenr = row + 1,
      col = col,
      class_start = def.class_start,
      class_end = def.class_end,
    }
    if fixtures[def.name] == nil then
      fixtures[def.name] = { entry }
    else
      table.insert(fixtures[def.name], entry)
    end
  end

  scan_cache[filepath] = fixtures
  return fixtures
end

-- Resolve the best fixture from a list of candidates for a given cursor line.
-- Prefers the candidate in the same class as the cursor; falls back to
-- top-level fixtures, then to the last candidate.
local function resolve_fixture(candidates, cursor_line)
  if #candidates == 1 or cursor_line == nil then
    return candidates[#candidates]
  end

  -- Try to find a candidate whose enclosing class contains cursor_line
  for _, loc in ipairs(candidates) do
    if loc.class_start and loc.class_end
      and cursor_line >= loc.class_start and cursor_line <= loc.class_end then
      return loc
    end
  end

  -- Cursor is outside any class → prefer a top-level (classless) candidate
  for _, loc in ipairs(candidates) do
    if loc.class_start == nil then
      return loc
    end
  end

  -- Fallback: last candidate
  return candidates[#candidates]
end

M.build_fixture_index = function(filepath, root_dir, cursor_line)
  local paths = require('pytrize.paths')
  local fixtures = {}

  -- Scan conftest.py chain (root to leaf); later entries override earlier ones
  local chain = paths.get_conftest_chain(filepath, root_dir)
  for _, conftest in ipairs(chain) do
    local cf = M.scan_fixtures(conftest)
    for name, candidates in pairs(cf) do
      fixtures[name] = candidates[#candidates]
    end
  end

  -- Scan the test file itself (fixtures defined here take priority)
  if vim.fn.filereadable(filepath) == 1 then
    local ff = M.scan_fixtures(filepath)
    for name, candidates in pairs(ff) do
      fixtures[name] = resolve_fixture(candidates, cursor_line)
    end
  end

  return fixtures
end

return M
