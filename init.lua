-- File 1: lua/ollama-chat/init.lua
local M = {}
local ui = require "ollama-chat.ui"
local chat = require "ollama-chat.chat"
local picker = require "ollama-chat.picker"
local backends = require "ollama-chat.backends"

-- Plugin state
local state = {
  buf = nil,
  win = nil,
  chat_history = {},
  context_files = {},
}

-- Configuration
local config = {
  templates_dir = vim.fn.stdpath "config" .. "/ollama-chat-templates",
  contexts_dir = vim.fn.expand "~/.config/llmcontexts",
}

-- Open the chat window
function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    print "Chat is already open"
    return
  end

  ui.create_window(state)
end

-- Close the chat window
function M.close()
  ui.close_window(state)
end

-- Send a message
function M.send_message()
  chat.send_message(state)
end

-- Add a file as context
function M.add_file(filepath)
  if not filepath or filepath == "" then
    -- If no filepath provided, use file picker
    filepath = vim.fn.input("Enter file path: ", "", "file")
  end

  if filepath and filepath ~= "" then
    chat.add_context_file(state, filepath)
    -- Refresh UI if window is open
    M.refresh_ui()
  end
end

-- Browse and add files from a directory with picker
function M.browse_files(directory)
  if not directory or directory == "" then
    -- Use default contexts directory if it exists
    if vim.fn.isdirectory(config.contexts_dir) == 1 then
      directory = config.contexts_dir
    else
      directory = vim.fn.input("Enter directory path: ", vim.fn.getcwd(), "dir")
    end
  end

  if directory == "" then
    return
  end

  picker.pick_from_directory(directory, function(file)
    chat.add_context_file(state, file.path)
    M.refresh_ui()
  end)
end

-- Add current buffer as context
function M.add_current_buffer()
  local current_buf = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(current_buf)

  if filepath == "" then
    print "Current buffer has no file associated"
    return
  end

  chat.add_context_file(state, filepath)
  M.refresh_ui()
end

