#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

copy_if_present() {
  local source=$1 destination=$2
  if [[ -f "$source" ]]; then
    if [[ -e "$destination" ]] && [[ "$(readlink -f -- "$source")" == "$(readlink -f -- "$destination")" ]]; then
      printf 'já gerenciado %s\n' "$source"
      return
    fi
    mkdir -p -- "$(dirname -- "$destination")"
    cp --dereference -- "$source" "$destination"
    printf 'capturado %s\n' "$source"
  fi
}

copy_if_present "$HOME/.bashrc" "$repo_dir/home/bashrc"
copy_if_present "$HOME/.profile" "$repo_dir/home/profile"
copy_if_present "$HOME/.gitconfig" "$repo_dir/home/gitconfig"
copy_if_present "$HOME/.config/git/ignore" "$repo_dir/config/git/ignore"
copy_if_present "$HOME/.config/Code/User/settings.json" "$repo_dir/config/Code/User/settings.json"
copy_if_present "$HOME/.config/zed/settings.json" "$repo_dir/config/zed/settings.json"
copy_if_present "$HOME/.config/flameshot/flameshot.ini" "$repo_dir/config/flameshot/flameshot.ini"
copy_if_present "$HOME/.config/htop/htoprc" "$repo_dir/config/htop/htoprc"

if command -v code >/dev/null 2>&1; then
  code --list-extensions | sort -u > "$repo_dir/packages/vscode-extensions.txt"
fi

printf '\nRevise as alterações antes de fazer commit:\n  git -C %q diff\n' "$repo_dir"
