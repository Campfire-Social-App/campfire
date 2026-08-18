# Campfire

Alternativa privada e auto-hospedada ao Discord: voz, texto e (futuramente) vídeo/tela para um único servidor, hospedado por você e usado só pelo seu grupo de amigos.

Sem multi-tenancy, sem depender de infraestrutura de terceiros para o núcleo do produto — você sobe o servidor, gera convites, e é dono dos seus dados.

> Arquitetura completa e roadmap detalhado em [PLANO.md](PLANO.md).

---

## Stack

| Componente | Tecnologia |
| :--- | :--- |
| Cliente (desktop) | Tauri + React + TypeScript |
| Cliente (mobile) | Flutter + Dart (em construção) |
| Servidor (core) | Python + FastAPI |
| Voz/vídeo (SFU) | LiveKit (self-hosted, serviço separado) |
| Banco de dados | PostgreSQL |
| Reverse proxy / TLS | Caddy |
| Orquestração | Docker Compose |

O FastAPI cuida de autenticação, canais, mensagens e sinalização (WebSocket gateway); o LiveKit cuida exclusivamente da mídia em tempo real (WebRTC). Os clientes falam com os dois.

O cliente Flutter em `app/` é um segundo consumidor da mesma API, com a mesma cara e as mesmas funções — nada no servidor muda por causa dele. Plano de obra em [PLANO_FLUTTER.md](PLANO_FLUTTER.md).

---

## Escopo atual (MVP)

- [x] Convite por link/código + registro de usuário
- [x] Login com sessão JWT (access + refresh)
- [x] Canais de texto (mensagens, anexos)
- [x] Fotos, vídeos e arquivos (colar print, progresso, preview/player, download com nome original)
- [x] Gateway em tempo real (WebSocket) para mensagens e presença
- [x] Canais de voz via LiveKit (entrar/sair, mute, indicador de fala)
- [x] Mensagens diretas 1:1 (conversas privadas, com não-lidas, na barra da esquerda)
- [x] Chamadas de voz/vídeo dentro da DM (toque, aceitar/recusar, câmera e tela)
- [ ] Empacotamento do cliente + guia de deploy em VPS

Vídeo de câmera, compartilhamento de tela e modo live ficam para uma fase posterior — a infraestrutura de voz (LiveKit) já suporta os três nativamente, então essa fase é majoritariamente trabalho de cliente.

---

## Roadmap (fora do MVP)

Itens que a arquitetura já comporta, mas que não entram na v1:

- **Vídeo de câmera** nos canais de voz
- **Compartilhamento de tela**
- **Modo live/broadcast** (transmissão para audiência maior que a sala)
- **E2EE** no áudio/vídeo via WebRTC Insertable Streams
- **Transferência de arquivo P2P** direto entre clientes (WebRTC DataChannels), como alternativa ao upload centralizado
- **Cargos e permissões** por canal (hoje só existe admin vs. usuário comum)
- **Múltiplos servidores** por instância de cliente (hoje é um servidor por deploy)
- **Notificações push** para o app fechado/minimizado — pré-requisito de servidor
  para a chamada tocar com o app Flutter fechado (ver PLANO_FLUTTER.md §9)

---

## Estrutura do repositório

```
campfire/
  server/     # API FastAPI (auth, canais, mensagens, gateway, tokens LiveKit)
  client/     # App desktop Tauri
  app/        # App mobile Flutter (Android/iOS; desktop de brinde)
  infra/      # docker-compose, config do LiveKit, Caddyfile
```

---

## Desenvolvimento local

Pré-requisitos: Docker, Node.js + npm, Rust (para o Tauri), Python 3.12+ + Poetry.

No Linux, o `tauri dev`/`tauri build` também precisa das libs de sistema do WebView
(`webkit2gtk`, `gtk3`, etc.) — veja https://tauri.app/start/prerequisites/#linux.