-- Remove a context file with picker
function M.remove_file(index)
  if #state.context_files == 0 then
    print "No context files to remove"
    return
  end

  if not index then
    -- Use picker to select file to remove
    local files = {}
    for i, file in ipairs(state.context_files) do
      local size_kb = math.floor(#file.content / 1024)
      table.insert(files, {
        index = i,
        path = file.path,
        display = string.format("%d. %s (%dKB)", i, file.name, size_kb),
        ordinal = file.name,
      })
    end

    picker.pick_files(files, "Remove Context File", function(file)
      chat.remove_context_file(state, file.index)
      M.refresh_ui()
    end)
  else
    chat.remove_context_file(state, index)
    M.refresh_ui()
  end
end

-- List context files
function M.list_files()
  if #state.context_files == 0 then
    print "No context files added"
    return
  end

  print "Context files:"
  for i, file in ipairs(state.context_files) do
    local size_kb = math.floor(#file.content / 1024)
    print(string.format("%d. %s (%dKB)", i, file.path, size_kb))
  end
end

-- Get available templates
local function get_templates()
  local templates = {}

  if vim.fn.isdirectory(config.templates_dir) == 0 then
    return templates
  end

  local items = vim.fn.readdir(config.templates_dir)
  for _, item in ipairs(items) do
    local path = config.templates_dir .. "/" .. item
    if vim.fn.isdirectory(path) == 1 then
      table.insert(templates, item)
    end
  end

  table.sort(templates)
  return templates
end

-- Load a context template with picker
function M.load_template(template_name)
  if not template_name or template_name == "" then
    -- Use picker to select template
    picker.pick_template(config.templates_dir, function(selected_name)
      M.load_template_by_name(selected_name)
    end)
    return
  end

  M.load_template_by_name(template_name)
end

-- Internal function to load template by name
function M.load_template_by_name(template_name)
  local template_path = config.templates_dir .. "/" .. template_name

  if vim.fn.isdirectory(template_path) == 0 then
    print("Template not found: " .. template_name)
    return
  end

  local files = vim.fn.globpath(template_path, "*", false, true)

  if #files == 0 then
    print("Template is empty: " .. template_name)
    return
  end

  local added_count = 0
  for _, file in ipairs(files) do
    if vim.fn.isdirectory(file) == 0 then
      if chat.add_context_file(state, file) then
        added_count = added_count + 1
      end
    end
  end

  print(string.format("Loaded template '%s' (%d files)", template_name, added_count))
  M.refresh_ui()
end

-- List available templates
function M.list_templates()
  local templates = get_templates()

  if #templates == 0 then
    print("No templates found in " .. config.templates_dir)
    print "\nTo create templates:"
    print("1. Create directory: " .. config.templates_dir)
    print "2. Create template folders inside (e.g., 'lua', 'python', 'react')"
    print "3. Add context files to each template folder"
    return
  end

  print "Available templates:"
  for _, tmpl in ipairs(templates) do
    local template_path = config.templates_dir .. "/" .. tmpl
    local files = vim.fn.globpath(template_path, "*", false, true)
    local file_count = 0
    for _, file in ipairs(files) do
      if vim.fn.isdirectory(file) == 0 then
        file_count = file_count + 1
      end
    end
    print(string.format("  • %s (%d files)", tmpl, file_count))
  end

  print("\nTemplates directory: " .. config.templates_dir)
end

-- Save current context as template
function M.save_template(template_name)
  if #state.context_files == 0 then
    print "No context files to save"
    return
  end

  if not template_name or template_name == "" then
    template_name = vim.fn.input "Enter template name: "
  end

  if template_name == "" then
    print "Template name required"
    return
  end

  if vim.fn.isdirectory(config.templates_dir) == 0 then
    vim.fn.mkdir(config.templates_dir, "p")
  end

  local template_path = config.templates_dir .. "/" .. template_name

  if vim.fn.isdirectory(template_path) == 0 then
    vim.fn.mkdir(template_path, "p")
  else
    local confirm = vim.fn.confirm("Template '" .. template_name .. "' already exists. Overwrite?", "&Yes\n&No", 2)
    if confirm ~= 1 then
      return
    end
  end

  local saved_count = 0
  for _, file in ipairs(state.context_files) do
    local dest = template_path .. "/" .. file.name
    local success = vim.fn.writefile(vim.fn.readfile(file.path), dest)
    if success == 0 then
      saved_count = saved_count + 1
    end
  end

  print(string.format("Saved template '%s' (%d files) to %s", template_name, saved_count, template_path))
end

-- Helper to refresh UI
function M.refresh_ui()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    ui.render_chat(state)
    ui.add_input_prompt(state)
    ui.move_to_input(state)
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Configure backend
  local backend_name = opts.backend or "ollama"
  chat.backend = backends[backend_name]

  if not chat.backend then
    error("Unknown backend: " .. backend_name .. ". Available: ollama, openai, anthropic, groq")
  end

  chat.backend_config = opts.backend_config or {}

  -- Allow custom configuration
  if opts.templates_dir then
    config.templates_dir = vim.fn.expand(opts.templates_dir)
  end

  if opts.contexts_dir then
    config.contexts_dir = vim.fn.expand(opts.contexts_dir)
  end

  -- Create contexts directory if it doesn't exist
  if vim.fn.isdirectory(config.contexts_dir) == 0 then
    vim.fn.mkdir(config.contexts_dir, "p")
    print("Created contexts directory: " .. config.contexts_dir)
  end

  -- Create user commands
  vim.api.nvim_create_user_command("ChatOpen", function()
    M.open()
  end, { desc = "Open chat window" })

  vim.api.nvim_create_user_command("ChatClose", function()
    M.close()
  end, { desc = "Close chat window" })

  vim.api.nvim_create_user_command("ChatAddFile", function(args)
    M.add_file(args.args)
  end, { nargs = "?", complete = "file", desc = "Add file as context" })

  vim.api.nvim_create_user_command("ChatBrowseFiles", function(args)
    M.browse_files(args.args)
  end, { nargs = "?", complete = "dir", desc = "Browse and add files from contexts directory" })

  vim.api.nvim_create_user_command("ChatAddBuffer", function()
    M.add_current_buffer()
  end, { desc = "Add current buffer as context" })

  vim.api.nvim_create_user_command("ChatRemoveFile", function(args)
    local index = tonumber(args.args)
    M.remove_file(index)
  end, { nargs = "?", desc = "Remove context file" })

  vim.api.nvim_create_user_command("ChatListFiles", function()
    M.list_files()
  end, { desc = "List context files" })

  vim.api.nvim_create_user_command("ChatLoadTemplate", function(args)
    M.load_template(args.args)
  end, { nargs = "?", desc = "Load context template" })

  vim.api.nvim_create_user_command("ChatListTemplates", function()
    M.list_templates()
  end, { desc = "List available templates" })

  vim.api.nvim_create_user_command("ChatSaveTemplate", function(args)
    M.save_template(args.args)
  end, { nargs = "?", desc = "Save current context as template" })
end

return M
