-- File 3: lua/ollama-chat/chat.lua
local M = {}
local ui = require "ollama-chat.ui"
local backends = require "ollama-chat.backends"

-- Current backend (set by init.lua)
M.backend = nil
M.backend_config = {}

-- Send message function
function M.send_message(state)
  local user_message = ui.get_user_input(state)

  if user_message == "" then
    print "Please type a message first"
    return
  end

  table.insert(state.chat_history, {
    role = "user",
    content = user_message,
  })

  -- Show thinking indicator
  table.insert(state.chat_history, {
    role = "assistant",
    content = "🤔 Thinking...",
  })

  ui.render_chat(state)
  ui.add_input_prompt(state)

  -- Get response asynchronously
  M.get_response_async(state, function(response)
    -- Remove thinking indicator
    table.remove(state.chat_history)

    -- Add actual response
    table.insert(state.chat_history, {
      role = "assistant",
      content = response,
    })

    ui.render_chat(state)
    ui.add_input_prompt(state)
    ui.move_to_input(state)
  end)
end

-- Async response function
function M.get_response_async(state, callback)
  if not M.backend then
    callback "Error: No backend configured"
    return
  end

  -- Build request using backend
  local cmd_args = M.backend.build_request(M.backend_config, state.chat_history, state.context_files)

  -- Execute async
  if vim.system then
    vim.system(
      cmd_args,
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          callback("Error: Request failed with code " .. result.code .. "\n" .. (result.stderr or ""))
          return
        end

        local response = M.backend.parse_response(result.stdout)
        callback(response)
      end)
    )
  else
    -- Fallback for older Neovim
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)
    local stdout_data = ""
    local stderr_data = ""

    local handle
    handle = vim.loop.spawn(
      cmd_args[1],
      {
        args = vim.list_slice(cmd_args, 2),
        stdio = { nil, stdout, stderr },
      },
      vim.schedule_wrap(function(code, signal)
        stdout:close()
        stderr:close()
        handle:close()

        if code ~= 0 then
          callback("Error: Request failed with code " .. code .. "\n" .. stderr_data)
          return
        end

        local response = M.backend.parse_response(stdout_data)
        callback(response)
      end)
    )

    stdout:read_start(function(err, data)
      if err then
        callback("Error reading stdout: " .. err)
      elseif data then
        stdout_data = stdout_data .. data
      end
    end)

    stderr:read_start(function(err, data)
      if err then
        -- Ignore
      elseif data then
        stderr_data = stderr_data .. data
      end
    end)
  end
end

-- Add a file as context
function M.add_context_file(state, filepath)
  local expanded_path = vim.fn.expand(filepath)

  if vim.fn.filereadable(expanded_path) == 0 then
    print("Error: File not found: " .. expanded_path)
    return false
  end

  -- Check if already added
  for _, file in ipairs(state.context_files) do
    if file.path == expanded_path then
      print("File already added: " .. expanded_path)
      return false
    end
  end

  local lines = vim.fn.readfile(expanded_path)
  local content = table.concat(lines, "\n")

  if #content > 100000 then
    local confirm = vim.fn.confirm("File is large (" .. math.floor(#content / 1024) .. "KB). Continue?", "&Yes\n&No", 2)
    if confirm ~= 1 then
      return false
    end
  end

  table.insert(state.context_files, {
    path = expanded_path,
    name = vim.fn.fnamemodify(expanded_path, ":t"),
    content = content,
  })

  print("Added context file: " .. expanded_path)
  return true
end

function M.remove_context_file(state, index)
  if index and state.context_files[index] then
    local removed = table.remove(state.context_files, index)
    print("Removed context file: " .. removed.path)
    return true
  end
  return false
end

function M.clear_context_files(state)
  state.context_files = {}
  print "Cleared all context files"
end

return M
