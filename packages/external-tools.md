# Catálogo de softwares da estação de trabalho

Inventário da máquina original (Ubuntu, x86_64) com o caminho de instalação em qualquer distribuição. Os itens das seções 1 a 6 não são instalados pelo `./install.sh`.

Legenda das famílias: **deb** = Debian/Ubuntu, **rpm** = Fedora/RHEL/Rocky, **arch** = Arch e derivadas, **suse** = openSUSE.

## Já automatizado (referência)

`./install.sh --packages` instala:

- **Pacotes da distribuição:** git, curl, ripgrep, fd, fzf, jq, tmux, vim, shellcheck, htop, ferramentas de compilação, Maven, gh, ffmpeg, nmap, rclone, flameshot, flatpak e outros (`packages/common.txt` e `packages/distro/`).
- **mise:** Java 21 (Temurin), Node LTS, Go, uv, kubectl, helm, terraform, golangci-lint, AWS CLI, act, eksctl e Bitwarden CLI (`config/mise/config.toml`).
- **Manifestos:** gopls e hey (Go), gemini-cli (npm), awxkit (uv), Headlamp e Podman Desktop (Flatpak), extensões do VS Code.
- **Segredos:** `./install.sh --secrets` restaura do Bitwarden as chaves SSH, `~/.ssh/config`, a configuração da AWS e o kubeconfig.

## 1. CLIs de DevOps

| Ferramenta | Versão na máquina original | Instalação |
|---|---|---|
| **Docker Engine** + buildx + compose | 29.9.1 | **deb/rpm:** repositório oficial, conforme <https://docs.docker.com/engine/install/>. **arch:** `pacman -S docker docker-buildx docker-compose`. **suse:** `zypper in docker docker-buildx docker-compose`. Depois, em todas: `sudo systemctl enable --now docker && sudo usermod -aG docker $USER` |
| **Ansible** (pacote completo, com coleções amazon.aws, awx.awx, community.*, cisco.* etc.) | ansible-core da distro | `uv tool install --with-executables-from ansible-core ansible` (alternativa: `pipx install --include-deps ansible`) |
| **ansible-lint** | da distro | `uv tool install ansible-lint` |
| **Teleport** (`tsh`, `tctl`, `tbot`) | **7.3.23**: precisa ser compatível com o cluster | `curl -fLO https://cdn.teleport.dev/teleport-v7.3.23-linux-amd64-bin.tar.gz`, extrair e copiar `teleport/tsh`, `tctl` e `tbot` para `~/.local/bin` (em arm64, troque `amd64` por `arm64`) |
| **AWS SAM CLI** | instalador oficial | `uv tool install aws-sam-cli`, ou o instalador da AWS: <https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html> |
| **Vagrant** | da distro | **deb/rpm:** repositório da HashiCorp, <https://developer.hashicorp.com/vagrant/install>. **arch/suse:** binário do mesmo link. Box usada: `vagrant box add generic/ubuntu2204` |
| **.NET SDK** | em `~/.dotnet` | `curl -fsSL https://dot.net/v1/dotnet-install.sh \| bash -s -- --channel LTS` |
| **Codex CLI** | `~/.codex` | `npm install -g @openai/codex` |

Repositório do Helm a recriar: `helm repo add kedacore https://kedacore.github.io/charts`.

## 2. Aplicativos gráficos (Flatpak, qualquer distribuição)

Substituem os Snaps e pacotes APT da máquina original. Os IDs foram conferidos no Flathub.

| Aplicativo | Antes | ID no Flathub |
|---|---|---|
| Brave | snap | `com.brave.Browser` |
| Firefox | snap | `org.mozilla.firefox` |
| Microsoft Edge | apt | `com.microsoft.Edge` |
| Thunderbird | snap | `org.mozilla.Thunderbird` |
| Obsidian | apt | `md.obsidian.Obsidian` |
| Logseq | AppImage | `com.logseq.Logseq` |
| Beekeeper Studio | snap | `io.beekeeperstudio.Studio` |
| CherryTree | snap | `net.giuspen.cherrytree` |
| Super Productivity | snap | `com.super_productivity.SuperProductivity` |
| OBS Studio | apt | `com.obsproject.Studio` |
| Kdenlive | snap | `org.kde.kdenlive` |
| PDF Arranger | snap | `com.github.jeromerobert.pdfarranger` |
| KCalc | snap | `org.kde.kcalc` |

