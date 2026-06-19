# mark-coach-mcp

Local MCP server that turns [Mark Builds Brands'](https://www.youtube.com/@markbuildsbrands) YouTube knowledge into an AI coaching assistant for ecommerce and Facebook Ads.

Ask Claude to analyze your Ads Manager screenshots, debug campaigns, or get strategic advice — and it'll respond using Mark's actual frameworks, vocabulary, and mental models from his 100+ videos.

## How it works

1. Downloads transcripts from Mark's YouTube channel
2. Indexes them locally into a vector database (ChromaDB)
3. Exposes a `search_mark_knowledge` tool via MCP
4. A Claude skill activates the persona and queries the knowledge base

All data stays on your machine. No API keys required.

## Quick start

```bash
git clone https://github.com/BlueNacho/mark-coach-mcp
cd mark-coach-mcp
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Install `uv` (Python package manager) if not present
- Install `yt-dlp` if not present
- Install Python dependencies
- Download transcripts from Mark's channel (or use your own)
- Index everything into a local vector DB
- Print the exact command to connect it to Claude

## Connect to Claude Code

After running setup, add the MCP server:

```bash
claude mcp add mark-coach -- uv --directory "/path/to/mark-coach-mcp" run src/server.py
```

Or add manually to `~/.claude.json`:

```json
{
  "mcpServers": {
    "mark-coach": {
      "command": "uv",
      "args": ["run", "src/server.py"],
      "cwd": "/path/to/mark-coach-mcp"
    }
  }
}
```

## Adding new videos

When Mark publishes new content, just run:

```bash
./setup.sh
```

It skips already-indexed videos and only processes new ones.

## Using your own transcripts

If you already have `.vtt` files, copy them to the `transcripts/` folder and run:

```bash
uv run src/indexer.py transcripts/
```

## Using the skill in Claude Code

Copy `skills/mark-coach.md` to your Claude skills directory, then activate with `/mark-coach` in any conversation.

## Project structure

```
mark-coach-mcp/
  setup.sh          ← one-command setup
  pyproject.toml    ← Python dependencies (managed by uv)
  src/
    indexer.py      ← converts .vtt transcripts → ChromaDB
    server.py       ← MCP server with search tool
  skills/
    mark-coach.md   ← Claude skill / persona definition
  transcripts/      ← your .vtt files (gitignored)
  data/             ← ChromaDB vector store (gitignored)
```

## Requirements

- macOS or Linux
- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (installed automatically by setup.sh)
- Claude Code or Claude Desktop
