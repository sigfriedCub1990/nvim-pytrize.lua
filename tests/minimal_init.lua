local plenary_dir = "/tmp/plenary.nvim"
local ts_dirs = {
  vim.fn.stdpath("data") .. "/lazy/nvim-treesitter",
  "/tmp/nvim-treesitter",
}

vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(plenary_dir)
for _, ts_dir in ipairs(ts_dirs) do
  if vim.fn.isdirectory(ts_dir) == 1 then
    vim.opt.runtimepath:append(ts_dir)
  end
end

vim.cmd("runtime plugin/plenary.vim")
