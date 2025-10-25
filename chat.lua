-- File 3: lua/ollama-chat/chat.lua
-- Chat logic - simplified to just echo

local M = {}
local ui = require "ollama-chat.ui"

-- Send message function
function M.send_message(state)
  -- Step 1: Get the user's input from the buffer
  local user_message = ui.get_user_input(state)

  -- Step 2: Validate that there's actually a message
  if user_message == "" then
    print "Please type a message first"
    return
  end

  -- Step 3: Add user message to chat history
  table.insert(state.chat_history, {
    role = "user",
    content = user_message,
  })

  -- Step 4: Create echo response (just repeat what user said)
  local echo_response = "You said: " .. user_message

  -- Step 5: Add bot response to chat history
  -- table.insert(state.chat_history, {
  --   role = "assistant",
  --   content = echo_response,
  -- })
  M.get_response(state, user_message)

  -- Step 6: Re-render the entire chat with new messages
  ui.render_chat(state)

  -- Step 7: Add the input prompt again at the bottom
  ui.add_input_prompt(state)

  -- Step 8: Move cursor to the input area
  ui.move_to_input(state)
end

function M.get_response(state, message)
  local response = ""
  print(message)
  if message == "test" then
    response = "works"
  else
    response = "xdd"
  end
  table.insert(state.chat_history, {
    role = "assistant",
    content = response,
  })
end

return M

-- load plugin in plugins folder
-- return {
--   {
--     dir = vim.fn.stdpath "config" .. "/lua/ollama-chat",
--     name = "ollama-chat.nvim",
--     lazy = false,
--     config = function()
--       require("ollama-chat").setup {}
--
--       -- Set up keybinding
--       vim.keymap.set("n", "<leader>oc", function()
--         require("ollama-chat").toggle()
--       end, { desc = "Toggle Chat" })
--
--       vim.keymap.set("n", "<leader>oC", function()
--         require("ollama-chat").clear()
--       end, { desc = "Clear Chat History" })
--     end,
--   },
-- }

-- Load from github.
-- return {
--   {
--     "yourusername/hello-world.nvim", -- replace with your GitHub username when published
--     lazy = false, -- load on startup
--     config = function()
--       require("hello-world").setup {}
--
--       -- Set up keybinding
--       vim.keymap.set("n", "<leader>hw", function()
--         require("hello-world").say_hello()
--       end, { desc = "Say Hello World" })
--     end,
--   },
-- }
