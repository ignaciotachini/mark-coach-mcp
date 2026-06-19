#!/usr/bin/env bash
set -euo pipefail

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
DIM=$'\033[2m'
NC=$'\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="$(uname -s)"

step()  { printf "\n${BOLD}==>${NC} %s\n" "$1"; }
ok()    { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}!${NC} %s\n" "$1"; }
err()   { printf "  ${RED}✗${NC} %s\n" "$1" >&2; }
info()  { printf "  ${DIM}%s${NC}\n" "$1"; }

is_interactive() { [ -t 0 ] && [ -t 1 ]; }

ask_yes_no() {
  local prompt="$1" default="${2:-y}" answer
  if ! is_interactive; then
    [ "$default" = "y" ] && return 0 || return 1
  fi
  read -r -p "  $prompt [$( [ "$default" = "y" ] && echo "Y/n" || echo "y/N" )]: " answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[YySs]$ ]]
}

# ---------------------------------------------------------------------------

printf "\n${BOLD}mark-coach-mcp setup${NC}\n"
printf "${DIM}Repo: %s${NC}\n" "$REPO_DIR"

# ---------- Dependencies ---------------------------------------------------

step "Verificando dependencias"

if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
  warn "uv no instalado — instalando..."
  # uv installer tira errores cosmeticos al tocar shell rc — el binario igual queda OK
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || true
fi
export PATH="$HOME/.local/bin:$PATH"
UV_BIN="$(command -v uv || echo "$HOME/.local/bin/uv")"
if [ ! -x "$UV_BIN" ]; then
  err "No se pudo instalar uv. Instalalo a mano: https://docs.astral.sh/uv/getting-started/installation/"
  exit 1
fi
ok "uv → $UV_BIN"

if ! command -v yt-dlp >/dev/null 2>&1; then
  warn "yt-dlp no instalado — instalando..."
  if command -v brew >/dev/null 2>&1; then
    brew install yt-dlp >/dev/null
  else
    "$UV_BIN" tool install yt-dlp >/dev/null
  fi
fi
ok "yt-dlp → $(command -v yt-dlp)"

# ---------- Python deps ----------------------------------------------------

step "Instalando dependencias Python"
cd "$REPO_DIR"
"$UV_BIN" sync --quiet
ok "Entorno virtual sincronizado"

# ---------- Transcripts ----------------------------------------------------

step "Transcripts"
TRANSCRIPTS_DIR="$REPO_DIR/transcripts"
mkdir -p "$TRANSCRIPTS_DIR"
VTT_COUNT="$(find "$TRANSCRIPTS_DIR" -maxdepth 2 -name '*.vtt' 2>/dev/null | wc -l | tr -d ' ')"

if [ "$VTT_COUNT" -eq 0 ]; then
  info "No hay transcripts en $TRANSCRIPTS_DIR"
  if ask_yes_no "¿Descargar transcripts del canal Mark Builds Brands ahora?"; then
    info "Descargando transcripts (esto puede tardar varios minutos)..."
    yt-dlp \
      --write-auto-sub \
      --sub-lang en \
      --skip-download \
      --output "$TRANSCRIPTS_DIR/%(title)s [%(id)s].%(ext)s" \
      "https://www.youtube.com/@markbuildsbrands/videos" \
      > /dev/null 2>&1 || warn "yt-dlp terminó con avisos — continuamos"
    VTT_COUNT="$(find "$TRANSCRIPTS_DIR" -maxdepth 2 -name '*.vtt' 2>/dev/null | wc -l | tr -d ' ')"
    ok "$VTT_COUNT archivos .vtt descargados"
  else
    warn "Salteamos la descarga. Copiá tus .vtt a $TRANSCRIPTS_DIR y volvé a correr ./setup.sh"
  fi
else
  ok "$VTT_COUNT archivos .vtt encontrados"
fi

# ---------- Indexing -------------------------------------------------------

