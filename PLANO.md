# Campfire — Plataforma de Comunicação Privada Auto-Hospedada (MVP: Texto + Voz)

## Contexto

O objetivo é construir um "core do Discord" para um único servidor privado, auto-hospedado pelo dono, com convite direto aos amigos — sem multi-tenancy, sem dependência de infraestrutura de terceiros para o núcleo do produto. O motivador é a pressão regulatória recente sobre plataformas centralizadas (ANPD / ECA Digital) tornando atrativa uma alternativa que o próprio usuário controla e hospeda.

Decisões de arquitetura já tomadas:
1. **SFU**: FastAPI não implementa WebRTC. **LiveKit self-hosted roda como serviço sidecar separado** (container próprio); FastAPI só autentica usuários e emite tokens de acesso ao LiveKit.
2. **Escopo do MVP**: **texto + voz**. Vídeo de câmera, compartilhamento de tela e "live" broadcast ficam para uma fase 2, reaproveitando a mesma infra de mídia (LiveKit já suporta os três nativamente — a fase 2 é majoritariamente trabalho de cliente, não de arquitetura nova).
3. **Auth**: convite por link/código (com limite de usos e expiração opcional) → registro usuário+senha → sessão via JWT (access + refresh token).

Duas aplicações — `client/` (Tauri) e `server/` (FastAPI) — num mesmo repositório, com um `infra/` para orquestração via Docker Compose.

---

## 1. Layout do repositório

```
campfire/
  server/                     # FastAPI app
    app/
      main.py                 # FastAPI app factory, mount routers, CORS, lifespan
      core/
        config.py             # pydantic-settings (env vars)
        security.py           # hashing (passlib/argon2), JWT encode/decode
        deps.py                # get_current_user, get_db, require_admin
      db.py                    # async SQLAlchemy engine/session
      models/                  # SQLAlchemy 2.0 ORM models
        user.py, invite.py, channel.py, message.py, attachment.py, server_settings.py
      schemas/                 # Pydantic request/response models
      api/
        auth.py                # register/login/refresh/logout
        invites.py             # admin invite CRUD
        server.py               # server settings
        channels.py             # channel CRUD
        messages.py              # message CRUD + pagination
        uploads.py                # multipart upload -> attachment
        voice.py                  # POST /voice/{channel_id}/token
        webhooks.py                # LiveKit webhook receiver
      gateway/
        manager.py               # ConnectionManager (WS registry, broadcast)
        events.py                 # event type enum + payload schemas
        router.py                 # /gateway websocket endpoint
      services/
        livekit_service.py        # token minting, webhook verification
    alembic/                       # migrations
    alembic.ini
    pyproject.toml
    Dockerfile

  client/                       # Tauri app
    src-tauri/                  # Rust shell, tauri.conf.json, secure storage plugin
    src/                         # React + TypeScript (Vite)
      api/client.ts               # REST client, attaches Bearer, 401->refresh
      ws/gateway.ts                 # WebSocket client, reconnect w/ backoff
      livekit/voice.ts               # wraps livekit-client SDK
      state/                          # Zustand stores (auth, channels, messages, voice)
      screens/
        ServerConnectScreen.tsx        # first run: enter self-hosted server URL
        LoginScreen.tsx
        RegisterWithInviteScreen.tsx
        ServerShell.tsx                  # sidebar (text/voice channel lists)
        TextChannelView.tsx
        VoiceChannelView.tsx               # participant list, mute controls
    package.json
    tauri.conf.json

  infra/
    docker-compose.yml            # prod: postgres, livekit, caddy, server
    docker-compose.dev.yml        # dev: postgres, livekit (dev keys)
    livekit/livekit.yaml
    caddy/Caddyfile

  .env.example
  README.md
```

---

## 2. Modelo de dados (server)

SQLAlchemy 2.0 async + Alembic. **Postgres** (não SQLite) — justificativa: WebSocket gateway em FastAPI async faz escritas concorrentes (mensagens, invite redemption) frequentes; SQLite tem limitações de lock em concorrência de escrita, e o custo de rodar Postgres num container extra é desprezível (2 vCPU/4GB comporta tranquilamente).

Entidades principais:
- **User**: `id (uuid)`, `username (unique)`, `password_hash`, `is_admin (bool)`, `created_at`
- **Invite**: `id`, `code (unique token)`, `created_by_id (FK User)`, `max_uses`, `uses_count`, `expires_at (nullable)`, `created_at`
- **ServerSettings**: linha singleton — `name`, `icon_url`, `created_at` (representa o "guild" único)
- **Channel**: `id`, `name`, `type (enum: text|voice)`, `position (int)`, `created_at`
- **Message**: `id`, `channel_id (FK, tipo text)`, `author_id (FK User)`, `content`, `created_at`, `edited_at (nullable)`
- **Attachment**: `id`, `message_id (FK, nullable até anexar)`, `filename`, `content_type`, `size_bytes`, `storage_path`

