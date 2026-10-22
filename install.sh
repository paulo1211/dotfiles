#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
backup_root="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
dry_run=false
install_packages=false
restore_secrets=false

usage() {
  cat <<'EOF'
Uso: ./install.sh [--dry-run] [--packages] [--secrets]

  --dry-run   mostra as alterações sem executá-las
  --packages  instala pacotes da distribuição, runtimes (mise), manifestos
              e extensões do VS Code
  --secrets   restaura chaves SSH e credenciais do Bitwarden (scripts/secrets.sh)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --packages) install_packages=true ;;
    --secrets) restore_secrets=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Argumento desconhecido: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

run() {
  if "$dry_run"; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

link_file() {
  local source=$1 target=$2
  local target_dir
  target_dir=$(dirname -- "$target")

  if [[ -L "$target" ]] && [[ "$(readlink -f -- "$target")" == "$(readlink -f -- "$source")" ]]; then
    printf 'ok       %s\n' "$target"
    return
  fi

  run mkdir -p -- "$target_dir"
  if [[ -e "$target" || -L "$target" ]]; then
    local relative=${target#"${HOME}/"}
    run mkdir -p -- "$backup_root/$(dirname -- "$relative")"
    run mv -- "$target" "$backup_root/$relative"
    printf 'backup   %s\n' "$target"
  fi
  run ln -s -- "$source" "$target"
  printf 'link     %s -> %s\n' "$target" "$source"
}

declare -a links=(
  "home/bashrc:${HOME}/.bashrc"
  "home/profile:${HOME}/.profile"
  "home/gitconfig:${HOME}/.gitconfig"
  "home/gitconfig.local.example:${HOME}/.gitconfig.local.example"
  "config/git/ignore:${HOME}/.config/git/ignore"
  "config/Code/User/settings.json:${HOME}/.config/Code/User/settings.json"
  "config/zed/settings.json:${HOME}/.config/zed/settings.json"
  "config/flameshot/flameshot.ini:${HOME}/.config/flameshot/flameshot.ini"
  "config/htop/htoprc:${HOME}/.config/htop/htoprc"
  "config/mise/config.toml:${HOME}/.config/mise/config.toml"
)

for entry in "${links[@]}"; do
  link_file "$repo_dir/${entry%%:*}" "${entry#*:}"
done

if "$install_packages"; then
  if "$dry_run"; then
    printf '+ %q --all\n' "$repo_dir/scripts/packages.sh"
  else
    "$repo_dir/scripts/packages.sh" --all
  fi
fi

if "$restore_secrets"; then
  if "$dry_run"; then
    "$repo_dir/scripts/secrets.sh" pull --dry-run
  else
    "$repo_dir/scripts/secrets.sh" pull
  fi
fi

printf '\nConcluído. Abra um novo shell ou execute: source ~/.bashrc\n'
if [[ -d "$backup_root" ]]; then
  printf 'Backup: %s\n' "$backup_root"
fi
