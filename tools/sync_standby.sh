#!/usr/bin/env bash
# Sincroniza pasta da produção → standby na Oracle (plano A) e aplica overlay.
# Roda NA PRODUÇÃO: sudo -u deploy ./tools/sync_standby.sh
# Requer /home/deploy/sync_standby.conf (veja sync_standby.conf.example)
set -euo pipefail

CONF="${SYNC_STANDBY_CONF:-/home/deploy/sync_standby.conf}"
if [[ ! -f "${CONF}" ]]; then
  echo "ERRO: configure ${CONF} (modelo: tools/sync_standby.conf.example)"
  exit 1
fi
# shellcheck disable=SC1090
source "${CONF}"

: "${STANDBY_NAME:?}"
: "${LOCAL_ROOT:?}"
: "${CONTENCAO_HOST:?}"
: "${CONTENCAO_USER:=deploy}"
: "${CONTENCAO_SSH_PORT:=22}"
: "${CONTENCAO_SSH_KEY:?}"
: "${REMOTE_ROOT:?}"
: "${REMOTE_SETUP_DIR:=/home/deploy/crm-setup}"

if [[ ! -d "${LOCAL_ROOT}" ]]; then
  echo "ERRO: LOCAL_ROOT não existe: ${LOCAL_ROOT}"
  exit 1
fi
if [[ ! -f "${CONTENCAO_SSH_KEY}" ]]; then
  echo "ERRO: chave SSH não encontrada: ${CONTENCAO_SSH_KEY}"
  exit 1
fi

SSH_OPTS=(-i "${CONTENCAO_SSH_KEY}" -p "${CONTENCAO_SSH_PORT}" -o StrictHostKeyChecking=accept-new -o BatchMode=yes)
RSYNC_SSH="ssh -i ${CONTENCAO_SSH_KEY} -p ${CONTENCAO_SSH_PORT} -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

LOCK_FILE="/tmp/sync_standby_${STANDBY_NAME}.lock"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "Outro sync de ${STANDBY_NAME} em andamento — saindo"
  exit 0
fi

echo "==> [${STANDBY_NAME}] rsync ${LOCAL_ROOT}/ → ${CONTENCAO_USER}@${CONTENCAO_HOST}:${REMOTE_ROOT}/"

ssh "${SSH_OPTS[@]}" "${CONTENCAO_USER}@${CONTENCAO_HOST}" "mkdir -p '${REMOTE_ROOT}'"

rsync -az --delete \
  --exclude 'node_modules/' \
  --exclude '**/node_modules/' \
  --exclude 'backend/logs/' \
  --exclude 'api_oficial/logs/' \
  --exclude 'frontend/node_modules/' \
  --exclude '.cache/' \
  --exclude '*.log' \
  -e "${RSYNC_SSH}" \
  "${LOCAL_ROOT}/" \
  "${CONTENCAO_USER}@${CONTENCAO_HOST}:${REMOTE_ROOT}/"

echo "==> [${STANDBY_NAME}] apply_standby_overlay na Oracle"
ssh "${SSH_OPTS[@]}" "${CONTENCAO_USER}@${CONTENCAO_HOST}" \
  "bash '${REMOTE_SETUP_DIR}/tools/apply_standby_overlay.sh' '${STANDBY_NAME}'"

echo "OK: sync ${STANDBY_NAME} concluído ($(date -Iseconds))"
