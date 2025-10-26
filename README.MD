# Ollama Chat - Neovim Plugin

A simple Neovim plugin for chatting with local LLMs via Ollama, with support for adding files as context.

## Prerequisites

- [Ollama](https://ollama.ai/) installed and running
- A model pulled (e.g., `ollama pull gemma2:2b`)
- Neovim 0.11+

## Installation

### Using lazy.nvim

```lua
{
  dir = "~/.config/nvim/lua/ollama-chat",
  config = function()
    require("ollama-chat").setup()
  end,
}
```

### Manual Installation

Copy the plugin files to your Neovim config:

```
~/.config/nvim/lua/ollama-chat/
├── init.lua
├── ui.lua
└── chat.lua
```

Then add to your config:

```lua
require("ollama-chat").setup()
```

## File Structure

```lua
lua/ollama-chat/
├── init.lua   -- Main plugin, commands, state management
├── ui.lua     -- UI rendering and window management
└── chat.lua   -- Ollama API communication, context handling
```

## Configuration

Edit the model in `chat.lua`:

```lua
-- Change this line to use a different model
local json = string.format('{"model":"gemma2:2b","messages":%s,"stream":false}', messages_json)
```

## Usage

### Basic Commands

| Command | Description |
|---------|-------------|
| `:ChatOpen` | Open the chat window |
| `:ChatClose` | Close the chat window |

### In Chat Window

| Key | Mode | Action |
|-----|------|--------|
| `<CR>` | Normal | Send message |
| `<C-s>` | Insert | Send message |
| `q` | Normal | Close chat |
| `<Esc>` | Normal | Close chat |

### Adding Context Files

| Command | Description |
|---------|-------------|
| `:ChatAddFile [path]` | Add a file as context |
| `:ChatAddBuffer` | Add current buffer as context |
| `:ChatListFiles` | List all context files |
| `:ChatRemoveFile [n]` | Remove context file by number |

### Example Workflow

```vim
" 1. Open chat
:ChatOpen

" 2. Add documentation as context
:ChatAddFile ~/projects/mylib/README.md

" 3. Add current code file
:ChatAddBuffer

" 4. Ask questions in the chat
" Type: "How do I use the authenticate() function?"
" Press <CR> to send

" 5. The AI will reference your files in its response

" 6. Remove context when done
:ChatRemoveFile 1
```

## How It Works

1. **Chat Window**: Opens a floating window with markdown rendering
2. **Message History**: Maintains full conversation context
3. **Context Files**: Added files are included in a system message sent with each request
4. **Ollama API**: Uses `/api/chat` endpoint for conversational responses

## Troubleshooting

### "Connection refused" error
- Ensure Ollama is running: `ollama serve`
- Check if model is available: `ollama list`

### "Model not found" error
- Pull the model: `ollama pull gemma2:2b`
- Update model name in `chat.lua`

### Large files causing slowness
- Files are sent with every message
- Keep context files under 100KB for best performance
- Use `:ChatRemoveFile` to clear unneeded context

## Tips

- **Start fresh**: Close and reopen chat to start a new conversation
- **Multiple files**: You can add multiple files for comprehensive context
- **Code reviews**: Add code files and ask for review/explanation
- **Documentation**: Add library docs and ask implementation questions

## License

MIT
