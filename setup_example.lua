return {
	{
		"nikojunttila/ai-chatter",
		lazy = false,
		config = function()
			require("ai-chatter").setup({
				-- Choose backend: "ollama", "openai", "anthropic", "groq"
				backend = "groq",

				backend_config = {
					-- OpenAI config
					-- api_key = os.getenv "OPENAI_API_KEY", -- or hardcode (not recommended)
					-- model = "gemma3:270m", -- or "gpt-4o", "gpt-3.5-turbo"

					-- Ollama config (if using ollama)
					-- model = "gemma3:270m",
					-- url = "http://127.0.0.1:11434/api/chat",

					-- Anthropic config (if using anthropic)
					-- api_key = os.getenv("ANTHROPIC_API_KEY"),
					-- model = "claude-3-5-haiku-20241022",
					-- max_tokens = 4096,

					-- Groq config (if using groq - free tier available!)
					api_key = os.getenv("GROQ_API_KEY"),
					model = "llama-3.3-70b-versatile",
				},

				contexts_dir = "~/.config/llmcontexts",
			})

			-- Keybindings
			vim.keymap.set("n", "<leader>oc", function()
				require("ai-chatter").open()
			end, { desc = "Open chat" })

			vim.keymap.set("n", "<leader>cb", function()
				require("ai-chatter").add_current_buffer()
			end, { desc = "Add current buffer to chat" })

			vim.keymap.set("n", "<leader>cf", function()
				require("ai-chatter").browse_files()
			end, { desc = "Browse context files" })

			vim.keymap.set("n", "<leader>cR", function()
				require("ai-chatter").reset_all()
			end, { desc = "Reset chat & contexts" })

			-- Info
			vim.keymap.set("n", "<leader>cl", function()
				require("ai-chatter").list_files()
			end, { desc = "List context files" })
		end,
	},
}
