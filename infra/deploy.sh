#!/usr/bin/env bash
# Sobe o stack de produção e valida que ele atende. Roda na VPS, chamado pelo
# workflow "Deploy server" depois que ele já deixou o repositório no commit
# certo — por isso este script não mexe em git: assim a versão do script que
# roda é sempre a do commit sendo publicado.
#
# À mão, para subir de novo sem passar pelo CI:
#   cd /opt/campfire && infra/deploy.sh
#
# O bootstrap da máquina (Docker, clone em /opt/campfire, infra/.env) é
# pré-requisito e está documentado no README.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/campfire}"
COMPOSE_FILE="$REPO_DIR/infra/docker-compose.yml"
ENV_FILE="$REPO_DIR/infra/.env"
HEALTH_RETRIES="${HEALTH_RETRIES:-36}"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

[ -f "$ENV_FILE" ] || {
  echo "ERRO: $ENV_FILE não existe. Faça o bootstrap da máquina antes (veja o README)." >&2
  exit 1
}

cd "$REPO_DIR"
log "Publicando $(git --no-pager log --oneline -1)"

# O livekit-server lê o YAML cru: não expande $VAR nenhuma. Sem isto a chave
# chega literal ("apiKey": "$LIVEKIT_API_KEY") e o processo morre na validação,
# reclamando que o segredo é curto demais. Então o arquivo é renderizado aqui,
# a partir do .env, e é a versão renderizada que o compose monta.
log "Renderizando a config do LiveKit"
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a
envsubst '$LIVEKIT_API_KEY $LIVEKIT_API_SECRET $LIVEKIT_DOMAIN' \
  < "$REPO_DIR/infra/livekit/livekit.yaml" \
  > "$REPO_DIR/infra/livekit/livekit.generated.yaml"
chmod 600 "$REPO_DIR/infra/livekit/livekit.generated.yaml"

# --build porque a imagem do server é construída na própria VPS: sem isso o
# compose reaproveitaria a imagem antiga e o deploy não mudaria nada.
log "Subindo os containers"
docker compose -f "$COMPOSE_FILE" up -d --build --remove-orphans

log "Estado"
docker compose -f "$COMPOSE_FILE" ps

# O health vai pelo domínio público de propósito: valida Caddy, TLS e API de uma
# vez só. Na primeira subida o Let's Encrypt ainda está emitindo o certificado,
# daí a paciência.
DOMAIN="$(grep -E '^DOMAIN=' "$ENV_FILE" | cut -d= -f2-)"
log "Aguardando https://$DOMAIN/health"
for i in $(seq 1 "$HEALTH_RETRIES"); do
  if curl -fsS --max-time 5 "https://$DOMAIN/health" 2>/dev/null | grep -q '"ok"'; then
    echo "OK (tentativa $i)"
    docker image prune -f >/dev/null
    exit 0
  fi
  sleep 5
done

echo "ERRO: /health não respondeu em $((HEALTH_RETRIES * 5))s." >&2
docker compose -f "$COMPOSE_FILE" logs --tail 60 server caddy >&2
exit 1
