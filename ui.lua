-- File 2: lua/ollama-chat/ui.lua
-- UI rendering and window management

local M = {}

-- Create floating window
function M.create_window(state)
  -- Calculate window size (80% of screen)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  -- Calculate position to center the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create a new buffer (false = not listed, true = scratch buffer)
  state.buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(state.buf, "bufhidden", "wipe") -- Delete buffer when hidden
  vim.api.nvim_buf_set_option(state.buf, "filetype", "markdown") -- Enable markdown syntax

  -- Window configuration
  local opts = {
    style = "minimal", -- No line numbers, etc.
    relative = "editor", -- Relative to the editor window
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded", -- Rounded border
  }

  -- Create the floating window
  state.win = vim.api.nvim_open_win(state.buf, true, opts)
  vim.api.nvim_win_set_option(state.win, "wrap", true) -- Enable word wrap

  -- Set keymaps for the chat window
  local plugin = require "ollama-chat"
  vim.keymap.set("n", "q", function()
    plugin.close()
  end, { buffer = state.buf, desc = "Close chat" })
  vim.keymap.set("n", "<Esc>", function()
    plugin.close()
  end, { buffer = state.buf, desc = "Close chat" })
  vim.keymap.set("n", "<CR>", function()
    plugin.send_message()
  end, { buffer = state.buf, desc = "Send message" })
  vim.keymap.set("i", "<C-s>", function()
    plugin.send_message()
  end, { buffer = state.buf, desc = "Send message" })

  -- Initial content
  M.render_chat(state)
  M.add_input_prompt(state)

  -- Move cursor to the last line and enter insert mode
  local line_count = vim.api.nvim_buf_line_count(state.buf)
  vim.api.nvim_win_set_cursor(state.win, { line_count, 0 })
  vim.cmd "startinsert"
end

-- Render the entire chat history to the buffer
function M.render_chat(state)
  local lines = { "# Chat Box", "" }

  -- Loop through all messages and add them to lines
  for _, msg in ipairs(state.chat_history) do
    if msg.role == "user" then
      table.insert(lines, "**You:** " .. msg.content)
      table.insert(lines, "") -- Empty line for spacing
    else
      table.insert(lines, "**Bot:**")
      local bot_lines = vim.split(msg.content, "\n", { trimempty = true })
      vim.list_extend(lines, bot_lines)
      table.insert(lines, "") -- Empty line for spacing
    end
  end

  -- Replace all buffer content with new lines
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
end

-- Add the input prompt at the bottom of the buffer
function M.add_input_prompt(state)
  vim.api.nvim_buf_set_lines(state.buf, -1, -1, false, {
    "",
    "─────────────────────────────────────────",
    "Type your message below and press <CR> to send (q to quit):",
    "",
  })
end

-- Move cursor to bottom and enter insert mode
function M.move_to_input(state)
  if vim.api.nvim_buf_is_valid(state.buf) and vim.api.nvim_win_is_valid(state.win) then
    local line_count = vim.api.nvim_buf_line_count(state.buf)
    vim.api.nvim_win_set_cursor(state.win, { line_count, 0 })
    vim.cmd "startinsert"
  end
end

-- Close the chat window
function M.close_window(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
end

-- Extract user input from the buffer
function M.get_user_input(state)
  -- Get all lines from the buffer
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)

  -- Loop backwards to find the last line with actual content
  -- Skip empty lines and our UI elements
  for i = #lines, 1, -1 do
    local line = vim.trim(lines[i])
    if
      line ~= ""
      and not line:match "^%-+$" -- Not a separator line
      and not line:match "^Type your message" -- Not instructions
      and not line:match "^#" -- Not a header
      and not line:match "^%*%*"
    then -- Not a chat message
      return line
    end
  end

  return ""
end

return M