Estado de voz (quem está em qual canal, mute/speaking) é **efêmero**: vive na memória do `ConnectionManager` do gateway, alimentado pelos webhooks do LiveKit — não precisa de tabela própria no MVP.

---

## 3. Superfície de API

**Auth**
- `POST /api/auth/register` `{invite_code, username, password}` → consome invite, cria usuário, retorna access+refresh JWT
- `POST /api/auth/login` `{username, password}` → tokens
- `POST /api/auth/refresh` `{refresh_token}` → novo access token
- `POST /api/auth/logout`

**Invites** (admin)
- `POST /api/invites` `{max_uses, expires_in}` → código
- `GET /api/invites`, `DELETE /api/invites/{id}`

**Server / Channels**
- `GET /api/server`, `PATCH /api/server` (admin)
- `GET /api/channels`, `POST /api/channels` (admin), `PATCH/DELETE /api/channels/{id}` (admin)

**Messages**
- `GET /api/channels/{id}/messages?before=&limit=` (paginação por cursor)
- `POST /api/channels/{id}/messages` `{content, attachment_ids?}`
- `PATCH/DELETE /api/messages/{id}`

**Uploads**
- `POST /api/uploads` (multipart) → valida tipo/tamanho, grava em volume local (`UPLOAD_DIR`), retorna `attachment_id` + URL servida pelo próprio FastAPI (ou Caddy estático)

**Voz**
- `POST /api/voice/{channel_id}/token` → valida que o canal existe e é de voz, emite JWT do LiveKit via `livekit-api` (`AccessToken` + `VideoGrants(room_join=True, room=channel_id, can_publish=True, can_subscribe=True)`)
- `POST /api/webhooks/livekit` → recebe eventos do LiveKit (verificados via `WebhookReceiver` do SDK, usando API key/secret), atualiza estado de voz no `ConnectionManager` e propaga `VOICE_STATE_UPDATE` pelo gateway

**Gateway (WebSocket)** — `/gateway`, uma conexão persistente por cliente após handshake com JWT:
- `ConnectionManager`: registro de conexões por `user_id`, `broadcast(event)`, `send_to_user(id, event)`
- Eventos (inspirados no gateway do Discord): `READY` (dump inicial de estado), `MESSAGE_CREATE/UPDATE/DELETE`, `TYPING_START`, `PRESENCE_UPDATE`, `VOICE_STATE_UPDATE`, `CHANNEL_CREATE/UPDATE/DELETE`
- Heartbeat/ping-pong para detectar conexões mortas

---

## 4. Integração com LiveKit

- SDK: `livekit-api` (Python) no server para mintar tokens; `livekit-client` (JS) no cliente Tauri para a conexão WebRTC real.
- **Nomeação de sala**: nome do canal de voz (`channel_id`) vira diretamente o `room` do LiveKit.
- **Webhook**: configurado no `livekit.yaml` para apontar para `POST /api/webhooks/livekit`; eventos `participant_joined` / `participant_left` / `room_finished` mantêm o estado de voz sincronizado e disparam `VOICE_STATE_UPDATE` no gateway.
- **docker-compose**: serviço `livekit` (imagem oficial `livekit/livekit-server`), montando `infra/livekit/livekit.yaml` com `api_key`/`api_secret` compartilhados com o FastAPI via env; portas `7880` (HTTP/WS), `7881` (RTC TCP fallback), faixa UDP para RTC (ex: `50000-60000/udp`) expostas no VPS.
- **TURN**: usar o **TURN embutido do LiveKit** (habilitável via config, compartilhando porta 443/TLS) em vez de um `coturn` separado — reduz peças móveis para operar. ⚠️ **Verificar durante a implementação** as chaves exatas de config (`turn.enabled`, portas) na versão atual do LiveKit, pois evoluem entre releases.
- ⚠️ **Verificar durante a implementação**: nomes exatos de classes no `livekit-api` Python SDK atual (`AccessToken`, `VideoGrants`, `WebhookReceiver`) e o formato do payload de webhook — confirmar contra a documentação/PyPI no momento de codar, não assumir cegamente o que está descrito aqui.

---

## 5. Cliente (Tauri)

- Shell Rust majoritariamente boilerplate; armazenamento seguro do refresh token via plugin de secure storage do Tauri (keychain do SO).
- Frontend: React + TypeScript + Vite (padrão do Tauri), estado com **Zustand** (bom encaixe para atualizações vindas do gateway via eventos).
- `api/client.ts`: wrapper fetch, injeta Bearer token, refresh automático em 401.
- `ws/gateway.ts`: cliente WebSocket com reconexão exponencial, despacha eventos para as stores.
- `livekit/voice.ts`: encapsula `livekit-client` (`Room.connect`, `localParticipant.setMicrophoneEnabled`, listeners de `TrackSubscribed`/`ParticipantConnected` para lista de participantes e indicador de "falando").
- Telas mínimas do MVP: `ServerConnectScreen` (self-hosted → precisa perguntar a URL do servidor no primeiro uso, não é um SaaS fixo), `LoginScreen`, `RegisterWithInviteScreen`, `ServerShell` (sidebar com canais texto/voz), `TextChannelView` (lista + composer + drag&drop de arquivo), `VoiceChannelView` (avatares dos participantes, mute/deafen, indicador de fala).

