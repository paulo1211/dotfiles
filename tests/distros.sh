#!/usr/bin/env bash
# Roda ./install.sh --packages em contêineres de cada família suportada.
# Uso: tests/distros.sh [imagem...]     (padrão: todas as imagens abaixo)
# Logs em tests/logs/<imagem>.log. GITHUB_TOKEN, se definido, evita o limite
# de requisições da API do GitHub ao baixar ferramentas pelo mise.
set -Euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
log_dir="$repo_dir/tests/logs"
mkdir -p "$log_dir"

images=("$@")
if (( ${#images[@]} == 0 )); then
  images=(
    debian:stable
    ubuntu:24.04
    fedora:latest
    rockylinux/rockylinux:9
    archlinux:latest
    opensuse/tumbleweed
    opensuse/leap:15.6
  )
fi

# Snap e Flatpak dependem de systemd/D-Bus, ausentes em contêineres.
skip=${DOTFILES_SKIP:-snap,flatpak,vscode}
expected="git curl rg fzf fd shellcheck jq tmux vim mise node npm go uv kubectl helm terraform golangci-lint aws act eksctl bw java hey gopls gemini awx"

pids=()
for image in "${images[@]}"; do
  log="$log_dir/${image//[\/:]/_}.log"
  printf 'iniciando %-26s -> %s\n' "$image" "${log#"$repo_dir/"}"
  docker run --rm \
    -v "$repo_dir:/src:ro" \
    -e DOTFILES_SKIP="$skip" \
    -e EXPECTED_COMMANDS="$expected" \
    -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
    "$image" bash /src/tests/in-container.sh >"$log" 2>&1 &
  pids+=($!)
done

status=0
for i in "${!images[@]}"; do
  if wait "${pids[$i]}"; then
    printf 'OK      %s\n' "${images[$i]}"
  else
    printf 'FALHOU  %s\n' "${images[$i]}"
    status=1
  fi
done
exit "$status"
