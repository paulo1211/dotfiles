#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install_extras=false
detect_only=false
failures=()

case "${1:-}" in
  --all) install_extras=true ;;
  --detect) detect_only=true ;;
  "") ;;
  *) printf 'Uso: %s [--all|--detect]\n' "$0" >&2; exit 2 ;;
esac

# Etapas podem ser puladas com DOTFILES_SKIP=distro-extras,runtimes,vscode,...
skipped() {
  [[ ",${DOTFILES_SKIP:-}," == *",$1,"* ]]
}

read_manifest() {
  sed 's/#.*//; /^[[:space:]]*$/d' "$1"
}

distro_id=unknown
distro_like=
distro_version=
os_release_file=${DOTFILES_OS_RELEASE_FILE:-/etc/os-release}
if [[ -r "$os_release_file" ]]; then
  # O arquivo é fornecido pela distribuição e contém apenas atribuições shell.
  # shellcheck source=/dev/null
  source "$os_release_file"
  distro_id=${ID:-unknown}
  distro_like=${ID_LIKE:-}
  distro_version=${VERSION_ID:-}
fi

case "$distro_id" in
  debian|ubuntu|linuxmint|pop) distro_family=debian ;;
  fedora|rhel|centos|rocky|almalinux) distro_family=fedora ;;
  arch|manjaro|endeavouros|garuda) distro_family=arch ;;
  opensuse*|sles|sled) distro_family=opensuse ;;
  *)
    case " $distro_like " in
      *" arch "*) distro_family=arch ;;
      *" suse "*) distro_family=opensuse ;;
      *" debian "*|*" ubuntu "*) distro_family=debian ;;
      *" fedora "*|*" rhel "*) distro_family=fedora ;;
      *)
        if command -v zypper >/dev/null 2>&1; then distro_family=opensuse
        elif command -v pacman >/dev/null 2>&1; then distro_family=arch
        elif command -v apt-get >/dev/null 2>&1; then distro_family=debian
        elif command -v dnf >/dev/null 2>&1; then distro_family=fedora
        else distro_family=unknown
        fi
        ;;
    esac
    ;;
esac

machine_arch=$(uname -m)
printf 'Distribuição detectada: %s (família %s)\n' "$distro_id" "$distro_family"
printf 'Arquitetura detectada: %s\n' "$machine_arch"

if "$detect_only"; then
  exit 0
fi

if [[ "$distro_family" == unknown ]]; then
  printf 'Distribuição não reconhecida. Instale manualmente packages/common.txt.\n' >&2
  exit 1
fi

# Traduz um nome genérico para os pacotes da família usando packages/names.txt.
resolve_package() {
  local generic=$1 column
  case "$distro_family" in
    debian) column=2 ;;
    fedora) column=3 ;;
    arch) column=4 ;;
    opensuse) column=5 ;;
  esac
  # Sem awk: instalações mínimas (ex. openSUSE Tumbleweed) não o trazem.
  local resolved=$generic fields
  while read -ra fields; do
    if [[ "${fields[0]}" == "$generic" ]]; then
      resolved=${fields[column - 1]}
      break
    fi
  done < <(read_manifest "$repo_dir/packages/names.txt")
  [[ "$resolved" == - ]] && return
  tr ',' '\n' <<<"$resolved"
}

pkg_install() {
  case "$distro_family" in
    debian) sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" ;;
    fedora) sudo dnf install -y --allowerasing "$@" ;;
    arch) sudo pacman -S --needed --noconfirm "$@" ;;
    opensuse) sudo zypper --non-interactive install --no-recommends "$@" ;;
  esac
}

# Tenta instalar tudo de uma vez; se falhar, instala um a um e registra as falhas.
install_list() {
  (( $# == 0 )) && return
  pkg_install "$@" && return
  printf 'aviso: instalação em lote falhou; tentando pacote a pacote\n' >&2
  local package
  for package in "$@"; do
    pkg_install "$package" || failures+=("$package")
  done
}

enable_el_repositories() {
  local major=${distro_version%%.*}
  sudo dnf install -y dnf-plugins-core
  if [[ "$distro_id" == rhel ]]; then
    sudo subscription-manager repos --enable "codeready-builder-for-rhel-${major}-${machine_arch}-rpms" \
      || printf 'aviso: não foi possível habilitar o CodeReady Builder\n' >&2
    rpm -q epel-release >/dev/null 2>&1 \
      || sudo dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${major}.noarch.rpm"
  else
    if (( major >= 9 )); then
      sudo dnf config-manager --set-enabled crb
    else
      sudo dnf config-manager --set-enabled powertools
    fi
    sudo dnf install -y epel-release
  fi
}

case "$distro_family" in
  debian) sudo apt-get update ;;
  fedora) [[ "$distro_id" != fedora ]] && enable_el_repositories ;;
  arch) sudo pacman -Syu --noconfirm ;;
  # Um repositório quebrado (ex.: a mídia de instalação que ficou cadastrada)
  # faz o refresh sair com erro mesmo com os demais atualizados.
  opensuse) sudo zypper --non-interactive refresh \
    || printf 'aviso: alguns repositórios não foram atualizados (veja "zypper repos")\n' >&2 ;;
esac

common=()
while IFS= read -r generic; do
  mapfile -t -O "${#common[@]}" common < <(resolve_package "$generic")
done < <(read_manifest "$repo_dir/packages/common.txt")

printf '\nInstalando pacotes comuns...\n'
install_list "${common[@]}"

# Debian e Ubuntu instalam o fd como fdfind.
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

optional_manifest="$repo_dir/packages/distro/$distro_family.txt"
if [[ -f "$optional_manifest" ]] && ! skipped distro-extras; then
  printf '\nInstalando ferramentas adicionais da família %s...\n' "$distro_family"
  while IFS= read -r package; do
    pkg_install "$package" || failures+=("$package")
  done < <(read_manifest "$optional_manifest")
fi

if "$install_extras" && ! skipped runtimes; then
  printf '\nInstalando runtimes com mise...\n'
  "$repo_dir/scripts/runtimes.sh" || failures+=("runtimes (mise)")
fi

if "$install_extras"; then
  "$repo_dir/scripts/ecosystems.sh" || true
fi

if "$install_extras" && ! skipped vscode && command -v code >/dev/null 2>&1; then
  while IFS= read -r extension; do
    code --install-extension "$extension" --force || failures+=("vscode:$extension")
  done < <(read_manifest "$repo_dir/packages/vscode-extensions.txt")
fi

if (( ${#failures[@]} > 0 )); then
  printf '\nNão instalados nesta distribuição (%d):\n' "${#failures[@]}" >&2
  printf '  %s\n' "${failures[@]}" >&2
fi
