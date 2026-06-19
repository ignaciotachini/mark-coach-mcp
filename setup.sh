#!/bin/bash
set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${BOLD}mark-coach-mcp setup${NC}"
echo "================================="
echo ""

# 1. uv
if ! command -v uv &>/dev/null; then
  echo -e "${YELLOW}Instalando uv...${NC}"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.cargo/bin:$PATH"
fi
echo -e "${GREEN}✓ uv$(NC) $(uv --version)"

# 2. yt-dlp
if ! command -v yt-dlp &>/dev/null; then
  echo -e "${YELLOW}Instalando yt-dlp...${NC}"
  if command -v brew &>/dev/null; then
    brew install yt-dlp
  else
    uv tool install yt-dlp
  fi
fi
echo -e "${GREEN}✓ yt-dlp${NC}"

# 3. Dependencias Python
echo ""
echo -e "${BOLD}Instalando dependencias Python...${NC}"
cd "$REPO_DIR"
uv sync
echo -e "${GREEN}✓ Dependencias instaladas${NC}"

# 4. Transcripts
echo ""
echo -e "${BOLD}Transcripts${NC}"

TRANSCRIPTS_DIR="$REPO_DIR/transcripts"
mkdir -p "$TRANSCRIPTS_DIR"

if [ -z "$(ls -A "$TRANSCRIPTS_DIR"/*.vtt 2>/dev/null)" ]; then
  echo "No se encontraron .vtt en $TRANSCRIPTS_DIR"
  echo ""
  echo "Opciones:"
  echo "  a) Descargar ahora del canal de Mark Builds Brands"
  echo "  b) Copiar tus .vtt manualmente a $TRANSCRIPTS_DIR y volver a correr setup.sh"
  echo ""
  read -p "¿Descargar ahora? (s/n): " answer
  if [[ "$answer" =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Descargando transcripts... (puede tardar varios minutos)${NC}"
    yt-dlp --write-auto-sub --sub-lang en --skip-download \
      --output "$TRANSCRIPTS_DIR/%(title)s [%(id)s].%(ext)s" \
      "https://www.youtube.com/@markbuildsbrands/videos"
    echo -e "${GREEN}✓ Transcripts descargados${NC}"
  else
    echo "Copiá tus .vtt a $TRANSCRIPTS_DIR y corré ./setup.sh de nuevo."
    exit 0
  fi
else
  VTT_COUNT=$(ls "$TRANSCRIPTS_DIR"/*.vtt 2>/dev/null | wc -l | tr -d ' ')
  echo -e "${GREEN}✓ $VTT_COUNT archivos .vtt encontrados${NC}"
fi

# 5. Indexar
echo ""
echo -e "${BOLD}Indexando transcripts en la base de conocimiento...${NC}"
uv run src/indexer.py "$TRANSCRIPTS_DIR"

# 6. Config de Claude
CLAUDE_CONFIG="$HOME/.claude.json"
MCP_CONFIG=$(cat <<EOF

  "mark-coach": {
    "command": "uv",
    "args": ["run", "src/server.py"],
    "cwd": "$REPO_DIR"
  }
EOF
)

echo ""
echo -e "${GREEN}${BOLD}✓ Setup completo!${NC}"
echo ""
echo "================================="
echo -e "${BOLD}Paso final: conectar a Claude${NC}"
echo "================================="
echo ""
echo "Agregá esto a tu MCP config de Claude Code:"
echo ""
echo -e "${YELLOW}claude mcp add mark-coach -- uv --directory \"$REPO_DIR\" run src/server.py${NC}"
echo ""
echo "O manualmente en ~/.claude.json / claude_desktop_config.json:"
echo '{
  "mcpServers": {'"$MCP_CONFIG"'
  }
}'
echo ""
