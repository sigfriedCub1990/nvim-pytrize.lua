local M = {}

local settings = require("pytrize.settings")

local function setup_commands()
    vim.cmd('command Pytrize lua require("pytrize.api").set()')
    vim.cmd('command PytrizeClear lua require("pytrize.api").clear()')
    vim.cmd('command PytrizeJump lua require("pytrize.api").jump()')
    vim.cmd('command PytrizeJumpFixture lua require("pytrize.api").jump_fixture()')
    vim.cmd('command PytrizeRenameFixture lua require("pytrize.api").rename_fixture()')
    vim.cmd('command PytrizeFixtureUsages lua require("pytrize.api").fixture_usages()')
end

M.setup = function(opts)
    if opts == nil then
        opts = {}
    end
    settings.update(opts)
    if not settings.settings.no_commands then
        setup_commands()
    end
end

return M
