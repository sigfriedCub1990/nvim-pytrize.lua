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
		assert.are.equal(1, #fixtures.db)
		assert.are.equal(path, fixtures.db[1].file)
		assert.are.equal(4, fixtures.db[1].linenr)
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
		assert.are.equal(4, fixtures.alpha[1].linenr)
		assert.are.equal(8, fixtures.beta[1].linenr)
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

	it("returns col=0 for a top-level fixture", function()
		local path = write_tmp_py("scan_col_top", {
			"import pytest",
			"",
			"@pytest.fixture",
			"def db():",
			"    return 'connection'",
		})
		local fixtures = ts_utils.scan_fixtures(path)
		assert.are.equal(0, fixtures.db[1].col)
		os.remove(path)
	end)

	it("returns correct col for a fixture defined inside a class", function()
		local path = write_tmp_py("scan_col_class", {
			"import pytest",
			"",
			"class TestFixtures:",
			"    @pytest.fixture",
			"    def class_fix(self):",
			"        return 42",
		})
		local fixtures = ts_utils.scan_fixtures(path)
		assert.are.equal(5, fixtures.class_fix[1].linenr)
		assert.are.equal(4, fixtures.class_fix[1].col)
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
	ts_utils.clear_scan_cache()
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

	it("resolves same-named fixture across N classes to the one containing the cursor", function()
		local test_file = tmp_root .. "/tests/test_n_classes.py"
		write_py(test_file, {
			"import pytest", -- 1
			"", -- 2
			"class TestFirst:", -- 3
			"    @pytest.fixture", -- 4
			"    def my_fix(self):", -- 5
			"        return 'first'", -- 6
			"", -- 7
			"    def test_it(self, my_fix):", -- 8
			"        pass", -- 9
			"", -- 10
			"class TestSecond:", -- 11
			"    @pytest.fixture", -- 12
			"    def my_fix(self):", -- 13
			"        return 'second'", -- 14
			"", -- 15
			"    def test_it(self, my_fix):", -- 16
			"        pass", -- 17
			"", -- 18
			"class TestThird:", -- 19
			"    @pytest.fixture", -- 20
			"    def my_fix(self):", -- 21
			"        return 'third'", -- 22
			"", -- 23
			"    def test_it(self, my_fix):", -- 24
			"        pass", -- 25
			"", -- 26
			"class TestFourth:", -- 27
			"    @pytest.fixture", -- 28
			"    def my_fix(self):", -- 29
			"        return 'fourth'", -- 30
			"", -- 31
			"    def test_it(self, my_fix):", -- 32
			"        pass", -- 33
		})

		local cases = {
			{ cursor = 8, expected_line = 5 }, -- TestFirst
			{ cursor = 16, expected_line = 13 }, -- TestSecond
			{ cursor = 24, expected_line = 21 }, -- TestThird
			{ cursor = 32, expected_line = 29 }, -- TestFourth
		}

		for _, c in ipairs(cases) do
			ts_utils.clear_scan_cache()
			local fixtures = ts_utils.build_fixture_index(test_file, tmp_root, c.cursor)
			assert.are.equal(
				c.expected_line,
				fixtures.my_fix.linenr,
				string.format("cursor at line %d should resolve to line %d", c.cursor, c.expected_line)
			)
		end
	end)

	it("resolves to top-level fixture when cursor is outside any class", function()
		local test_file = tmp_root .. "/tests/test_mixed.py"
		write_py(test_file, {
			"import pytest", -- 1
			"", -- 2
			"@pytest.fixture", -- 3
			"def my_fix():", -- 4
			"    return 'top'", -- 5
			"", -- 6
			"class TestInner:", -- 7
			"    @pytest.fixture", -- 8
			"    def my_fix(self):", -- 9
			"        return 'class'", -- 10
			"", -- 11
			"def test_top(my_fix):", -- 12
			"    pass", -- 13
		})

		-- Cursor on line 12 (outside class) → should resolve to top-level line 4
		local fixtures = ts_utils.build_fixture_index(test_file, tmp_root, 12)
		assert.are.equal(4, fixtures.my_fix.linenr)
	end)
end)
