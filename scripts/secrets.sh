#!/usr/bin/env bash
# Restaura (pull) ou envia (push) os segredos de secrets/manifest.txt usando o
# Bitwarden CLI. Cada item é uma nota segura cujo campo "Notas" guarda o arquivo.
#
# Uso: scripts/secrets.sh status|pull|push [--dry-run]
# Servidor próprio: BW_SERVER=https://vault.exemplo.com scripts/secrets.sh pull
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest="$repo_dir/secrets/manifest.txt"
backup_root="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
# Limite do campo de notas do Bitwarden (texto cifrado).
max_note_bytes=7000
action=${1:-}
dry_run=false
[[ "${2:-}" == --dry-run ]] && dry_run=true

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

usage() {
  sed -n '2,6s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"
}

case "$action" in
  status|pull|push) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

for command_name in bw jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s não encontrado. Rode ./install.sh --packages primeiro.\n' "$command_name" >&2
    exit 1
  fi
done

read_manifest() {
  sed 's/#.*//; /^[[:space:]]*$/d' "$manifest"
}

expand_home() {
  printf '%s' "${1/#\~/$HOME}"
}

ensure_session() {
  local state
  state=$(bw status | jq -r .status)
  if [[ "$state" == unauthenticated ]]; then
    [[ -n "${BW_SERVER:-}" ]] && bw config server "$BW_SERVER" >/dev/null
    printf 'Entrando no Bitwarden...\n' >&2
    BW_SESSION=$(bw login --raw)
  elif [[ "$state" == locked ]] || [[ -z "${BW_SESSION:-}" ]]; then
    printf 'Desbloqueando o cofre...\n' >&2
    BW_SESSION=$(bw unlock --raw)
  fi
  export BW_SESSION
  bw sync >/dev/null
}

# Todos os itens dotfiles/* numa única chamada; os segredos ficam só em memória.
load_items() {
  items=$(bw list items --search dotfiles/)
}

item_field() {
  jq -r --arg name "$1" --arg field "$2" \
    'map(select(.name == $name)) | if length == 0 then empty else (.[0][$field] // empty) end' <<<"$items"
}

pull() {
  local name target mode path current
  while read -r name target mode; do
    path=$(expand_home "$target")
    if [[ -z "$(item_field "$name" id)" ]]; then
      printf 'ausente  %s (sem item no cofre)\n' "$name"
      continue
    fi
    current=$(jq -j --arg name "$name" 'map(select(.name == $name))[0].notes // ""' <<<"$items")
    if [[ -f "$path" ]] && [[ "$(cat -- "$path")" == "$current" ]]; then
      printf 'ok       %s\n' "$target"
      continue
    fi
    if "$dry_run"; then
      printf 'gravaria %s\n' "$target"
      continue
    fi
    mkdir -p -- "$(dirname -- "$path")"
    [[ "$path" == "$HOME/.ssh/"* ]] && chmod 700 "$HOME/.ssh"
    if [[ -e "$path" ]]; then
      local relative=${path#"$HOME/"}
      mkdir -p -- "$backup_root/$(dirname -- "$relative")"
      mv -- "$path" "$backup_root/$relative"
      printf 'backup   %s\n' "$target"
    fi
    (umask 077; printf '%s\n' "$current" > "$path")
    chmod "$mode" "$path"
    printf 'gravado  %s\n' "$target"
  done < <(read_manifest)
  [[ -d "$backup_root" ]] && printf 'Backup: %s\n' "$backup_root"
  return 0
}

push() {
  local name target mode path size id template
  while read -r name target mode; do
    path=$(expand_home "$target")
    if [[ ! -f "$path" ]]; then
      printf 'ausente  %s (arquivo local não existe)\n' "$target"
      continue
    fi
    size=$(wc -c < "$path")
    if (( size > max_note_bytes )); then
      printf 'grande   %s (%d bytes; acima do limite de notas, envie como anexo)\n' "$target" "$size" >&2
      continue
    fi
    id=$(item_field "$name" id)
    if [[ -n "$id" ]] && [[ "$(item_field "$name" notes)" == "$(cat -- "$path")" ]]; then
      printf 'ok       %s\n' "$name"
      continue
    fi
    if "$dry_run"; then
      printf '%s %s\n' "$([[ -n "$id" ]] && echo atualizaria || echo criaria)" "$name"
      continue
    fi
    if [[ -n "$id" ]]; then
      bw get item "$id" \
        | jq --rawfile notes "$path" '.notes = ($notes | rtrimstr("\n"))' \
        | bw encode | bw edit item "$id" >/dev/null
      printf 'atualiz. %s\n' "$name"
    else
      template=$(bw get template item)
      jq --arg name "$name" --rawfile notes "$path" \
        '.type = 2 | .secureNote = {type: 0} | .name = $name
         | .notes = ($notes | rtrimstr("\n")) | .login = null | .fields = []' <<<"$template" \
        | bw encode | bw create item >/dev/null
      printf 'criado   %s\n' "$name"
    fi
  done < <(read_manifest)
}

status() {
  local name target mode path in_vault
  printf '%-30s %-8s %s\n' ITEM COFRE LOCAL
  while read -r name target mode; do
    path=$(expand_home "$target")
    in_vault=$([[ -n "$(item_field "$name" id)" ]] && echo sim || echo falta)
    printf '%-30s %-8s %s\n' "$name" "$in_vault" "$([[ -f "$path" ]] && echo "$target" || echo ausente)"
  done < <(read_manifest)
}

ensure_session
load_items
"$action"
