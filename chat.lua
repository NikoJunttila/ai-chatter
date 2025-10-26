-- File 3: lua/ollama-chat/chat.lua
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

  -- Step 4: Get response from Ollama (with full history)
  M.get_response(state)

  -- Step 5: Re-render the entire chat with new messages
  ui.render_chat(state)

  -- Step 6: Add the input prompt again at the bottom
  ui.add_input_prompt(state)

  -- Step 7: Move cursor to the input area
  ui.move_to_input(state)
end

function M.get_response(state)
  local response = M.query_ollama_chat(state.chat_history)
  table.insert(state.chat_history, {
    role = "assistant",
    content = response,
  })
end

-- Helper function to escape strings for JSON
local function json_escape(str)
  local escape_chars = {
    ["\\"] = "\\\\",
    ['"'] = '\\"',
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
  }
  return str:gsub('[\\"\n\r\t\b\f]', escape_chars)
end

-- New function using /api/chat endpoint with conversation history
function M.query_ollama_chat(chat_history)
  -- Build messages array for the API with proper escaping
  local messages = {}
  for _, msg in ipairs(chat_history) do
    local escaped_content = json_escape(msg.content)
    table.insert(messages, string.format('{"role":"%s","content":"%s"}', msg.role, escaped_content))
  end
  local messages_json = "[" .. table.concat(messages, ",") .. "]"

  -- Build full JSON payload
  local json = string.format('{"model":"gemma3:270m","messages":%s,"stream":false}', messages_json)

  local cmd = "curl -s http://127.0.0.1:11434/api/chat -d " .. vim.fn.shellescape(json)

  local res = vim.fn.system(cmd)

  -- Parse the response
  -- For /api/chat, the response is in message.content
  local content = res:match '"message"%s*:%s*{.-"content"%s*:%s*"(.-)"[,}]'

  if content then
    -- Unescape JSON escape sequences
    content = content:gsub("\\n", "\n")
    content = content:gsub("\\r", "\r")
    content = content:gsub("\\t", "\t")
    content = content:gsub('\\"', '"')
    content = content:gsub("\\\\", "\\")
    return content
  else
    -- Try to extract error message
    local error_msg = res:match '"error"%s*:%s*"(.-)"'
    if error_msg then
      return "Error: " .. error_msg
    end
    return "Error: Could not parse response. Raw: " .. res:sub(1, 200)
  end
end

return M