Tudo de uma vez:

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub \
  com.brave.Browser org.mozilla.firefox com.microsoft.Edge org.mozilla.Thunderbird \
  md.obsidian.Obsidian com.logseq.Logseq io.beekeeperstudio.Studio net.giuspen.cherrytree \
  com.super_productivity.SuperProductivity com.obsproject.Studio org.kde.kdenlive \
  com.github.jeromerobert.pdfarranger org.kde.kcalc
```

## 3. Editores e IDEs

| Aplicativo | Instalação |
|---|---|
| **VS Code** | **deb/rpm/suse:** repositório da Microsoft, <https://code.visualstudio.com/docs/setup/linux>. **arch:** AUR `visual-studio-code-bin`. Evite o Flatpak, porque o terminal integrado fica isolado do sistema. As extensões são instaladas pelo `install.sh` |
| **JetBrains Toolbox** | <https://www.jetbrains.com/toolbox-app/>; extraia e execute. GoLand, IntelliJ IDEA, PyCharm e RustRover são reinstalados por ele. JDKs do IntelliJ ficam em `~/.jdks` |
| **Zed** | `curl -f https://zed.dev/install.sh \| sh` |
| **Claude Code** | `curl -fsSL https://claude.ai/install.sh \| bash` |

## 4. Fornecedor e corporativos

| Aplicativo | Instalação | Observação |
|---|---|---|
| **FortiClient VPN** | <https://www.fortinet.com/support/product-downloads> (deb/rpm) | Conexão `paulo.araujo3`. Em Arch e openSUSE, ou se o FortiClient não funcionar: `openfortivpn` + plugin `NetworkManager-fortisslvpn` (nomes variam por distro) |
| **VirtualBox** | **deb/rpm:** <https://www.virtualbox.org/wiki/Linux_Downloads>. **arch/suse:** pacote `virtualbox` da distro | Versão 7.2 na máquina original. VMs em `~/VirtualBox VMs` |
| **Duplicati** | <https://duplicati.com/download> | Job "bkp pc". Guarde a senha de criptografia no Bitwarden |
| **Claude Desktop** | repositório do fornecedor (o mesmo de `/etc/apt/sources.list.d/claude-desktop`) | |
| **ChatGPT** | repositório do fornecedor (o mesmo de `/etc/apt/sources.list.d/chatgpt`) | |
| **ZenNotes** | instalador do fornecedor | Configuração em `~/.config/zennotes` |
| **LM Studio** | AppImage em <https://lmstudio.ai> | Modelos podem ser baixados de novo |
| **Antigravity** (`agy`) | <https://antigravity.google> | |
| **Perplexity** (`pplx`) | instalador do produto | |
| **TWG** | distribuição corporativa | Timer de usuário `twg-upkeep` em `~/.config/systemd/user` |

## 5. Só no Ubuntu (Snap)

Não há equivalente oficial em outras distribuições:

| Snap | Para que serve | Alternativa fora do Ubuntu |
|---|---|---|
| `microk8s` (classic) | Kubernetes local | `kind` ou `k3d` (disponíveis no mise) |
| `multipass` | VMs Ubuntu rápidas | Vagrant ou VirtualBox |
| `workshop` | Ambientes de desenvolvimento da Canonical | — |
| `ora` | Ora (gestão de tarefas) | versão web |
| `screenshot-tool` | Captura de tela | Flameshot (já instalado) |

## 6. Logins após a instalação

Tokens de sessão não vão para o cofre; refaça nesta ordem:

```bash
scripts/secrets.sh pull                         # chaves SSH, AWS, kubeconfig
gh auth login                                   # GitHub (Git usa o token do gh via HTTPS)
tsh login --proxy=teleport.ozmap.com.br         # Teleport
aws sso login --profile <perfil>                # se algum perfil usar SSO
aws eks update-kubeconfig --name togglemaster-eks --region us-east-1   # se o kubeconfig não vier do cofre
docker login                                    # e demais registries usados
claude                                          # Claude Code; repetir para codex, gemini, twg
```

Perfis AWS da máquina original: `default`, `datatransfer-report`, `account-br`, `account-llc` e `organization-finops`. Contextos Kubernetes: `togglemaster-eks` (EKS) e `devoz-cluster`.
