#!/usr/bin/env bash
# Inicializador local do Campfire. Usa exclusivamente o compose de
# desenvolvimento, que já contém credenciais locais e não depende do .env de
# produção (DOMAIN, LIVEKIT_DOMAIN e POSTGRES_PASSWORD).
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.dev.yml"
CLIENT_DIR="$ROOT_DIR/client"
HEALTH_URL="${CAMPFIRE_HEALTH_URL:-http://127.0.0.1:8000/health}"
HEALTH_RETRIES="${CAMPFIRE_HEALTH_RETRIES:-30}"

# Esta instalação do Docker não possui o plugin buildx. O builder clássico
# também funciona em máquinas que possuem buildx e evita essa dependência.
export DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-0}"
export COMPOSE_DOCKER_CLI_BUILD="${COMPOSE_DOCKER_CLI_BUILD:-0}"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
fail() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Uso: ./run.sh [comando]

Comandos:
  web       Sobe os serviços e abre o cliente web em http://localhost:1420 (padrão)
  desktop   Sobe os serviços e abre o cliente Tauri
  services  Sobe somente API, Postgres, LiveKit, bots e Adminer
  rebuild   Reconstrói as imagens e reinicia todos os serviços
  stop      Para os serviços locais
  restart   Reinicia os serviços locais
  logs      Acompanha os logs dos serviços
  status    Exibe o estado dos containers e da API
  help      Exibe esta ajuda

Variáveis opcionais:
  CAMPFIRE_HEALTH_RETRIES=30
  CAMPFIRE_HEALTH_URL=http://127.0.0.1:8000/health
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "comando '$1' não encontrado. $2"
}

check_docker() {
  require_command docker "Instale o Docker Engine e o Docker Compose."
  docker compose version >/dev/null 2>&1 || fail "o plugin 'docker compose' não está disponível."
  docker info >/dev/null 2>&1 || fail "não foi possível acessar o Docker. Verifique se o serviço está ativo e se seu usuário possui permissão."
}

wait_for_api() {
  require_command curl "Instale o curl para que o script possa verificar a API."
  log "Aguardando a API em $HEALTH_URL"
  for attempt in $(seq 1 "$HEALTH_RETRIES"); do
    if curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" 2>/dev/null | grep -q '"status":"ok"'; then
      echo "API pronta (tentativa $attempt)."
      return
    fi
    sleep 2
  done
  docker compose -f "$COMPOSE_FILE" logs --tail=80 server >&2
  fail "a API não ficou pronta em $((HEALTH_RETRIES * 2)) segundos."
}

start_services() {
  check_docker
  log "Iniciando os serviços locais"
  docker compose -f "$COMPOSE_FILE" up -d --remove-orphans
  wait_for_api
  docker compose -f "$COMPOSE_FILE" ps
  printf '\nAPI:     http://localhost:8000\nAdminer: http://localhost:8081\n'
}

prepare_desktop_client() {
  require_command node "Instale o Node.js 22 ou superior."
  require_command npm "Instale o npm."
  local node_major
  node_major="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"
  if [ "$node_major" -lt 22 ]; then
    fail "Node.js 22 ou superior é necessário; encontrado $(node --version)."
  fi
  if [ ! -d "$CLIENT_DIR/node_modules" ]; then
    log "Instalando dependências do cliente"
    (cd "$CLIENT_DIR" && npm ci)
  elif [ ! -w "$CLIENT_DIR/node_modules" ]; then
    fail "$CLIENT_DIR/node_modules não pertence ao usuário atual. Corrija com: sudo chown -R $(id -u):$(id -g) '$CLIENT_DIR/node_modules'"
  fi
}

run_web() {
  start_services
  if curl --fail --silent --max-time 2 http://127.0.0.1:1420 2>/dev/null | grep -qi '<title>Campfire</title>'; then
    log "O cliente web já está em execução"
    echo "Abra http://localhost:1420 no navegador."
    return
  fi
  log "Iniciando o cliente web"
  printf 'Abra http://localhost:1420 no navegador. Pressione Ctrl+C para encerrar o cliente.\n'
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 \
    && [ "$(node --version | sed -E 's/^v([0-9]+).*/\1/')" -ge 22 ]; then
    if [ ! -d "$CLIENT_DIR/node_modules" ]; then
      log "Instalando dependências do cliente"
      (cd "$CLIENT_DIR" && npm ci)
    fi
    cd "$CLIENT_DIR"
    exec npm run dev -- --host 0.0.0.0
  fi

  log "Node.js 22 não está disponível localmente; usando o container oficial"
  exec docker run --rm --network host \
    -v "$CLIENT_DIR:/app" \
    -v campfire_client_node_modules:/app/node_modules \
    -w /app node:22-bookworm \
    sh -c 'if [ ! -x node_modules/.bin/vite ]; then npm ci; fi; exec npm run dev -- --host 0.0.0.0'
}

run_desktop() {
  start_services
  prepare_desktop_client
  require_command cargo "Instale Rust/Cargo e os pré-requisitos do Tauri."
  log "Iniciando o cliente desktop"
  printf 'Pressione Ctrl+C para encerrar o cliente. Os serviços permanecem ativos; use ./run.sh stop para pará-los.\n'
  cd "$CLIENT_DIR"
  exec npm run tauri dev
}

action="${1:-web}"
case "$action" in
  desktop) run_desktop ;;
  web) run_web ;;
  services) start_services ;;
  rebuild)
    check_docker
    log "Reconstruindo e iniciando os serviços locais"
    docker compose -f "$COMPOSE_FILE" up -d --build --remove-orphans
    wait_for_api
    ;;
  stop)
    check_docker
    log "Parando os serviços locais"
    docker compose -f "$COMPOSE_FILE" down
    ;;
  restart)
    check_docker
    log "Reiniciando os serviços locais"
    docker compose -f "$COMPOSE_FILE" restart
    wait_for_api
    ;;
  logs)
    check_docker
    docker compose -f "$COMPOSE_FILE" logs --follow --tail=100
    ;;
  status)
    check_docker
    docker compose -f "$COMPOSE_FILE" ps
    if command -v curl >/dev/null 2>&1; then
      printf '\nAPI: '
      curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" || true
      printf '\n'
    fi
    ;;
  help|-h|--help) usage ;;
  *) usage >&2; fail "comando desconhecido: $action" ;;
esac
