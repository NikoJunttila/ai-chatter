# Ollama Chat for Neovim

Chat with LLMs directly in Neovim with support for multiple backends (Ollama, OpenAI, Anthropic, Groq).

## Features

- 🤖 Multiple LLM backends (Ollama, OpenAI, Claude, Groq)
- 📎 Context files support
- 💬 Clean chat interface
- 🔄 Async responses

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{
  "nikojunttila/ai-chatter",
  config = function()
    require("ollama-chat").setup({
      backend = "ollama", -- or "openai", "anthropic", "groq"
      ollama = {
        model = "gemma2:2b",
        url = "http://127.0.0.1:11434/api/chat",
      },
      groq = {
        model = "llama-3.3-70b-versatile",
        api_key = os.getenv("GROQ_API_KEY"),
      },
      -- Add other backend configs as needed
    })
  end,
}
```

## Usage

- `:OllamaChat` - Open chat window
- `:OllamaChatContext` - Toggle context file for current buffer
- In chat: Type message and press Enter
- `q` to quit chat window

## Configuration

See `lua/ollama-chat/init.lua` for all configuration options.

## Requirements

- Neovim >= 0.7.0
- curl
