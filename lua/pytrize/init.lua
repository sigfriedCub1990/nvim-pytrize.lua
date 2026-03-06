local M = {}

local settings = require("pytrize.settings")

local function setup_commands()
	vim.api.nvim_create_user_command("PytrizeJumpFixture", function()
		require("pytrize.api").jump_fixture()
	end, { desc = "Jump to fixture definition under cursor" })
	vim.api.nvim_create_user_command("PytrizeRenameFixture", function()
		require("pytrize.api").rename_fixture()
	end, { desc = "Rename fixture under cursor across project" })
	vim.api.nvim_create_user_command("PytrizeFixtureUsages", function()
		require("pytrize.api").fixture_usages()
	end, { desc = "Show fixture usages in quickfix list" })
end

--- Configure the pytrize plugin.
---@param opts? PytrizeSettings
M.setup = function(opts)
	opts = opts or {}
	settings.update(opts)
	if not settings.settings.no_commands then
		setup_commands()
	end
end

return M
