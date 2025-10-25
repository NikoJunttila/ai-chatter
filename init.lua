-- File 1: lua/ollama-chat/init.lua
-- Main plugin entry point

local M = {}

-- Import modules
local ui = require "ollama-chat.ui"
local chat = require "ollama-chat.chat"

-- State holds all our plugin data
M.state = {
  buf = nil, -- The buffer ID for our chat window
  win = nil, -- The window ID for our chat window
  chat_history = {}, -- Array of messages {role: "user"/"assistant", content: "..."}
}

-- Open chat
function M.open()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    return
  end

  ui.create_window(M.state)
end

-- Close chat window
function M.close()
  ui.close_window(M.state)
end

-- Toggle chat
function M.toggle()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    M.close()
  else
    M.open()
  end
end

-- Clear chat history
function M.clear()
  M.state.chat_history = {}
  if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    ui.render_chat(M.state)
    ui.add_input_prompt(M.state)
  end
  print "Chat history cleared"
end

-- Send message (delegates to chat module)
function M.send_message()
  chat.send_message(M.state)
end

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Create commands
  vim.api.nvim_create_user_command("ChatToggle", M.toggle, { desc = "Toggle chat window" })
  vim.api.nvim_create_user_command("ChatClear", M.clear, { desc = "Clear chat history" })
end

return M
