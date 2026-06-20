# mark-coach-mcp

Local MCP server that turns [Mark Builds Brands'](https://www.youtube.com/@markbuildsbrands) YouTube knowledge into an AI coaching assistant for ecommerce and Facebook Ads.

Ask Claude to analyze your Ads Manager screenshots, debug campaigns, or get strategic advice — and it'll respond using Mark's actual frameworks, vocabulary, and mental models from his 100+ videos.

## How it works

1. Downloads transcripts from Mark's YouTube channel
2. Indexes them locally into a vector database (ChromaDB)
3. Exposes a `search_mark_knowledge` tool via MCP
4. A Claude skill activates the persona and queries the knowledge base

All data stays on your machine. No API keys required.

## Install (one line)

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/BlueNacho/mark-coach-mcp/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/BlueNacho/mark-coach-mcp/main/install.ps1 | iex
```

That's it. The installer will:

1. Clone the repo to `~/mark-coach-mcp` (or `%USERPROFILE%\mark-coach-mcp` on Windows)
2. Install `uv` (Python package manager) if needed
3. Install `yt-dlp` if needed
4. Install Python dependencies
5. Download Mark's transcripts (~100 videos, a few minutes)
6. Index everything into a local vector DB
7. **Auto-detect** Claude Code and/or Claude Desktop on your machine and configure both
8. Install the `mark-coach` skill globally for Claude Code

After it finishes, restart Claude Desktop / Claude Code and start using `/mark-coach`.

> **Pick a different install dir?**
> macOS/Linux: `INSTALL_DIR=~/projects/mark-coach-mcp curl -fsSL ... | bash`
> Windows: `$env:INSTALL_DIR = "D:\projects\mark-coach-mcp"; iwr -useb ... | iex`

## Manual install

### macOS / Linux

```bash
git clone https://github.com/BlueNacho/mark-coach-mcp ~/mark-coach-mcp
cd ~/mark-coach-mcp
./setup.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/BlueNacho/mark-coach-mcp $env:USERPROFILE\mark-coach-mcp
cd $env:USERPROFILE\mark-coach-mcp
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

> If you prefer **WSL** on Windows, follow the macOS/Linux instructions inside your WSL terminal — the bash scripts work as-is.

## Using it

### Claude Code

The skill is installed globally. Just open Claude Code and type:

```
/mark-coach
```

Or describe an ecommerce / Facebook Ads question and the skill activates automatically.

### Claude Desktop

After restart, the `search_mark_knowledge` tool is available. To get the persona/voice, create a **Project** in Claude.ai (or Cowork Space) and paste the contents of `skills/mark-coach.md` into the project's Custom Instructions.

## Adding new videos

When Mark publishes new content:

```bash
cd ~/mark-coach-mcp
./setup.sh
```

The setup script is idempotent — it re-downloads only new videos and re-indexes only the new ones (existing indexed videos are skipped via `data/processed.txt`).

## Using your own transcripts

If you have your own `.vtt` files (from any creator), drop them into `transcripts/` and run:

```bash
./setup.sh
```

The indexer accepts any YouTube `.vtt` file — it strips timestamps, dedupes, and chunks the text.

## Project structure

```
mark-coach-mcp/
  install.sh         ← one-line bootstrap (clones repo, runs setup.sh)
  setup.sh           ← installs deps, downloads/indexes, wires Claude
  pyproject.toml     ← Python dependencies (managed by uv)
  src/
    indexer.py       ← converts .vtt transcripts → ChromaDB
    server.py        ← MCP server with search_mark_knowledge tool
  skills/
    mark-coach.md    ← Claude skill / persona definition
  transcripts/       ← your .vtt files (gitignored)
  data/              ← ChromaDB vector store (gitignored)
```

## Requirements

- macOS, Linux, or Windows 10/11
- `git`
  - macOS: included with Xcode CLT (`xcode-select --install`)
  - Linux: install via your package manager
  - Windows: https://git-scm.com/download/win
- Claude Code and/or Claude Desktop

Everything else (`uv`, `yt-dlp`, Python deps) is installed automatically.

## Troubleshooting

### MCP says "Failed to connect" after a reboot
The MCP needs the **absolute path** to `uv`. The setup script handles this automatically; if you registered manually, make sure your `claude mcp add` command uses the full path (e.g. `/Users/you/.local/bin/uv` on macOS, `C:\Users\you\.local\bin\uv.exe` on Windows — not just `uv`).

### Windows: "running scripts is disabled on this system"
PowerShell blocks unsigned scripts by default. Run setup with the bypass flag:
```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```
The one-line installer already does this.

### Re-run setup
The setup script is safe to run any number of times. It detects what's already in place and skips it.

```bash
cd ~/mark-coach-mcp && ./setup.sh
```

### Uninstall

**macOS / Linux:**
```bash
claude mcp remove -s user mark-coach 2>/dev/null
rm -rf ~/.claude/skills/mark-coach
rm -rf ~/mark-coach-mcp
```

**Windows (PowerShell):**
```powershell
claude mcp remove -s user mark-coach 2>$null
Remove-Item -Recurse -Force $env:USERPROFILE\.claude\skills\mark-coach
Remove-Item -Recurse -Force $env:USERPROFILE\mark-coach-mcp
```

For Claude Desktop, edit the config file and remove the `mark-coach` entry from `mcpServers`:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
