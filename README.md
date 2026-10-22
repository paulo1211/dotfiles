# Dotfiles do Paulo

Configurações pessoais portáveis para reinstalar o ambiente em outra distribuição Linux.

## Instalação

```bash
git clone <URL-DESTE-REPOSITORIO> ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run
./install.sh
```

Arquivos existentes são movidos para `~/.dotfiles-backup/<data-hora>/` antes de os links simbólicos serem criados.

Para instalar também os pacotes da distribuição, os runtimes (mise), os manifestos de npm/Go/Python/Snap/Flatpak e as extensões do VS Code:

```bash
./install.sh --packages
```

O instalador detecta a distribuição por `/etc/os-release` e reconhece:

- Debian, Ubuntu e derivadas (`apt`).
- Fedora, RHEL e derivadas (`dnf`).
- Arch Linux, Manjaro, EndeavourOS e derivadas (`pacman`).
- openSUSE Leap, Tumbleweed e SUSE Linux Enterprise (`zypper`).

Em RHEL, Rocky e AlmaLinux o EPEL e o CRB (CodeReady Builder) são habilitados automaticamente, porque `fzf`, `ripgrep`, `ShellCheck` e outros vêm de lá. Diferenças de nome de pacote entre famílias ficam em `packages/names.txt`. Pacotes que não existem numa distribuição são listados no final, sem interromper a instalação.

Se `/etc/os-release` não for conclusivo, ele tenta detectar o gerenciador de pacotes. Para conferir a distribuição e a arquitetura sem instalar nada:

```bash
./scripts/packages.sh --detect
```

Java 21 (Temurin), Node, Go, uv, kubectl, helm, terraform, golangci-lint, AWS CLI, act e eksctl são instalados pelo [mise](https://mise.jdx.dev) a partir de `config/mise/config.toml`, da mesma forma em todas as distribuições. O Maven continua vindo da distribuição. Para pular etapas, use `DOTFILES_SKIP`, por exemplo `DOTFILES_SKIP=distro-extras,snap,flatpak,vscode ./install.sh --packages`.

O bootstrap não instala Docker; veja a seção de itens manuais.

## Testes por distribuição

`tests/distros.sh` roda `./install.sh --packages` em contêineres Debian, Ubuntu, Fedora, Rocky Linux, Arch, openSUSE Tumbleweed e Leap, e confere os comandos num shell de login novo. Os logs ficam em `tests/logs/`. Também é possível testar só algumas imagens:

```bash
tests/distros.sh archlinux:latest fedora:latest
```

## Conteúdo

- Bash: aliases, histórico, PATH, ativação do mise e inicialização opcional de NVM/Homebrew.
- Git: identidade separada em arquivo local e ignore global.
- VS Code e Zed: preferências e lista de extensões.
- htop e Flameshot: preferências atuais.
- `packages/common.txt` e `packages/names.txt`: pacotes comuns e seus nomes em cada família.
- `config/mise/config.toml`: runtimes e CLIs instalados pelo mise.
- `packages/distro/`: equivalências das ferramentas atuais para cada família Linux.
- Manifestos de Snap, Flatpak, npm, Go e ferramentas Python.
- `packages/external-tools.md`: catálogo dos softwares instalados fora da automação (CLIs de DevOps, Flatpaks, IDEs, apps corporativos e logins pós-instalação).
- `scripts/capture.sh`: atualiza no repositório somente os arquivos permitidos.
- `scripts/doctor.sh`: mostra o que ainda falta após uma migração.

## Identidade Git local

A identidade e outros dados específicos da máquina não ficam no repositório. Depois de instalar:

```bash
cp ~/.gitconfig.local.example ~/.gitconfig.local
chmod 600 ~/.gitconfig.local
${EDITOR:-vim} ~/.gitconfig.local
```

## Atualizar o repositório a partir da máquina

```bash
cd ~/dotfiles
./scripts/capture.sh
git diff
```

O script usa uma lista explícita. Ele não captura `.ssh`, `.aws`, `.kube`, `.gnupg`, históricos, bancos de dados de aplicativos, cookies, tokens nem arquivos MCP.

## Segredos (Bitwarden)

Chaves SSH, `~/.ssh/config`, `~/.gitconfig.local`, AWS e kubeconfig ficam no Bitwarden como notas seguras chamadas `dotfiles/...`. A lista está em `secrets/manifest.txt` e contém só nomes e caminhos. O `bw` é instalado pelo mise.

Na máquina atual, envie os arquivos para o cofre (só uma vez, ou quando mudarem):

```bash
scripts/secrets.sh push --dry-run
scripts/secrets.sh push
```

Numa máquina nova:

```bash
./install.sh --packages --secrets
# ou, depois da instalação:
scripts/secrets.sh pull
```

O script pede login ou a senha mestra quando necessário. Arquivos locais diferentes do cofre são movidos para `~/.dotfiles-backup/` antes de serem sobrescritos. `scripts/secrets.sh status` mostra o que existe no cofre e na máquina. Para servidor próprio (Vaultwarden etc.), defina `BW_SERVER=https://...`.

## Itens que permanecem manuais

- Chaves GPG: não estão no manifesto.
- Docker: use o repositório oficial da distribuição e recrie a participação no grupo `docker`.
- Autenticação com tokens de curta duração: execute novamente `gh auth login`, `aws sso login`, `tsh login` etc.
- Ajustes do GNOME e extensões: variam bastante entre versões e não foram incluídos nesta primeira versão.

O modo `--packages` também tenta restaurar os manifestos de Snap, Flatpak, npm, Go e Python. Ecossistemas indisponíveis são ignorados com um aviso. Consulte [packages/external-tools.md](packages/external-tools.md) para SAM CLI, Teleport, editores, CLIs corporativas e aplicativos com repositório próprio.

## Publicação

Antes do primeiro push, confira:

```bash
git status
git diff --cached
git grep -nEi '(password|passwd|secret|token|api[_-]?key|private[_-]?key)'
```

Crie então um repositório vazio no provedor escolhido e adicione o remoto. O repositório nasce sem remoto para evitar publicação acidental.
