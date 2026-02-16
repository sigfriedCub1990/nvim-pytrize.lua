local has_parser = pcall(function()
	vim.treesitter.language.inspect("python")
end)

if not has_parser then
	describe("rename (skipped)", function()
		it("SKIPPED: python treesitter parser not installed", function()
			print("Skipping rename tests: python treesitter parser not available")
		end)
	end)
	return
end

local rename = require("pytrize.rename")

local function create_python_buf(lines)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })
	local parser = vim.treesitter.get_parser(bufnr, "python")
	parser:parse()
	return bufnr
end

describe("find_rename_positions - fixture definitions", function()
	it("finds @pytest.fixture bare decorator", function()
		local bufnr = create_python_buf({
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.is_not_nil(positions)
		assert.are.equal(1, #positions)
		assert.are.equal(3, positions[1].row)
		assert.are.equal(4, positions[1].col_start)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("finds @pytest.fixture() call decorator", function()
		local bufnr = create_python_buf({
			"import pytest",
			"",
			"@pytest.fixture(scope='module')",
			"def my_fixture():",
			"    return 42",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.is_not_nil(positions)
		assert.are.equal(1, #positions)
		assert.are.equal(3, positions[1].row)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not match a plain function without @pytest.fixture", function()
		local bufnr = create_python_buf({
			"def my_fixture():",
			"    return 42",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)

describe("find_rename_positions - fixture consumers", function()
	it("finds parameter and body references", function()
		local bufnr = create_python_buf({
			"def test_foo(my_fixture):",
			"    result = my_fixture.value",
			"    assert my_fixture == 42",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		-- 1: parameter (row 0), 2: body ref row 1 (object of attribute), 3: body ref row 2
		assert.are.equal(3, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does NOT rename the attribute field of an attribute access", function()
		local bufnr = create_python_buf({
			"def test_foo(db):",
			"    x = db.my_fixture",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does NOT rename keyword argument names", function()
		local bufnr = create_python_buf({
			"def test_foo(db):",
			"    call(my_fixture=1)",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("handles nested function shadowing", function()
		local bufnr = create_python_buf({
			"def test_foo(my_fixture):",
			"    def inner(my_fixture):",
			"        return my_fixture + 1",
			"    return my_fixture",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		-- outer param (row 0), inner param (row 1), inner body ref (row 2), outer body ref (row 3)
		-- Both functions are consumers; shadowing prevents double-counting from the outer body walk
		assert.are.equal(4, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not rename in functions without the parameter", function()
		local bufnr = create_python_buf({
			"def test_foo(other):",
			"    my_fixture = 42",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("finds typed parameter and its body references", function()
		local bufnr = create_python_buf({
			"def test_foo(self, my_fixture: MagicMock):",
			"    my_fixture.assert_called_once()",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		-- typed param (row 0), body ref (row 1)
		assert.are.equal(2, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("finds typed default parameter and its body references", function()
		local bufnr = create_python_buf({
			"def test_foo(my_fixture: Any = None):",
			"    print(my_fixture)",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		-- typed default param (row 0), body ref (row 1)
		assert.are.equal(2, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)

describe("find_rename_positions - usefixtures", function()
	it("renames fixture name inside @pytest.mark.usefixtures", function()
		local bufnr = create_python_buf({
			'import pytest',
			'',
			'@pytest.mark.usefixtures("my_fixture")',
			'def test_foo(self):',
			'    pass',
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.are.equal(1, #positions)
		assert.are.equal(2, positions[1].row)
		-- string_content starts after the opening quote
		assert.are.equal(26, positions[1].col_start)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("renames only matching fixture among multiple usefixtures args", function()
		local bufnr = create_python_buf({
			'import pytest',
			'',
			'@pytest.mark.usefixtures("other", "my_fixture")',
			'def test_foo(self):',
			'    pass',
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.are.equal(1, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not rename non-matching usefixtures strings", function()
		local bufnr = create_python_buf({
			'import pytest',
			'',
			'@pytest.mark.usefixtures("other_fixture")',
			'def test_foo(self):',
			'    pass',
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)

describe("find_rename_positions - combined", function()
	it("finds both fixture definition and consumers", function()
		local bufnr = create_python_buf({
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
			"",
			"def test_use(my_fixture):",
			"    assert my_fixture == 42",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		-- def name (row 3), param (row 6), body ref (row 7)
		assert.are.equal(3, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("finds definition, usefixtures, param, and body refs together", function()
		local bufnr = create_python_buf({
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
			"",
			'@pytest.mark.usefixtures("my_fixture")',
			"def test_indirect(self):",
			"    pass",
			"",
			"def test_direct(my_fixture):",
			"    assert my_fixture",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		-- def name (row 3), usefixtures string (row 6), param (row 10), body ref (row 11)
		assert.are.equal(4, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)

describe("apply_renames", function()
	it("replaces identifiers in buffer", function()
		local bufnr = create_python_buf({
			"def test_foo(my_fixture):",
			"    assert my_fixture == 42",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		rename._apply_renames(bufnr, positions, "new_fix")
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.equal("def test_foo(new_fix):", lines[1])
		assert.are.equal("    assert new_fix == 42", lines[2])
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("handles renames on the same line", function()
		local bufnr = create_python_buf({
			"def test_foo(my_fixture):",
			"    x = my_fixture + my_fixture",
		})
		local positions = rename._find_rename_positions(bufnr, "my_fixture")
		rename._apply_renames(bufnr, positions, "f")
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.equal("def test_foo(f):", lines[1])
		assert.are.equal("    x = f + f", lines[2])
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)
