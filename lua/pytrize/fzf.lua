local M = {}

M.show_usages = function(items, fixture_name)
	local fzf_lua = require("fzf-lua")

	local entries = {}
	for _, item in ipairs(items) do
		-- fzf-lua understands "file:line:col:text" format natively
		table.insert(entries, string.format("%s:%d:%d:%s", item.filename, item.lnum, item.col, vim.trim(item.text)))
	end

	fzf_lua.fzf_exec(entries, {
		prompt = string.format('Usages of "%s"> ', fixture_name),
		actions = {
			["default"] = fzf_lua.actions.file_edit,
			["ctrl-s"] = fzf_lua.actions.file_split,
			["ctrl-v"] = fzf_lua.actions.file_vsplit,
			["ctrl-t"] = fzf_lua.actions.file_tabedit,
		},
		previewer = "builtin",
	})
end

return M
