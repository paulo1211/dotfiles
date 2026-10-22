#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

if ! command -v mise >/dev/null 2>&1; then
  printf 'Instalando mise em ~/.local/bin...\n'
  curl -fsSL https://mise.run | sh
fi

# Instala as ferramentas de ~/.config/mise/config.toml (link para config/mise/).
cd "$HOME"
MISE_YES=1 mise install
mise reshim
mise ls --current
