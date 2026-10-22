#!/usr/bin/env bash
# Executado como root dentro do contêiner: prepara um usuário com sudo,
# roda o instalador como esse usuário e confere os comandos esperados.
set -Eeuo pipefail

# shellcheck source=/dev/null
. /etc/os-release
case " ${ID} ${ID_LIKE:-} " in
  *" debian "*|*" ubuntu "*) apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo >/dev/null ;;
  *" fedora "*|*" rhel "*) dnf install -y -q sudo ;;
  *" arch "*) pacman -Sy --noconfirm --needed sudo >/dev/null ;;
  *" suse "*|*" opensuse "*) zypper --non-interactive -q install sudo ;;
esac

useradd --create-home --shell /bin/bash tester
printf 'tester ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

cp -r /src /home/tester/dotfiles
chown -R tester: /home/tester/dotfiles

run_as_tester() {
  sudo -u tester -H env DOTFILES_SKIP="${DOTFILES_SKIP:-}" GITHUB_TOKEN="${GITHUB_TOKEN:-}" "$@"
}

run_as_tester /home/tester/dotfiles/install.sh --packages

printf '\n==> Verificação em um shell de login novo\n'
read -ra expected <<<"${EXPECTED_COMMANDS:?}"
missing=()
for command_name in "${expected[@]}"; do
  if path=$(run_as_tester bash -lic "command -v $command_name" 2>/dev/null); then
    printf '  ok       %-14s %s\n' "$command_name" "$path"
  else
    printf '  ausente  %s\n' "$command_name"
    missing+=("$command_name")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'RESULTADO: FALHOU (%s)\n' "${missing[*]}"
  exit 1
fi
printf 'RESULTADO: OK\n'