if [ "$VTT_COUNT" -gt 0 ]; then
  step "Indexando transcripts en la base de conocimiento"
  "$UV_BIN" run src/indexer.py "$TRANSCRIPTS_DIR" | tail -3
fi

# ---------- Claude integration --------------------------------------------

step "Configurando Claude"

CLAUDE_CODE_FOUND=false
CLAUDE_DESKTOP_FOUND=false

if command -v claude >/dev/null 2>&1; then
  CLAUDE_CODE_FOUND=true
  info "Claude Code detectado"

  SKILL_DST="$HOME/.claude/skills/mark-coach"
  mkdir -p "$SKILL_DST"
  cp "$REPO_DIR/skills/mark-coach.md" "$SKILL_DST/SKILL.md"
  ok "Skill instalado en ~/.claude/skills/mark-coach/SKILL.md"

  if claude mcp get mark-coach >/dev/null 2>&1; then
    claude mcp remove -s user mark-coach >/dev/null 2>&1 || true
  fi
  claude mcp add -s user mark-coach -- "$UV_BIN" --directory "$REPO_DIR" run src/server.py >/dev/null
  ok "MCP registrado en Claude Code (scope: user)"
else
  info "Claude Code no detectado — salteamos su configuración"
fi

if [ "$PLATFORM" = "Darwin" ]; then
  CLAUDE_DESKTOP_DIR="$HOME/Library/Application Support/Claude"
elif [ "$PLATFORM" = "Linux" ]; then
  CLAUDE_DESKTOP_DIR="$HOME/.config/Claude"
else
  CLAUDE_DESKTOP_DIR=""
fi

CLAUDE_DESKTOP_CONFIG="$CLAUDE_DESKTOP_DIR/claude_desktop_config.json"

if [ -n "$CLAUDE_DESKTOP_DIR" ] && [ -d "$CLAUDE_DESKTOP_DIR" ]; then
  CLAUDE_DESKTOP_FOUND=true
  info "Claude Desktop detectado"
  [ -f "$CLAUDE_DESKTOP_CONFIG" ] || echo '{}' > "$CLAUDE_DESKTOP_CONFIG"
  "$UV_BIN" run python - "$CLAUDE_DESKTOP_CONFIG" "$UV_BIN" "$REPO_DIR" <<'PYEOF'
import json
import sys
from pathlib import Path

config_path, uv_bin, repo_dir = sys.argv[1], sys.argv[2], sys.argv[3]
p = Path(config_path)
try:
    config = json.loads(p.read_text() or "{}")
except json.JSONDecodeError:
    print("  ! claude_desktop_config.json invalido — sobreescribiendo")
    config = {}

config.setdefault("mcpServers", {})
config["mcpServers"]["mark-coach"] = {
    "command": uv_bin,
    "args": ["--directory", repo_dir, "run", "src/server.py"],
}
p.write_text(json.dumps(config, indent=2))
print("  ✓ MCP agregado a claude_desktop_config.json")
PYEOF
else
  info "Claude Desktop no detectado — salteamos su configuración"
fi

# ---------- Summary --------------------------------------------------------

printf "\n${BOLD}${GREEN}✓ Setup completo${NC}\n\n"
printf "${BOLD}Próximos pasos:${NC}\n"

if $CLAUDE_CODE_FOUND; then
  printf "  • ${BOLD}Claude Code:${NC} reiniciá la sesión y usá ${YELLOW}/mark-coach${NC}\n"
fi
if $CLAUDE_DESKTOP_FOUND; then
  printf "  • ${BOLD}Claude Desktop:${NC} cerralo (cmd+Q en macOS) y abrilo de nuevo\n"
fi
if ! $CLAUDE_CODE_FOUND && ! $CLAUDE_DESKTOP_FOUND; then
  warn "No detectamos Claude Code ni Claude Desktop instalados."
  info "Instalá alguno y corré este script de nuevo."
fi

printf "\n${DIM}Para agregar más videos en el futuro: copiá los .vtt a transcripts/ y corré ./setup.sh${NC}\n\n"