```bash
# Stack de apoio (Postgres + LiveKit em modo dev)
docker compose -f infra/docker-compose.dev.yml up -d

# Servidor
cd server
poetry install
cp .env.example .env
poetry run alembic upgrade head
poetry run python -m app.cli create-admin --username admin --password <senha>
poetry run uvicorn app.main:app --reload

# Cliente desktop
cd client
npm install
npm run tauri dev

# Cliente mobile
cd app
flutter pub get
flutter run
```

O `app/` tem instruções próprias — código gerado, geração dos tokens de tema a
partir do CSS do cliente React — em [app/README.md](app/README.md).

---

## Deploy em produção

Notas de arquitetura em [PLANO.md](PLANO.md#8-notas-de-deploy-em-produção): Docker Compose com Caddy (TLS automático), LiveKit exposto num subdomínio próprio, backup de Postgres e uploads, e segredos gerenciados via `.env` fora do controle de versão.

### Esteira

Push no `master` que toque em `server/` ou `infra/` dispara o workflow [Deploy server](.github/workflows/deploy-server.yml): a suíte roda contra um Postgres real e, só se passar, o runner entra na VPS por SSH, deixa o repositório no commit testado e executa [`infra/deploy.sh`](infra/deploy.sh), que reconstrói a imagem, sobe o compose e espera `https://$DOMAIN/health` responder antes de dar o deploy por bom.

Secrets usados pelo workflow: `DEPLOY_SSH_KEY` (chave privada), `DEPLOY_HOST`, `DEPLOY_PORT`, `DEPLOY_USER`, `DEPLOY_KNOWN_HOSTS` (saída do `ssh-keyscan`, para o runner não confiar em qualquer host no IP).

### Bootstrap da máquina (uma vez)

A esteira atualiza um servidor que já existe; ela não cria um do zero. Numa VPS nova:

```bash
# 1. Docker
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

# 2. Código
git clone https://github.com/masioware/campfire.git /opt/campfire

# 3. Segredos — gerados na própria máquina, nunca versionados
cat > /opt/campfire/infra/.env <<EOF
POSTGRES_USER=campfire
POSTGRES_PASSWORD=$(openssl rand -hex 24)
POSTGRES_DB=campfire
JWT_SECRET=$(openssl rand -hex 32)
LIVEKIT_API_KEY=$(openssl rand -hex 12)
LIVEKIT_API_SECRET=$(openssl rand -hex 32)
DOMAIN=seudominio.com
LIVEKIT_DOMAIN=livekit.seudominio.com
FIRST_ADMIN_USERNAME=admin
FIRST_ADMIN_PASSWORD=<senha do primeiro admin>
EOF
chmod 600 /opt/campfire/infra/.env

# 4. Buffers de UDP — o LiveKit avisa no boot que o padrão do kernel é pequeno
#    demais para um SFU, e sob carga isso vira perda de pacote no áudio/vídeo
cat > /etc/sysctl.d/99-livekit.conf <<EOF
net.core.rmem_max=5000000
net.core.wmem_max=5000000
EOF
sysctl -p /etc/sysctl.d/99-livekit.conf

# 5. Primeira subida
cd /opt/campfire && infra/deploy.sh
```

O `.env` fica em `infra/`, não na raiz: o `docker compose -f infra/docker-compose.yml` usa o diretório do arquivo como project directory e é lá que ele procura.

Sem domínio próprio, `sslip.io` resolve qualquer nome terminado num IP para aquele IP (`DOMAIN=203.0.113.10.sslip.io`), e o Let's Encrypt emite certificado normalmente — o cliente precisa de TLS válido para falar `https://` com a API e `wss://` com o LiveKit. Trocar pelo domínio de verdade depois é editar essas duas linhas e rodar o deploy de novo.

Portas que precisam estar abertas: 443/TCP+UDP e 80/TCP (Caddy e o desafio do ACME), 7881/TCP (fallback RTC) e 7882/UDP (mídia do LiveKit).

---

## Licença

A definir.