---

## 6. Workflow de desenvolvimento local

- `infra/docker-compose.dev.yml`: `postgres`, `livekit` (config dev com chaves não-secretas), opcionalmente `adminer` para inspecionar o banco.
- Server: `uvicorn app.main:app --reload` apontando para o Postgres/LiveKit do compose; CORS liberado para `tauri://localhost` em modo dev.
- Client: `npm run tauri dev` apontando para `http://localhost:8000`.
- `.env.example` documentando `DATABASE_URL`, `JWT_SECRET`, `LIVEKIT_API_KEY/SECRET/URL`, `UPLOAD_DIR`.

---

## 7. Marcos de construção (ordem recomendada)

**M0 — Scaffold**: layout do repo, FastAPI com `/health`, Postgres+Alembic conectados, Tauri com shell React em branco. *Entrega*: `docker compose up` + `npm run tauri dev` → janela abre e faz ping em `/health`.

**M1 — Auth & Invites**: models `User`/`Invite` + migrations, endpoints register/login/refresh, dependency de validação JWT, bootstrap do primeiro admin (via env/CLI), geração de convite. Cliente: telas de conectar-ao-servidor, registro via convite, login, persistência de token. *Entrega*: registrar via link de convite, logar, permanecer logado após reiniciar o app.

**M2 — Texto + Gateway**: models `Channel`/`Message`/`Attachment` + migrations, CRUD de canais (admin), CRUD+paginação de mensagens, upload em disco local, gateway WebSocket com `READY`/`MESSAGE_CREATE`/`TYPING_START`. Cliente: sidebar de canais, view de canal de texto com updates em tempo real, composer com anexo. *Entrega*: dois clientes logados veem mensagens um do outro em tempo real.

**M3 — Voz via LiveKit**: serviço LiveKit no compose + config, endpoint de token de voz, webhook receiver + evento `VOICE_STATE_UPDATE`, integração `livekit-client` no cliente (entrar/sair, mute, lista de participantes, indicador de fala). *Entrega*: dois clientes em redes diferentes entram no mesmo canal de voz (atravessando TURN) e se ouvem.

**M4 — Empacotamento & Deploy**: build de produção do Tauri para os SOs alvo, compose de produção (Caddy com TLS automático, notas de backup de Postgres + uploads, config de produção do LiveKit com IP público), README de deploy para VPS. *Entrega*: um amigo baixa o cliente, aponta para seu domínio, entra via link de convite de fora da sua rede.

*(Fase 2, fora de escopo agora: vídeo de câmera, compartilhamento de tela, modo live/broadcast, E2EE via Insertable Streams, transferência de arquivo P2P via DataChannel — a arquitetura de M3 já comporta essas extensões sem redesenho.)*

---

## 8. Notas de deploy em produção

- **Reverse proxy**: Caddy (TLS automático via Let's Encrypt) na frente do FastAPI (`/api`, `/gateway`) e do LiveKit (subdomínio dedicado, ex: `livekit.seudominio.com`, dado que LiveKit usa WS + faixa de portas RTC próprias).
- **Portas a abrir no VPS**: 443 (Caddy), faixa UDP do LiveKit para RTC, 7881/TCP (fallback).
- **Backups**: `pg_dump` agendado (cron) para o volume do Postgres; backup do volume de uploads (ou usar Cloudflare R2 desde já para já ter durabilidade gerenciada).
- **Segredos**: arquivo `.env` no VPS (fora do controle de versão), `JWT_SECRET`/`LIVEKIT_API_SECRET`/senha do Postgres gerados via `openssl rand`, documentados no README — não hardcoded no compose.

---

## Verificação

- M0: `docker compose -f infra/docker-compose.dev.yml up` sobe sem erro; `curl localhost:8000/health` retorna 200; `npm run tauri dev` abre janela.
- M1: fluxo manual completo de convite→registro→login→refresh via cliente real; teste automatizado (pytest) do endpoint de auth.
- M2: dois clientes (duas instâncias do app, dois usuários) trocando mensagens em tempo real; teste automatizado de paginação de mensagens.
- M3: teste manual de voz entre duas redes distintas (ex: uma via 4G/hotspot) para validar que o TURN embutido do LiveKit realmente resolve NAT restritivo — este é o teste mais crítico de todo o MVP, pois é o que valida a arquitetura de infra mínima proposta no documento original.
- M4: instalar o cliente empacotado numa máquina "limpa" (sem ambiente de dev) e completar o fluxo de convite de ponta a ponta contra o servidor de produção.
