# LLM Chat MCP Server

OpenAI-compatible API bridge for adversary analyst in research-loop. Enables cross-model verification by calling external LLM APIs (DeepSeek, GPT, Kimi, etc.) through Claude Code's MCP protocol.

## Installation

1. Install the required dependency:

```bash
pip install httpx
```

2. Register the MCP server in your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "llm-chat": {
      "command": "python3",
      "args": ["/absolute/path/to/research-loop/mcp-servers/llm-chat/server.py"],
      "env": {
        "LLM_API_KEY": "your-api-key-here",
        "LLM_BASE_URL": "https://api.deepseek.com/v1",
        "LLM_MODEL": "deepseek-chat",
        "LLM_SERVER_NAME": "llm-chat"
      }
    }
  }
}
```

Replace `/absolute/path/to/research-loop` with the actual path to this repository.

## Supported Providers

Any OpenAI-compatible API endpoint is supported:

- OpenAI (gpt-4o, gpt-3.5-turbo)
- DeepSeek (deepseek-chat)
- Kimi / Moonshot (moonshot-v1-32k)
- Any other OpenAI-compatible endpoint

## License

Copied from [wanshuiyin/Auto-claude-code-research-in-sleep](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep) (MIT License).

