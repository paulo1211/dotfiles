#!/usr/bin/env bash
set -u

printf 'Sistema: '
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf '%s %s\n' "${NAME:-Linux}" "${VERSION_ID:-}"
else
  uname -srm
fi
printf 'Arquitetura: %s\n' "$(uname -m)"
printf 'Família detectada: '
"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/packages.sh" --detect | sed -n '1s/^Distribuição detectada: //p'

printf '\nComandos:\n'
for command_name in mise bw git curl vim rg fd fdfind fzf tmux shellcheck brew code zed gh docker kubectl helm terraform ansible ansible-lint aws sam teleport tsh uv go gopls golangci-lint eksctl act node npm gemini awx java mvn vagrant rclone ffmpeg nmap; do
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '  ok       %-12s %s\n' "$command_name" "$(command -v "$command_name")"
  else
    printf '  ausente  %s\n' "$command_name"
  fi
done

printf '\nLinks:\n'
for target in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.gitconfig" \
  "$HOME/.config/git/ignore" "$HOME/.config/Code/User/settings.json" \
  "$HOME/.config/zed/settings.json" "$HOME/.config/flameshot/flameshot.ini" \
  "$HOME/.config/htop/htoprc" "$HOME/.config/mise/config.toml"; do
  if [[ -L "$target" ]]; then
    printf '  link     %s -> %s\n' "$target" "$(readlink -- "$target")"
  elif [[ -e "$target" ]]; then
    printf '  arquivo  %s\n' "$target"
  else
    printf '  ausente  %s\n' "$target"
  fi
done

printf '\nCredenciais (presença apenas):\n'
for path in "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.aws" "$HOME/.kube"; do
  [[ -e "$path" ]] && printf '  presente %s (não versionado)\n' "$path" || printf '  ausente  %s\n' "$path"
done
