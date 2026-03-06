local M = {}

--- Jump to fixture definition under cursor.
M.jump_fixture = function()
	local jump = require("pytrize.jump")

	jump.to_fixture_declaration()
end

--- Rename fixture under cursor across the project.
M.rename_fixture = function()
	local rename = require("pytrize.rename")

	rename.rename_fixture()
end

--- Show all usages of fixture under cursor.
M.fixture_usages = function()
	local usages = require("pytrize.usages")

	usages.show_usages()
end

return M
