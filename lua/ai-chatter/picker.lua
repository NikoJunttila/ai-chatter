-- File 4: lua/ollama-chat/picker.lua
-- Picker utilities for selecting files/templates

local M = {}

-- Check if telescope is available
local function has_telescope()
  return pcall(require, "telescope")
end

-- Telescope-based file picker
local function telescope_file_picker(files, prompt_title, callback)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  pickers
    .new({}, {
      prompt_title = prompt_title,
      finder = finders.new_table {
        results = files,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display or entry.path,
            ordinal = entry.ordinal or entry.path,
            path = entry.path,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            callback(selection.value)
          end
        end)

        -- Allow multiple selections with <Tab>
        map("i", "<Tab>", actions.toggle_selection + actions.move_selection_worse)
        map("n", "<Tab>", actions.toggle_selection + actions.move_selection_worse)

        -- Confirm multiple selections with <CR> in visual mode
        map("i", "<C-CR>", function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local selections = picker:get_multi_selection()
          actions.close(prompt_bufnr)

          if #selections > 0 then
            for _, selection in ipairs(selections) do
              callback(selection.value)
            end
          else
            local selection = action_state.get_selected_entry()
            if selection then
              callback(selection.value)
            end
          end
        end)

        return true
      end,
    })
    :find()
end

-- Fallback vim.ui.select picker
local function builtin_picker(files, prompt_title, callback)
  local items = {}
  for _, file in ipairs(files) do
    table.insert(items, file.display or file.path)
  end

  vim.ui.select(items, {
    prompt = prompt_title .. ":",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if choice and idx then
      callback(files[idx])
    end
  end)
end

-- Main picker function
function M.pick_files(files, prompt_title, callback)
  if #files == 0 then
    print "No files available"
    return
  end

  prompt_title = prompt_title or "Select File"

  if has_telescope() then
    telescope_file_picker(files, prompt_title, callback)
  else
    builtin_picker(files, prompt_title, callback)
  end
end

-- Pick files from a directory with preview
function M.pick_from_directory(directory, callback, opts)
  opts = opts or {}
  local pattern = opts.pattern or "*"
  local recursive = opts.recursive or false

  -- Expand directory path
  directory = vim.fn.expand(directory)

  if vim.fn.isdirectory(directory) == 0 then
    print("Directory not found: " .. directory)
    return
  end

  -- Get files
  local glob_pattern = recursive and (directory .. "/**/" .. pattern) or (directory .. "/" .. pattern)
  local file_paths = vim.fn.globpath(directory, pattern, false, true)

  local files = {}
  for _, path in ipairs(file_paths) do
    if vim.fn.isdirectory(path) == 0 then -- Skip directories
      local relative_path = path:gsub("^" .. vim.pesc(directory) .. "/", "")
      local size = vim.fn.getfsize(path)
      local size_kb = math.floor(size / 1024)

      table.insert(files, {
        path = path,
        display = string.format("%s (%dKB)", relative_path, size_kb),
        ordinal = relative_path, -- For fuzzy searching
      })
    end
  end

  if #files == 0 then
    print("No files found in " .. directory)
    return
  end

  -- Sort by name
  table.sort(files, function(a, b)
    return a.ordinal < b.ordinal
  end)

  M.pick_files(files, "Select files from " .. vim.fn.fnamemodify(directory, ":t"), callback)
end

-- Pick a template
function M.pick_template(templates_dir, callback)
  local templates = {}

  if vim.fn.isdirectory(templates_dir) == 0 then
    print("Templates directory not found: " .. templates_dir)
    return
  end

  -- Get template directories
  local items = vim.fn.readdir(templates_dir)
  for _, item in ipairs(items) do
    local path = templates_dir .. "/" .. item
    if vim.fn.isdirectory(path) == 1 then
      -- Count files in template
      local file_count = 0
      local files = vim.fn.globpath(path, "*", false, true)
      for _, file in ipairs(files) do
        if vim.fn.isdirectory(file) == 0 then
          file_count = file_count + 1
        end
      end

      table.insert(templates, {
        name = item,
        path = path,
        display = string.format("%s (%d files)", item, file_count),
        ordinal = item,
      })
    end
  end

  if #templates == 0 then
    print("No templates found in " .. templates_dir)
    return
  end

  table.sort(templates, function(a, b)
    return a.name < b.name
  end)

  M.pick_files(templates, "Select Template", function(template)
    callback(template.name)
  end)
end

return M
