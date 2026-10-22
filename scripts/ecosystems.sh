#!/usr/bin/env bash
set -uo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
failures=0

# Usa os runtimes instalados pelo mise mesmo fora de um shell interativo.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/go/bin:$PATH"

skipped() {
  [[ ",${DOTFILES_SKIP:-}," == *",$1,"* ]]
}

warn() {
  printf 'aviso: %s\n' "$*" >&2
  failures=$((failures + 1))
}

read_manifest() {
  sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$1"
}

if skipped snap; then
  :
elif command -v snap >/dev/null 2>&1; then
  while read -r package mode; do
    args=(install "$package")
    [[ "${mode:-}" == classic ]] && args+=(--classic)
    sudo snap "${args[@]}" || warn "não foi possível instalar o snap $package"
  done < <(read_manifest "$repo_dir/packages/snap.txt")
else
  warn 'Snap não está disponível; packages/snap.txt foi ignorado'
fi

if skipped flatpak; then
  :
elif command -v flatpak >/dev/null 2>&1; then
  if ! flatpak remote-list --columns=name | grep -qx flathub; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
      || warn 'não foi possível adicionar o Flathub'
  fi
  while IFS= read -r application; do
    flatpak install --noninteractive -y flathub "$application" \
      || warn "não foi possível instalar o Flatpak $application"
  done < <(read_manifest "$repo_dir/packages/flatpak.txt")
else
  warn 'Flatpak não está disponível; packages/flatpak.txt foi ignorado'
fi

if command -v npm >/dev/null 2>&1; then
  while IFS= read -r package; do
    npm install --global "$package" || warn "não foi possível instalar o pacote npm $package"
  done < <(read_manifest "$repo_dir/packages/npm-global.txt")
  command -v mise >/dev/null 2>&1 && mise reshim
else
  warn 'npm não está disponível; packages/npm-global.txt foi ignorado'
fi

if command -v go >/dev/null 2>&1; then
  while IFS= read -r module; do
    go install "$module" || warn "não foi possível instalar o módulo Go $module"
  done < <(read_manifest "$repo_dir/packages/go-tools.txt")
else
  warn 'Go não está disponível; packages/go-tools.txt foi ignorado'
fi

if command -v uv >/dev/null 2>&1; then
  while IFS= read -r package; do
    uv tool install "$package" || warn "não foi possível instalar a ferramenta Python $package com uv"
  done < <(read_manifest "$repo_dir/packages/python-tools.txt")
elif command -v pipx >/dev/null 2>&1; then
  while IFS= read -r package; do
    pipx install "$package" || warn "não foi possível instalar a ferramenta Python $package com pipx"
  done < <(read_manifest "$repo_dir/packages/python-tools.txt")
else
  warn 'uv/pipx não está disponível; packages/python-tools.txt foi ignorado'
fi

if (( failures > 0 )); then
  printf '\nFinalizado com %d aviso(s). Consulte packages/external-tools.md para itens manuais.\n' "$failures" >&2
fi
