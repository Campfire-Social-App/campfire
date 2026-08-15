# Campfire

Alternativa privada e auto-hospedada ao Discord: voz, texto e (futuramente) vídeo/tela para um único servidor, hospedado por você e usado só pelo seu grupo de amigos.

Sem multi-tenancy, sem depender de infraestrutura de terceiros para o núcleo do produto — você sobe o servidor, gera convites, e é dono dos seus dados.

> Arquitetura completa e roadmap detalhado em [PLANO.md](PLANO.md).

---

## Stack

| Componente | Tecnologia |
| :--- | :--- |
| Cliente (desktop) | Tauri + React + TypeScript |
| Servidor (core) | Python + FastAPI |
| Voz/vídeo (SFU) | LiveKit (self-hosted, serviço separado) |
| Banco de dados | PostgreSQL |
| Reverse proxy / TLS | Caddy |
| Orquestração | Docker Compose |

O FastAPI cuida de autenticação, canais, mensagens e sinalização (WebSocket gateway); o LiveKit cuida exclusivamente da mídia em tempo real (WebRTC). O cliente Tauri fala com os dois.

---

## Escopo atual (MVP)

- [x] Convite por link/código + registro de usuário
- [x] Login com sessão JWT (access + refresh)
- [x] Canais de texto (mensagens, anexos)
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
- **Notificações push** para o app fechado/minimizado
- **Build para mobile** (Tauri 2 suporta Android/iOS, não avaliado ainda)

---

## Estrutura do repositório

```
campfire/
  server/     # API FastAPI (auth, canais, mensagens, gateway, tokens LiveKit)
  client/     # App desktop Tauri
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

# Cliente
cd client
npm install
npm run tauri dev
```

---

## Deploy em produção

Guia completo em [PLANO.md](PLANO.md#8-notas-de-deploy-em-produção): Docker Compose com Caddy (TLS automático), LiveKit exposto num subdomínio próprio, backup de Postgres e uploads, e segredos gerenciados via `.env` fora do controle de versão.

---

## Licença

A definir.
