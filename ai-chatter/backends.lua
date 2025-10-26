-- File 5: lua/ollama-chat/backends.lua
-- Backend implementations for different LLM APIs

local M = {}

-- Enable debug logging (set to false to disable)
local DEBUG = false

-- Helper function for debug logging
local function debug_log(message, data)
	if not DEBUG then
		return
	end

	local log_file = io.open(vim.fn.stdpath("cache") .. "/ollama-chat-debug.log", "a")
	if log_file then
		log_file:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), message))
		if data then
			log_file:write(string.format("Data: %s\n", vim.inspect(data)))
		end
		log_file:write("\n")
		log_file:close()
	end
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

-- Helper to unescape JSON strings properly
local function json_unescape(str)
	if not str then
		return ""
	end

	local result = {}
	local i = 1
	local len = #str

	while i <= len do
		local char = str:sub(i, i)

		if char == "\\" and i < len then
			local next_char = str:sub(i + 1, i + 1)

			if next_char == "n" then
				table.insert(result, "\n")
				i = i + 2
			elseif next_char == "r" then
				table.insert(result, "\r")
				i = i + 2
			elseif next_char == "t" then
				table.insert(result, "\t")
				i = i + 2
			elseif next_char == "b" then
				table.insert(result, "\b")
				i = i + 2
			elseif next_char == "f" then
				table.insert(result, "\f")
				i = i + 2
			elseif next_char == '"' then
				table.insert(result, '"')
				i = i + 2
			elseif next_char == "\\" then
				table.insert(result, "\\")
				i = i + 2
			elseif next_char == "/" then
				table.insert(result, "/")
				i = i + 2
			elseif next_char == "u" then
				-- Handle unicode escapes \uXXXX
				if i + 5 <= len then
					local hex = str:sub(i + 2, i + 5)
					local code = tonumber(hex, 16)
					if code then
						-- Basic ASCII handling
						if code < 128 then
							table.insert(result, string.char(code))
						else
							-- For non-ASCII, keep the original escape
							table.insert(result, str:sub(i, i + 5))
						end
						i = i + 6
					else
						-- Invalid unicode escape, keep backslash
						table.insert(result, "\\")
						i = i + 1
					end
				else
					table.insert(result, "\\")
					i = i + 1
				end
			else
				-- Unknown escape sequence - just skip the backslash
				-- This handles cases like \x or other invalid escapes
				table.insert(result, next_char)
				i = i + 2
			end
		else
			table.insert(result, char)
			i = i + 1
		end
	end

	return table.concat(result)
end

-- Helper function to robustly parse JSON content field
-- This properly handles escaped quotes within the content
local function parse_json_content(response_text, field_name)
	field_name = field_name or "content"

	debug_log("parse_json_content looking for field:", field_name)

	-- Build pattern to find: "field_name":"
	local pattern = '"' .. field_name .. '"%s*:%s*"'
	local start_pos = response_text:find(pattern)

	if not start_pos then
		debug_log("Field not found")
		return nil
	end

	debug_log("Field found at position:", start_pos)

	-- Find where the actual content starts (after the opening quote)
	local content_start = start_pos
	while content_start <= #response_text do
		if
			response_text:sub(content_start, content_start) == '"'
			and response_text:sub(content_start - 1, content_start - 1) == ":"
		then
			content_start = content_start + 1
			break
		end
		content_start = content_start + 1
	end

	if content_start > #response_text then
		debug_log("Could not find content start")
		return nil
	end

	debug_log("Content starts at position:", content_start)

	-- Now parse character by character, respecting escape sequences
	local result = {}
	local pos = content_start
	local escaped = false

	while pos <= #response_text do
		local char = response_text:sub(pos, pos)

		if escaped then
			-- This character is escaped, add both backslash and character
			table.insert(result, "\\")
			table.insert(result, char)
			escaped = false
		elseif char == "\\" then
			-- Next character will be escaped
			escaped = true
		elseif char == '"' then
			-- Found unescaped quote - this is the end of the string
			local raw_content = table.concat(result)
			debug_log("Raw content extracted, length:", #raw_content)
			debug_log("First 200 chars:", raw_content:sub(1, 200))

			local unescaped = json_unescape(raw_content)
			debug_log("Unescaped content, length:", #unescaped)
			debug_log("First 200 chars:", unescaped:sub(1, 200))

			return unescaped
		else
			-- Regular character
			table.insert(result, char)
		end

		pos = pos + 1
	end

	debug_log("Reached end without finding closing quote")
	return nil
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
			if i < #chat_history or not msg.content:match("🤔") then
				table.insert(
					messages,
					string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content))
				)
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
		debug_log("Ollama raw response:", response_text)

		-- Use robust parser that handles escaped quotes
		local content = parse_json_content(response_text, "content")

		if content then
			return content
		end

		local error_msg = parse_json_content(response_text, "error")
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
			error("OpenAI API key not configured. Set api_key in setup()")
		end

		local messages = {}

		-- Add system message
		local system_content = build_system_message(context_files)
		table.insert(messages, string.format('{"role":"system","content":"%s"}', json_escape(system_content)))

		-- Add chat history
		for i, msg in ipairs(chat_history) do
			if i < #chat_history or not msg.content:match("🤔") then
				table.insert(
					messages,
					string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content))
				)
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
		debug_log("OpenAI raw response:", response_text)

		-- Use robust parser that handles escaped quotes
		local content = parse_json_content(response_text, "content")

		if content then
			return content
		end

		-- Check for error
		local error_msg = parse_json_content(response_text, "message")
		if error_msg then
			return "Error: " .. error_msg
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
			error("Anthropic API key not configured. Set api_key in setup()")
		end

		local messages = {}
		local system_content = build_system_message(context_files)

		-- Add chat history (Anthropic doesn't use role "system" in messages array)
		for i, msg in ipairs(chat_history) do
			if i < #chat_history or not msg.content:match("🤔") then
				table.insert(
					messages,
					string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content))
				)
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
		debug_log("Anthropic raw response:", response_text)

		-- Anthropic uses "text" field instead of "content"
		local content = parse_json_content(response_text, "text")

		if content then
			return content
		end

		local error_msg = parse_json_content(response_text, "message")
		if error_msg then
			return "Error: " .. error_msg
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
			error("Groq API key not configured. Set api_key in setup()")
		end

		local messages = {}

		-- Add system message
		local system_content = build_system_message(context_files)
		table.insert(messages, string.format('{"role":"system","content":"%s"}', json_escape(system_content)))

		-- Add chat history
		for i, msg in ipairs(chat_history) do
			if i < #chat_history or not msg.content:match("🤔") then
				table.insert(
					messages,
					string.format('{"role":"%s","content":"%s"}', msg.role, json_escape(msg.content))
				)
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
		debug_log("Groq raw response:", response_text)

		-- Use robust parser that handles escaped quotes
		local content = parse_json_content(response_text, "content")

		if content then
			return content
		end

		local error_msg = parse_json_content(response_text, "message")
		if error_msg then
			return "Error: " .. error_msg
		end

		return "Error: Could not parse Groq response"
	end,
}

return M
