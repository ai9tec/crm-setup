#!/usr/bin/env bash
# Promote (restore) de um backup offsite nesta VPS de contenção.
# ATENÇÃO: sobrescreve o banco da instalação local (EMPRESA_LOCAL).
#
# Uso:
#   sudo ./tools/promote_from_backup.sh --slug PRODUCAO [--stamp latest] [--dry-run]
#
# Premissas:
# - CRM já instalado nesta VPS (mesmo stack)
# - Backup em /home/deploy/backups/offsite/{slug}/{stamp}/
# - Após o script: apontar DNS da produção caída para este IP e renovar SSL se necessário
set -euo pipefail

OFFSITE_ROOT="/home/deploy/backups/offsite"
SLUG=""
STAMP="latest"
DRY_RUN=0
EMPRESA_LOCAL=""

usage() {
  echo "Uso: sudo $0 --slug SLUG_PRODUCAO [--stamp latest|YYYY-MM-DD_HHMM] [--empresa-local SLUG] [--dry-run]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --stamp) STAMP="$2"; shift 2 ;;
    --empresa-local) EMPRESA_LOCAL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[[ -n "${SLUG}" ]] || usage
[[ "$(id -u)" -eq 0 ]] || { echo "Execute como root"; exit 1; }

SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${EMPRESA_LOCAL}" && -f "${SETUP_DIR}/VARIAVEIS_INSTALACAO" ]]; then
  # shellcheck disable=SC1090
  source "${SETUP_DIR}/VARIAVEIS_INSTALACAO"
  EMPRESA_LOCAL="${empresa:-}"
fi
: "${EMPRESA_LOCAL:?Informe --empresa-local (slug instalado nesta VPS)}"

SRC="${OFFSITE_ROOT}/${SLUG}/${STAMP}"
if [[ "${STAMP}" == "latest" && -L "${OFFSITE_ROOT}/${SLUG}/latest" ]]; then
  SRC="$(readlink -f "${OFFSITE_ROOT}/${SLUG}/latest")"
fi

[[ -d "${SRC}" ]] || { echo "ERRO: backup não encontrado: ${SRC}"; exit 1; }
[[ -f "${SRC}/db.dump" ]] || { echo "ERRO: db.dump ausente em ${SRC}"; exit 1; }
[[ -f "${SRC}/manifest.json" ]] && echo "Manifest:" && cat "${SRC}/manifest.json" && echo

APP_ROOT="/home/deploy/${EMPRESA_LOCAL}"
ENV_FILE="${APP_ROOT}/backend/.env"
[[ -f "${ENV_FILE}" ]] || { echo "ERRO: ${ENV_FILE} não encontrado"; exit 1; }

db_pass="$(grep -E '^DB_PASS=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_user="$(grep -E '^DB_USER=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_name="$(grep -E '^DB_NAME=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_host="$(grep -E '^DB_HOST=' "${ENV_FILE}" | head -1 | cut -d= -f2- | tr -d '\r')"
db_user="${db_user:-$EMPRESA_LOCAL}"
db_name="${db_name:-$EMPRESA_LOCAL}"
db_host="${db_host:-localhost}"

echo "Restore: ${SRC} → DB ${db_name} / app ${APP_ROOT}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[dry-run] Nenhuma alteração feita."
  echo "Próximos passos manuais após promote real:"
  echo "  1) Conferir .env restaurado (R2, URLs) — pode precisar reajustar BACKEND_URL/FRONTEND_URL temporários"
  echo "  2) pm2 restart all"
  echo "  3) Apontar DNS da produção caída para o IP desta VPS"
  echo "  4) certbot --nginx -d app... -d api... -d apiof..."
  echo "  5) Validar login + WABA"
  exit 0
fi

read -r -p "CONFIRMA restore DESTRUTIVO no banco ${db_name}? (digite SIM): " confirm
[[ "${confirm}" == "SIM" ]] || { echo "Abortado."; exit 1; }

echo "==> Parando PM2"
sudo -u deploy bash -lc 'pm2 stop all' || true

echo "==> Restore DB principal"
PGPASSWORD="${db_pass}" pg_restore -U "${db_user}" -h "${db_host}" -d "${db_name}" \
  --clean --if-exists --no-owner --no-acl --single-transaction "${SRC}/db.dump" || true

if [[ -f "${SRC}/oficialseparado.dump" ]]; then
  echo "==> Restore oficialseparado"
  PGPASSWORD="${db_pass}" pg_restore -U "${db_user}" -h "${db_host}" -d oficialseparado \
    --clean --if-exists --no-owner --no-acl --single-transaction "${SRC}/oficialseparado.dump" || true
fi

if [[ -f "${SRC}/env-and-sessions.tar.gz" ]]; then
  echo "==> Extraindo .env e sessions (backup dos .env atuais em .env.pre-promote)"
  [[ -f "${APP_ROOT}/backend/.env" ]] && cp -a "${APP_ROOT}/backend/.env" "${APP_ROOT}/backend/.env.pre-promote"
  [[ -f "${APP_ROOT}/frontend/.env" ]] && cp -a "${APP_ROOT}/frontend/.env" "${APP_ROOT}/frontend/.env.pre-promote"
  tar -C "${APP_ROOT}" -xzf "${SRC}/env-and-sessions.tar.gz"
  chown -R deploy:deploy "${APP_ROOT}/backend/sessions" 2>/dev/null || true
fi

echo "==> Subindo PM2"
sudo -u deploy bash -lc 'pm2 restart all'

echo
echo "Restore concluído."
echo "Checklist:"
echo "  [ ] Revisar ${APP_ROOT}/backend/.env (URLs/R2) — se o promote for permanente, alinhar DNS e SSL"
echo "  [ ] DNS A/AAAA da produção caída → IP desta VPS"
echo "  [ ] certbot --nginx para os domínios de produção"
echo "  [ ] Testar login e envio/recebimento WABA"
echo "  [ ] Se Baileys falhar, reconectar QR"
