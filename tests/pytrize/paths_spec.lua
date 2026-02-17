local paths = require("pytrize.paths")

-- Helper to create a temp directory tree with conftest.py files
local tmp_root = "/tmp/pytrize_paths_test"

local function setup_tree(conftests)
  -- conftests: list of relative dirs that should have a conftest.py
  vim.fn.mkdir(tmp_root, "p")
  for _, rel in ipairs(conftests) do
    local dir = tmp_root .. "/" .. rel
    vim.fn.mkdir(dir, "p")
    local f = io.open(dir .. "/conftest.py", "w")
    f:write("# conftest\n")
    f:close()
  end
end

local function teardown_tree()
  vim.fn.delete(tmp_root, "rf")
end

describe("get_conftest_chain", function()
  after_each(function()
    teardown_tree()
  end)

  it("finds conftest.py at root and subdirectory", function()
    setup_tree({ ".", "tests" })
    vim.fn.mkdir(tmp_root .. "/tests/unit", "p")
    local test_file = tmp_root .. "/tests/unit/test_foo.py"

    local chain = paths.get_conftest_chain(test_file, tmp_root)
    assert.are.same({
      tmp_root .. "/conftest.py",
      tmp_root .. "/tests/conftest.py",
    }, chain)
  end)

  it("returns empty when no conftest.py files exist", function()
    vim.fn.mkdir(tmp_root .. "/tests", "p")
    local test_file = tmp_root .. "/tests/test_foo.py"

    local chain = paths.get_conftest_chain(test_file, tmp_root)
    assert.are.same({}, chain)
  end)

  it("finds conftest.py only at root", function()
    setup_tree({ "." })
    vim.fn.mkdir(tmp_root .. "/tests", "p")
    local test_file = tmp_root .. "/tests/test_foo.py"

    local chain = paths.get_conftest_chain(test_file, tmp_root)
    assert.are.same({
      tmp_root .. "/conftest.py",
    }, chain)
  end)

  it("finds conftest.py at every level", function()
    setup_tree({ ".", "tests", "tests/unit" })
    local test_file = tmp_root .. "/tests/unit/test_foo.py"

    local chain = paths.get_conftest_chain(test_file, tmp_root)
    assert.are.same({
      tmp_root .. "/conftest.py",
      tmp_root .. "/tests/conftest.py",
      tmp_root .. "/tests/unit/conftest.py",
    }, chain)
  end)

  it("returns conftest chain in root-to-leaf order", function()
    setup_tree({ ".", "a", "a/b", "a/b/c" })
    local test_file = tmp_root .. "/a/b/c/test_deep.py"

    local chain = paths.get_conftest_chain(test_file, tmp_root)
    assert.are.equal(4, #chain)
    assert.are.equal(tmp_root .. "/conftest.py", chain[1])
    assert.are.equal(tmp_root .. "/a/b/c/conftest.py", chain[4])
  end)
end)
