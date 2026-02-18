local has_parser = pcall(function()
	vim.treesitter.language.inspect("python")
end)

if not has_parser then
	describe("usages (skipped)", function()
		it("SKIPPED: python treesitter parser not installed", function()
			print("Skipping usages tests: python treesitter parser not available")
		end)
	end)
	return
end

local usages = require("pytrize.usages")

local function create_python_buf(lines)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })
	local parser = vim.treesitter.get_parser(bufnr, "python")
	parser:parse()
	return bufnr
end

describe("find_usage_positions", function()
	it("finds fixture used as a plain parameter", function()
		local bufnr = create_python_buf({
			"def test_foo(my_fixture):",
			"    assert my_fixture == 42",
		})
		local positions = usages._find_usage_positions(bufnr, "my_fixture")
		-- param (row 0) + body ref (row 1)
		assert.are.equal(2, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("finds fixture used as a typed parameter", function()
		local bufnr = create_python_buf({
			"def test_foo(my_fixture: MagicMock):",
			"    my_fixture.assert_called()",
		})
		local positions = usages._find_usage_positions(bufnr, "my_fixture")
		-- typed param (row 0) + body ref (row 1)
		assert.are.equal(2, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("finds fixture in @pytest.mark.usefixtures", function()
		local bufnr = create_python_buf({
			"import pytest",
			"",
			'@pytest.mark.usefixtures("my_fixture")',
			"def test_foo(self):",
			"    pass",
		})
		local positions = usages._find_usage_positions(bufnr, "my_fixture")
		assert.are.equal(1, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does NOT include the fixture definition itself", function()
		local bufnr = create_python_buf({
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
		})
		local positions = usages._find_usage_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does NOT find attribute access (db.my_fixture)", function()
		local bufnr = create_python_buf({
			"def test_foo(db):",
			"    x = db.my_fixture",
		})
		local positions = usages._find_usage_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does NOT find keyword argument names", function()
		local bufnr = create_python_buf({
			"def test_foo(db):",
			"    call(my_fixture=1)",
		})
		local positions = usages._find_usage_positions(bufnr, "my_fixture")
		assert.are.equal(0, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("finds both definition and consumer when they coexist, but only the consumer positions", function()
		local bufnr = create_python_buf({
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
			"",
			"def test_uses(my_fixture):",
			"    assert my_fixture",
		})
		local positions = usages._find_usage_positions(bufnr, "my_fixture")
		-- param (row 6) + body ref (row 7); definition on row 3 is excluded
		assert.are.equal(2, #positions)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)

local tmp_root = "/tmp/pytrize_usages_test"

local function write_py(path, lines)
	local dir = vim.fn.fnamemodify(path, ":h")
	vim.fn.mkdir(dir, "p")
	local f = io.open(path, "w")
	f:write(table.concat(lines, "\n") .. "\n")
	f:close()
end

describe("find_all_usages", function()
	after_each(function()
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name:find(tmp_root, 1, true) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end
		vim.fn.delete(tmp_root, "rf")
	end)

	it("returns quickfix items for usages across files", function()
		vim.fn.mkdir(tmp_root .. "/.git", "p")

		write_py(tmp_root .. "/conftest.py", {
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
		})
		write_py(tmp_root .. "/test_a.py", {
			"def test_uses(my_fixture):",
			"    assert my_fixture",
		})
		write_py(tmp_root .. "/test_b.py", {
			"import pytest",
			"",
			'@pytest.mark.usefixtures("my_fixture")',
			"def test_indirect(self):",
			"    pass",
		})

		local items = usages._find_all_usages("my_fixture", tmp_root)

		-- Each item must have the quickfix fields
		assert.is_true(#items > 0)
		for _, item in ipairs(items) do
			assert.is_not_nil(item.filename)
			assert.is_not_nil(item.lnum)
			assert.is_not_nil(item.col)
			assert.is_not_nil(item.text)
		end
	end)

	it("does NOT include the fixture definition in results", function()
		vim.fn.mkdir(tmp_root .. "/.git", "p")

		write_py(tmp_root .. "/conftest.py", {
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
		})
		write_py(tmp_root .. "/test_a.py", {
			"def test_uses(my_fixture):",
			"    assert my_fixture",
		})

		local items = usages._find_all_usages("my_fixture", tmp_root)

		-- conftest.py line 4 is the definition — must not appear
		for _, item in ipairs(items) do
			local in_conftest = item.filename:find("conftest.py", 1, true) ~= nil
			local is_def_line = item.lnum == 4
			assert.is_false(in_conftest and is_def_line, "definition should not appear in usages")
		end
	end)

	it("finds the right files and line numbers", function()
		vim.fn.mkdir(tmp_root .. "/.git", "p")

		write_py(tmp_root .. "/conftest.py", {
			"import pytest",
			"",
			"@pytest.fixture",
			"def my_fixture():",
			"    return 42",
		})
		write_py(tmp_root .. "/test_a.py", {
			"def test_uses(my_fixture):",
			"    assert my_fixture",
		})

		local items = usages._find_all_usages("my_fixture", tmp_root)

		-- Find the parameter usage in test_a.py line 1
		local found_param = false
		for _, item in ipairs(items) do
			if item.filename:find("test_a.py", 1, true) and item.lnum == 1 then
				found_param = true
				assert.is_true(item.col > 0)
				assert.is_not_nil(item.text:find("my_fixture"))
			end
		end
		assert.is_true(found_param, "expected to find parameter usage in test_a.py line 1")
	end)
end)
