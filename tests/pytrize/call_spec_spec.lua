local has_parser = pcall(function()
  vim.treesitter.language.inspect("python")
end)

if not has_parser then
  describe("call_spec (skipped)", function()
    it("SKIPPED: python treesitter parser not installed", function()
      print("Skipping call_spec tests: python treesitter parser not available")
    end)
  end)
  return
end

local call_spec = require("pytrize.call_spec")

local function create_python_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })

  -- Force treesitter parse
  local parser = vim.treesitter.get_parser(bufnr, "python")
  parser:parse()

  return bufnr
end

describe("call_spec.get_calls", function()
  it("parses single-param parametrize with strings", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      '@pytest.mark.parametrize("name", [',
      '    "alice",',
      '    "bob",',
      "])",
      "def test_greet(name):",
      "    pass",
    })

    local result = call_spec.get_calls(bufnr)
    assert.is_not_nil(result)
    assert.is_not_nil(result["test_greet"])
    assert.are.equal(1, #result["test_greet"])

    local spec = result["test_greet"][1]
    assert.are.equal("test_greet", spec.func_name)
    assert.are.same({ "name" }, spec.params)
    assert.are.equal(2, #spec.entries)
    assert.are.equal("alice", spec.entries[1].id)
    assert.are.equal("bob", spec.entries[2].id)

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("parses multi-param parametrize with tuples", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      '@pytest.mark.parametrize("x, y", [',
      "    (1, 2),",
      "    (3, 4),",
      "])",
      "def test_add(x, y):",
      "    pass",
    })

    local result = call_spec.get_calls(bufnr)
    assert.is_not_nil(result)

    local spec = result["test_add"][1]
    assert.are.same({ "x", "y" }, spec.params)
    assert.are.equal(2, #spec.entries)
    assert.are.equal("1-2", spec.entries[1].id)
    assert.are.equal("3-4", spec.entries[2].id)

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("parses mixed types: int, float, bool, None", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      '@pytest.mark.parametrize("val", [',
      "    42,",
      "    3.14,",
      "    True,",
      "    False,",
      "    None,",
      "])",
      "def test_types(val):",
      "    pass",
    })

    local result = call_spec.get_calls(bufnr)
    assert.is_not_nil(result)

    local spec = result["test_types"][1]
    assert.are.equal(5, #spec.entries)
    assert.are.equal("42", spec.entries[1].id)
    assert.are.equal("3.14", spec.entries[2].id)
    assert.are.equal("True", spec.entries[3].id)
    assert.are.equal("False", spec.entries[4].id)
    assert.are.equal("None", spec.entries[5].id)

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  it("handles multiple decorators on one function", function()
    local bufnr = create_python_buf({
      "import pytest",
      "",
      '@pytest.mark.parametrize("a", [1, 2])',
      '@pytest.mark.parametrize("b", [3, 4])',
      "def test_combo(a, b):",
      "    pass",
    })

    local result = call_spec.get_calls(bufnr)
    assert.is_not_nil(result)
    assert.are.equal(2, #result["test_combo"])

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)
