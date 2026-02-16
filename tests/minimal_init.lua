local plenary_dir = "/tmp/plenary.nvim"
local ts_dir = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter"

vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(plenary_dir)
if vim.fn.isdirectory(ts_dir) == 1 then
  vim.opt.runtimepath:append(ts_dir)
end

vim.cmd("runtime plugin/plenary.vim")
