#!/usr/bin/env bash
# Backup diário offsite: dump Postgres (+ oficialseparado) + .env/sessions → rsync para contenção.
# Uso (produção, root ou deploy): sudo ./tools/backup_diario.sh
# Requer: /home/deploy/backup_offsite.conf e chave SSH em CONTENCAO_SSH_KEY
set -euo pipefail

CONF="${BACKUP_OFFSITE_CONF:-/home/deploy/backup_offsite.conf}"
SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VAR_FILE="${SETUP_DIR}/VARIAVEIS_INSTALACAO"

if [[ ! -f "${CONF}" ]]; then
  echo "ERRO: configure ${CONF} (veja tools/backup_offsite.conf.example)"
  exit 1
fi
# shellcheck disable=SC1090
source "${CONF}"

if [[ -z "${EMPRESA:-}" && -f "${VAR_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${VAR_FILE}"
  EMPRESA="${empresa:-}"
fi

: "${CONTENCAO_HOST:?}"
: "${CONTENCAO_USER:=deploy}"
: "${CONTENCAO_SSH_KEY:?}"
: "${CONTENCAO_SSH_PORT:=22}"
: "${EMPRESA:?EMPRESA/slug não definido}"
: "${KEEP_LOCAL_DAYS:=1}"

APP_ROOT="/home/deploy/${EMPRESA}"
ENV_FILE="${APP_ROOT}/backend/.env"
STAMP="$(date +%Y-%m-%d_%H%M)"
WORK="/home/deploy/backups/staging/${EMPRESA}/${STAMP}"
REMOTE_ROOT="/home/deploy/backups/offsite/${EMPRESA}"
REMOTE_DIR="${REMOTE_ROOT}/${STAMP}"

SSH_OPTS=(-i "${CONTENCAO_SSH_KEY}" -p "${CONTENCAO_SSH_PORT}" -o StrictHostKeyChecking=accept-new -o BatchMode=yes)

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERRO: ${ENV_FILE} não encontrado"
  exit 1
fi
if [[ ! -f "${CONTENCAO_SSH_KEY}" ]]; then
  echo "ERRO: chave SSH ${CONTENCAO_SSH_KEY} não encontrada"
  exit 1
fi

db_pass="$(grep -E '^DB_PASS=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_user="$(grep -E '^DB_USER=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_name="$(grep -E '^DB_NAME=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_host="$(grep -E '^DB_HOST=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_user="${db_user:-$EMPRESA}"
db_name="${db_name:-$EMPRESA}"
db_host="${db_host:-localhost}"

mkdir -p "${WORK}"
chmod 700 "${WORK}"

echo "==> Dump ${db_name}"
PGPASSWORD="${db_pass}" pg_dump -U "${db_user}" -h "${db_host}" -Fc --no-owner --no-acl \
  -f "${WORK}/db.dump" "${db_name}"

if PGPASSWORD="${db_pass}" psql -U "${db_user}" -h "${db_host}" -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='oficialseparado'" | grep -q 1; then
  echo "==> Dump oficialseparado"
  PGPASSWORD="${db_pass}" pg_dump -U "${db_user}" -h "${db_host}" -Fc --no-owner --no-acl \
    -f "${WORK}/oficialseparado.dump" oficialseparado
else
  echo "==> oficialseparado não existe — pulando"
fi

echo "==> Empacotando .env e sessions"
PACK_LIST=()
[[ -f "${APP_ROOT}/backend/.env" ]] && PACK_LIST+=("backend/.env")
[[ -f "${APP_ROOT}/frontend/.env" ]] && PACK_LIST+=("frontend/.env")
[[ -f "${APP_ROOT}/api_oficial/.env" ]] && PACK_LIST+=("api_oficial/.env")
[[ -d "${APP_ROOT}/backend/sessions" ]] && PACK_LIST+=("backend/sessions")

if [[ ${#PACK_LIST[@]} -gt 0 ]]; then
  tar -C "${APP_ROOT}" -czf "${WORK}/env-and-sessions.tar.gz" "${PACK_LIST[@]}"
else
  echo "AVISO: nada para empacotar (.env/sessions)"
fi

GIT_REV="unknown"
if [[ -d "${APP_ROOT}/.git" ]]; then
  GIT_REV="$(git -C "${APP_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
elif [[ -d "${APP_ROOT}/backend/.git" ]]; then
  GIT_REV="$(git -C "${APP_ROOT}/backend" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

cat >"${WORK}/manifest.json" <<EOF
{
  "empresa": "${EMPRESA}",
  "hostname": "$(hostname -f 2>/dev/null || hostname)",
  "stamp": "${STAMP}",
  "git": "${GIT_REV}",
  "has_oficialseparado": $([ -f "${WORK}/oficialseparado.dump" ] && echo true || echo false),
  "created_at": "$(date -Iseconds)"
}
EOF

chmod -R go-rwx "${WORK}"

echo "==> Enviando para ${CONTENCAO_USER}@${CONTENCAO_HOST}:${REMOTE_DIR}"
ssh "${SSH_OPTS[@]}" "${CONTENCAO_USER}@${CONTENCAO_HOST}" "mkdir -p '${REMOTE_DIR}'"
rsync -az -e "ssh ${SSH_OPTS[*]}" "${WORK}/" "${CONTENCAO_USER}@${CONTENCAO_HOST}:${REMOTE_DIR}/"
ssh "${SSH_OPTS[@]}" "${CONTENCAO_USER}@${CONTENCAO_HOST}" \
  "ln -sfn '${REMOTE_DIR}' '${REMOTE_ROOT}/latest'"

echo "==> Limpando staging local (> ${KEEP_LOCAL_DAYS} dia(s))"
find "/home/deploy/backups/staging/${EMPRESA}" -mindepth 1 -maxdepth 1 -type d -mtime "+${KEEP_LOCAL_DAYS}" -exec rm -rf {} + 2>/dev/null || true

echo "OK: backup ${EMPRESA} ${STAMP} → ${CONTENCAO_HOST}:${REMOTE_DIR}"
