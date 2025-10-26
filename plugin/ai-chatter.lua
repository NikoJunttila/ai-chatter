-- This file auto-loads when Neovim starts
if vim.fn.has("nvim-0.7.0") == 0 then
	vim.api.nvim_err_writeln("ai-chatter requires at least nvim-0.7.0")
	return
end

-- Prevent loading twice
if vim.g.loaded_ai_chatter then
	return
end
vim.g.loaded_ai_chatter = true

-- Create user commands
vim.api.nvim_create_user_command("AiChatter", function()
	require("ai-chatter").open_chat()
end, {})

vim.api.nvim_create_user_command("AiChatter", function()
	require("ai-chatter").toggle_context_file()
end, {})
