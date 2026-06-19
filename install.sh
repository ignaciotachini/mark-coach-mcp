#!/usr/bin/env bash
set -euo pipefail

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

REPO_URL="https://github.com/BlueNacho/mark-coach-mcp.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/mark-coach-mcp}"

printf "\n${BOLD}mark-coach-mcp — one-line installer${NC}\n"
printf "Destino: %s\n\n" "$INSTALL_DIR"

if ! command -v git >/dev/null 2>&1; then
  printf "${YELLOW}git no esta instalado.${NC} En macOS: instalá Xcode Command Line Tools con: ${BOLD}xcode-select --install${NC}\n" >&2
  exit 1
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  printf "${YELLOW}Repo ya existe en %s — haciendo git pull...${NC}\n" "$INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --rebase --autostash
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
chmod +x setup.sh
./setup.sh

printf "\n${GREEN}${BOLD}Instalación completa.${NC}\n"
printf "Repo en: ${BOLD}%s${NC}\n\n" "$INSTALL_DIR"
