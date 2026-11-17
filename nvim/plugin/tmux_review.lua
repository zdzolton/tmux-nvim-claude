if vim.g.loaded_tmux_review then
	return
end
vim.g.loaded_tmux_review = 1

require("tmux_review").register()

vim.api.nvim_create_user_command("ReviewClear", function()
	require("tmux_review").clear()
end, {})
