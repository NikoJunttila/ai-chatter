# AI Chatter for Neovim

Chat with LLMs directly in Neovim with support for multiple backends (Ollama, OpenAI, Anthropic, Groq).

## ✨ Features

- 🤖 **Multiple LLM backends** - Ollama (local), OpenAI, Claude, Groq
- 📎 **Context files support** - Add any file as context for your conversation
- 💬 **Clean chat interface** - Simple and intuitive UI
- 🔄 **Async responses** - Non-blocking API calls
- 🆓 **Free tier support** - Works with Groq's free API tier

## 📦 Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "nikojunttila/ai-chatter",
  lazy = false,
  config = function()
    require("ai-chatter").setup({
      backend = "groq", -- Choose: "ollama", "openai", "anthropic", "groq"
      
      -- Groq config (free tier available!)
      groq = {
        api_key = os.getenv("GROQ_API_KEY"),
        model = "llama-3.3-70b-versatile",
      },
      
      -- Ollama config (runs locally)
      ollama = {
        model = "gemma2:2b",
        url = "http://127.0.0.1:11434/api/chat",
      },
      
      -- OpenAI config
      openai = {
        api_key = os.getenv("OPENAI_API_KEY"),
        model = "gpt-4o-mini",
      },
      
      -- Anthropic config
      anthropic = {
        api_key = os.getenv("ANTHROPIC_API_KEY"),
        model = "claude-3-5-haiku-20241022",
        max_tokens = 4096,
      },
    })
    
    -- Optional keybindings
    vim.keymap.set("n", "<leader>ac", function()
      require("ai-chatter").open_chat()
    end, { desc = "Open AI Chat" })
    
    vim.keymap.set("n", "<leader>ax", function()
      require("ai-chatter").toggle_context_file()
    end, { desc = "Toggle current buffer as context" })
  end,
}
```

## 🚀 Usage

### Commands

- `:AIChat` - Open the chat window
- `:AIChatContext` - Toggle current buffer as context file

### In Chat Window

- **Type your message** and press `Enter` to send
- **`q`** - Quit chat window
- **`i`** - Enter insert mode to type
- **`Esc`** - Return to normal mode

### Context Files

Context files allow you to add reference material to your conversation. The AI will have access to the content of these files when responding.

1. Open a file you want to add as context
2. Run `:AIChatContext` or use your keybinding
3. The file is now included in all chat messages (shown at top of chat)
4. Toggle the command again to remove the file from context

## ⚙️ Configuration

### Backend Options

#### Ollama (Local)
Requires Ollama to be installed and running locally.
```lua
ollama = {
  model = "gemma2:2b",  -- or "llama3.2", "mistral", etc.
  url = "http://127.0.0.1:11434/api/chat",
}
```

#### Groq (Free Tier Available!)
Get your free API key at [console.groq.com](https://console.groq.com)
```lua
groq = {
  api_key = os.getenv("GROQ_API_KEY"),
  model = "llama-3.3-70b-versatile",  -- or "mixtral-8x7b-32768", etc.
}
```

#### OpenAI
```lua
openai = {
  api_key = os.getenv("OPENAI_API_KEY"),
  model = "gpt-4o-mini",  -- or "gpt-4o", "gpt-3.5-turbo"
}
```

#### Anthropic (Claude)
```lua
anthropic = {
  api_key = os.getenv("ANTHROPIC_API_KEY"),
  model = "claude-3-5-haiku-20241022",  -- or "claude-3-5-sonnet-20241022"
  max_tokens = 4096,
}
```

### Setting API Keys

Add to your shell config (`~/.bashrc`, `~/.zshrc`, etc.):
```bash
export GROQ_API_KEY="your-api-key-here"
export OPENAI_API_KEY="your-api-key-here"
export ANTHROPIC_API_KEY="your-api-key-here"
```

## 📋 Requirements

- Neovim >= 0.7.0
- `curl` (for API requests)
- An API key for your chosen backend (except Ollama which runs locally)
