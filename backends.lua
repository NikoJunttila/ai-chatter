-- File 5: lua/ollama-chat/backends.lua
-- Backend implementations for different LLM APIs

local M = {}

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

-- Helper to unescape JSON
local function json_unescape(str)
  return str:gsub("\\n", "\n"):gsub("\\r", "\r"):gsub("\\t", "\t"):gsub('\\"', '"'):gsub("\\\\", "\\")
end

-- Build system message with context files
local function build_system_message(context_files)
  if #context_files == 0 then
    return "You are a helpful AI assistant in Neovim."
  end

  local parts = { "You are a helpful AI assistant in Neovim." }
  table.insert(parts, "\n\nThe user has provided the following reference files for context:")

  for i, file in ipairs(context_files) do
    table.insert(
      parts,
      string.format("\n\n--- File %d: %s ---\n%s\n--- End of %s ---", i, file.name, file.content, file.name)
    )
  end

  table.insert(parts, "\n\nUse these files as reference when answering questions.")

  return table.concat(parts)
end

-- ============================================================================
-- OLLAMA BACKEND
-- ============================================================================
M.ollama = {
  name = "Ollama",

  build_request = function(config, chat_history, context_files)
    local messages = {}

    -- Add system message
    local system_content = build_system_message(context_files)
    table.insert(messages, string.format('{"role":"system","content":"%s"}', json_escape(system_content)))

    -- Add chat history (exclude last message if it's thinking indicator)
    for i, msg in ipairs(chat_history) do
      if i < #chat_history or not msg.content:match "🤔" then
        table.insert(messages, string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content)))
      end
    end

    local messages_json = "[" .. table.concat(messages, ",") .. "]"
    local json_payload =
      string.format('{"model":"%s","messages":%s,"stream":false}', config.model or "gemma2:2b", messages_json)

    return {
      "curl",
      "-s",
      config.url or "http://127.0.0.1:11434/api/chat",
      "-d",
      json_payload,
    }
  end,

  parse_response = function(response_text)
    local content = response_text:match '"message"%s*:%s*{.-"content"%s*:%s*"(.-)"[,}]'
    if content then
      return json_unescape(content)
    end

    local error_msg = response_text:match '"error"%s*:%s*"(.-)"'
    if error_msg then
      return "Error: " .. error_msg
    end

    return "Error: Could not parse response"
  end,
}

-- ============================================================================
-- OPENAI BACKEND
-- ============================================================================
M.openai = {
  name = "OpenAI",

  build_request = function(config, chat_history, context_files)
    if not config.api_key then
      error "OpenAI API key not configured. Set api_key in setup()"
    end

    local messages = {}

    -- Add system message
    local system_content = build_system_message(context_files)
    table.insert(messages, string.format('{"role":"system","content":"%s"}', json_escape(system_content)))

    -- Add chat history
    for i, msg in ipairs(chat_history) do
      if i < #chat_history or not msg.content:match "🤔" then
        table.insert(messages, string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content)))
      end
    end

    local messages_json = "[" .. table.concat(messages, ",") .. "]"
    local json_payload = string.format('{"model":"%s","messages":%s}', config.model or "gpt-4o-mini", messages_json)

    return {
      "curl",
      "-s",
      config.url or "https://api.openai.com/v1/chat/completions",
      "-H",
      "Content-Type: application/json",
      "-H",
      "Authorization: Bearer " .. config.api_key,
      "-d",
      json_payload,
    }
  end,

  parse_response = function(response_text)
    -- OpenAI response format: {"choices":[{"message":{"content":"..."}}]}
    local content = response_text:match '"choices"%s*:%s*%[%s*{.-"message"%s*:%s*{.-"content"%s*:%s*"(.-)"'
    if content then
      return json_unescape(content)
    end

    -- Check for error
    local error_msg = response_text:match '"error"%s*:%s*{.-"message"%s*:%s*"(.-)"'
    if error_msg then
      return "Error: " .. json_unescape(error_msg)
    end

    return "Error: Could not parse OpenAI response"
  end,
}

-- ============================================================================
-- ANTHROPIC (CLAUDE) BACKEND
-- ============================================================================
M.anthropic = {
  name = "Anthropic",

  build_request = function(config, chat_history, context_files)
    if not config.api_key then
      error "Anthropic API key not configured. Set api_key in setup()"
    end

    local messages = {}
    local system_content = build_system_message(context_files)

    -- Add chat history (Anthropic doesn't use role "system" in messages array)
    for i, msg in ipairs(chat_history) do
      if i < #chat_history or not msg.content:match "🤔" then
        table.insert(messages, string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content)))
      end
    end

    local messages_json = "[" .. table.concat(messages, ",") .. "]"
    local json_payload = string.format(
      '{"model":"%s","messages":%s,"system":"%s","max_tokens":%d}',
      config.model or "claude-3-5-haiku-20241022",
      messages_json,
      json_escape(system_content),
      config.max_tokens or 4096
    )

    return {
      "curl",
      "-s",
      config.url or "https://api.anthropic.com/v1/messages",
      "-H",
      "Content-Type: application/json",
      "-H",
      "x-api-key: " .. config.api_key,
      "-H",
      "anthropic-version: 2023-06-01",
      "-d",
      json_payload,
    }
  end,

  parse_response = function(response_text)
    -- Anthropic response: {"content":[{"text":"..."}]}
    local content = response_text:match '"content"%s*:%s*%[%s*{%s*"text"%s*:%s*"(.-)"'
    if content then
      return json_unescape(content)
    end

    local error_msg = response_text:match '"error"%s*:%s*{.-"message"%s*:%s*"(.-)"'
    if error_msg then
      return "Error: " .. json_unescape(error_msg)
    end

    return "Error: Could not parse Anthropic response"
  end,
}

-- ============================================================================
-- GROQ BACKEND (Fast inference API)
-- ============================================================================
M.groq = {
  name = "Groq",

  build_request = function(config, chat_history, context_files)
    if not config.api_key then
      error "Groq API key not configured. Set api_key in setup()"
    end

    local messages = {}

    -- Add system message
    local system_content = build_system_message(context_files)
    table.insert(messages, string.format('{"role":"system","content":"%s"}', json_escape(system_content)))

    -- Add chat history
    for i, msg in ipairs(chat_history) do
      if i < #chat_history or not msg.content:match "🤔" then
        table.insert(messages, string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content)))
      end
    end

    local messages_json = "[" .. table.concat(messages, ",") .. "]"
    local json_payload =
      string.format('{"model":"%s","messages":%s}', config.model or "llama-3.3-70b-versatile", messages_json)

    return {
      "curl",
      "-s",
      config.url or "https://api.groq.com/openai/v1/chat/completions",
      "-H",
      "Content-Type: application/json",
      "-H",
      "Authorization: Bearer " .. config.api_key,
      "-d",
      json_payload,
    }
  end,

  parse_response = function(response_text)
    -- Groq uses OpenAI-compatible format
    local content = response_text:match '"choices"%s*:%s*%[%s*{.-"message"%s*:%s*{.-"content"%s*:%s*"(.-)"'
    if content then
      return json_unescape(content)
    end

    local error_msg = response_text:match '"error"%s*:%s*{.-"message"%s*:%s*"(.-)"'
    if error_msg then
      return "Error: " .. json_unescape(error_msg)
    end

    return "Error: Could not parse Groq response"
  end,
}

return M
