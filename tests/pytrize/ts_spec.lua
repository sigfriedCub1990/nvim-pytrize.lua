local has_parser = pcall(function()
  vim.treesitter.language.inspect("python")
end)

if not has_parser then
  describe("ts (skipped)", function()
    it("SKIPPED: python treesitter parser not installed", function()
      print("Skipping ts tests: python treesitter parser not available")
    end)
  end)
  return
end

local ts_utils = require("pytrize.ts")

local function create_python_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })
  local parser = vim.treesitter.get_parser(bufnr, "python")
  parser:parse()
  return bufnr
end

describe("get_fixture_defs", function()
  it("finds a bare @pytest.fixture definition", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      "@pytest.fixture",
      "def my_fixture():",
      "    return 42",
    })
    local defs = ts_utils.get_fixture_defs(bufnr)
    assert.are.equal(1, #defs)
    assert.are.equal("my_fixture", defs[1].name)
    assert.is_not_nil(defs[1].name_node)
    assert.is_not_nil(defs[1].func_node)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("finds a @pytest.fixture() call-form definition", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      "@pytest.fixture(scope='module')",
      "def my_fixture():",
      "    return 42",
    })
    local defs = ts_utils.get_fixture_defs(bufnr)
    assert.are.equal(1, #defs)
    assert.are.equal("my_fixture", defs[1].name)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("ignores plain functions without @pytest.fixture", function()
    local bufnr = create_python_buf({
      "def not_a_fixture():",
      "    return 42",
    })
    local defs = ts_utils.get_fixture_defs(bufnr)
    assert.are.equal(0, #defs)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("finds multiple fixtures in one file", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      "@pytest.fixture",
      "def fixture_a():",
      "    return 1",
      "",
      "@pytest.fixture(scope='session')",
      "def fixture_b():",
      "    return 2",
    })
    local defs = ts_utils.get_fixture_defs(bufnr)
    assert.are.equal(2, #defs)
    assert.are.equal("fixture_a", defs[1].name)
    assert.are.equal("fixture_b", defs[2].name)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("ignores @pytest.mark.parametrize and other decorators", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      '@pytest.mark.parametrize("x", [1, 2])',
      "def test_foo(x):",
      "    pass",
    })
    local defs = ts_utils.get_fixture_defs(bufnr)
    assert.are.equal(0, #defs)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)

local function write_tmp_py(name, lines)
  local path = "/tmp/pytrize_test_" .. name .. ".py"
  local f = io.open(path, "w")
  f:write(table.concat(lines, "\n") .. "\n")
  f:close()
  return path
end

describe("scan_fixtures", function()
  it("returns fixtures keyed by name with file and linenr", function()
    local path = write_tmp_py("scan1", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def db():",
      "    return 'connection'",
    })
    local fixtures = ts_utils.scan_fixtures(path)
    assert.is_not_nil(fixtures.db)
    assert.are.equal(path, fixtures.db.file)
    assert.are.equal(4, fixtures.db.linenr)
    os.remove(path)
  end)

  it("returns multiple fixtures from one file", function()
    local path = write_tmp_py("scan2", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def alpha():",
      "    return 1",
      "",
      "@pytest.fixture",
      "def beta():",
      "    return 2",
    })
    local fixtures = ts_utils.scan_fixtures(path)
    assert.is_not_nil(fixtures.alpha)
    assert.is_not_nil(fixtures.beta)
    assert.are.equal(4, fixtures.alpha.linenr)
    assert.are.equal(8, fixtures.beta.linenr)
    os.remove(path)
  end)

  it("returns empty table for file with no fixtures", function()
    local path = write_tmp_py("scan3", {
      "def helper():",
      "    return 42",
    })
    local fixtures = ts_utils.scan_fixtures(path)
    assert.are.same({}, fixtures)
    os.remove(path)
  end)

  it("cleans up buffer for files that were not previously loaded", function()
    local path = write_tmp_py("scan4", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def temp():",
      "    pass",
    })
    assert.are.equal(-1, vim.fn.bufnr(path))
    ts_utils.scan_fixtures(path)
    assert.are.equal(-1, vim.fn.bufnr(path))
    os.remove(path)
  end)
end)

-- build_fixture_index tests
local tmp_root = "/tmp/pytrize_index_test"

local function write_py(path, lines)
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  local f = io.open(path, "w")
  f:write(table.concat(lines, "\n") .. "\n")
  f:close()
end

local function teardown()
  vim.fn.delete(tmp_root, "rf")
end

describe("build_fixture_index", function()
  after_each(teardown)

  it("finds fixtures from conftest.py and the test file", function()
    write_py(tmp_root .. "/conftest.py", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def db():",
      "    return 'conn'",
    })
    write_py(tmp_root .. "/tests/test_foo.py", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def local_fix():",
      "    return 1",
      "",
      "def test_it(db, local_fix):",
      "    pass",
    })

    local fixtures = ts_utils.build_fixture_index(tmp_root .. "/tests/test_foo.py", tmp_root)
    assert.is_not_nil(fixtures.db)
    assert.are.equal(tmp_root .. "/conftest.py", fixtures.db.file)
    assert.is_not_nil(fixtures.local_fix)
    assert.are.equal(tmp_root .. "/tests/test_foo.py", fixtures.local_fix.file)
  end)

  it("inner conftest overrides outer conftest for same fixture name", function()
    write_py(tmp_root .. "/conftest.py", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def db():",
      "    return 'outer'",
    })
    write_py(tmp_root .. "/tests/conftest.py", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def db():",
      "    return 'inner'",
    })
    vim.fn.mkdir(tmp_root .. "/tests", "p")
    local test_file = tmp_root .. "/tests/test_foo.py"
    write_py(test_file, { "def test_it(db): pass" })

    local fixtures = ts_utils.build_fixture_index(test_file, tmp_root)
    assert.is_not_nil(fixtures.db)
    assert.are.equal(tmp_root .. "/tests/conftest.py", fixtures.db.file)
  end)

  it("test file fixture overrides conftest fixture", function()
    write_py(tmp_root .. "/conftest.py", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def db():",
      "    return 'conftest'",
    })
    write_py(tmp_root .. "/tests/test_foo.py", {
      "import pytest",
      "",
      "@pytest.fixture",
      "def db():",
      "    return 'local'",
    })

    local fixtures = ts_utils.build_fixture_index(tmp_root .. "/tests/test_foo.py", tmp_root)
    assert.are.equal(tmp_root .. "/tests/test_foo.py", fixtures.db.file)
  end)

  it("returns empty when no fixtures exist anywhere", function()
    vim.fn.mkdir(tmp_root .. "/tests", "p")
    write_py(tmp_root .. "/tests/test_foo.py", { "def test_it(): pass" })

    local fixtures = ts_utils.build_fixture_index(tmp_root .. "/tests/test_foo.py", tmp_root)
    assert.are.same({}, fixtures)
  end)
end)
