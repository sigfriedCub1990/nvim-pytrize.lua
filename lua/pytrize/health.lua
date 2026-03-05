local M = {}

M.check = function()
    vim.health.start("pytrize")

    -- Check Neovim version
    if vim.fn.has("nvim-0.9.0") == 1 then
        vim.health.ok("Neovim >= 0.9.0")
    else
        vim.health.error("Neovim >= 0.9.0 required")
    end

    -- Check Python treesitter parser
    local ok = pcall(vim.treesitter.language.inspect, "python")
    if ok then
        vim.health.ok("Python treesitter parser installed")
    else
        vim.health.error("Python treesitter parser not found", {
            "Install with :TSInstall python (nvim-treesitter) or compile manually",
        })
    end

    -- Check for grep (used by fixture rename/usages)
    if vim.fn.executable("grep") == 1 then
        vim.health.ok("grep command available")
    else
        vim.health.warn("grep not found — fixture rename and usages features will not work")
    end

    -- Check highlight group
    local settings = require("pytrize.settings").settings
    if vim.fn.hlexists(settings.highlight) == 1 then
        vim.health.ok(string.format("Highlight group '%s' exists", settings.highlight))
    else
        vim.health.warn(string.format("Highlight group '%s' not found — virtual text may be invisible", settings.highlight))
    end
end

return M
