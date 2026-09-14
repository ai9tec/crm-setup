#!/usr/bin/env bash
# Aplica overlay de standby no .env após rsync da produção.
# Roda NA ORACLE: sudo -u deploy ./tools/apply_standby_overlay.sh app|magistral|beauty
set -euo pipefail

STANDBY="${1:-}"
if [[ -z "${STANDBY}" ]]; then
  echo "Uso: $0 app|magistral|beauty"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAP_FILE="${STANDBY_MAP:-${SCRIPT_DIR}/standby_map.conf}"
APP_ROOT="/home/deploy/${STANDBY}"
BACKEND_ENV="${APP_ROOT}/backend/.env"
FRONTEND_ENV="${APP_ROOT}/frontend/.env"
OFICIAL_ENV="${APP_ROOT}/api_oficial/.env"
SECRET_FILE="/home/deploy/standby-overlays/${STANDBY}.secret"

if [[ ! -f "${MAP_FILE}" ]]; then
  echo "ERRO: mapa não encontrado: ${MAP_FILE}"
  exit 1
fi

LINE="$(grep -E "^${STANDBY}\\|" "${MAP_FILE}" || true)"
if [[ -z "${LINE}" ]]; then
  echo "ERRO: standby '${STANDBY}' não está em ${MAP_FILE}"
  exit 1
fi

IFS='|' read -r _NAME BACKEND_PORT FRONTEND_PORT OFICIAL_PORT REDIS_DB DB_NAME OFICIAL_DB <<<"${LINE}"

if [[ ! -d "${APP_ROOT}" ]]; then
  echo "ERRO: pasta ${APP_ROOT} não existe (rode o rsync primeiro)"
  exit 1
fi
if [[ ! -f "${BACKEND_ENV}" ]]; then
  echo "ERRO: ${BACKEND_ENV} não existe"
  exit 1
fi

# Senha do role Postgres do standby na Oracle (obrigatória na 1ª vez)
DB_PASS=""
REDIS_PASS=""
if [[ -f "${SECRET_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${SECRET_FILE}"
fi
: "${DB_PASS:?Defina DB_PASS em ${SECRET_FILE}}"

# Reaproveita senha Redis do .env sincronizado (produção), se REDIS_PASS não veio no secret
if [[ -z "${REDIS_PASS}" ]]; then
  REDIS_PASS="$(grep -E '^REDIS_URI=' "${BACKEND_ENV}" | head -1 | sed -n 's|.*redis://:\([^@]*\)@.*|\1|p' || true)"
fi
if [[ -z "${REDIS_PASS}" ]]; then
  echo "ERRO: não foi possível obter senha Redis; defina REDIS_PASS em ${SECRET_FILE}"
  exit 1
fi

upsert_env() {
  local file="$1" key="$2" value="$3"
  if [[ ! -f "${file}" ]]; then
    return 0
  fi
  python3 - "${file}" "${key}" "${value}" <<'PY'
import sys
path, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
except FileNotFoundError:
    lines = []
out = []
found = False
prefix = key + "="
for line in lines:
    if line.startswith(prefix):
        out.append(prefix + value)
        found = True
    else:
        out.append(line)
if not found:
    out.append(prefix + value)
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(out) + "\n")
PY
}

echo "==> Overlay backend (${STANDBY})"
upsert_env "${BACKEND_ENV}" "PORT" "${BACKEND_PORT}"
upsert_env "${BACKEND_ENV}" "DB_NAME" "${DB_NAME}"
upsert_env "${BACKEND_ENV}" "DB_USER" "${DB_NAME}"
upsert_env "${BACKEND_ENV}" "DB_PASS" "${DB_PASS}"
upsert_env "${BACKEND_ENV}" "REDIS_URI" "redis://:${REDIS_PASS}@127.0.0.1:6379/${REDIS_DB}"
# URLs locais até o promote (DNS de produção apontar para a Oracle)
upsert_env "${BACKEND_ENV}" "BACKEND_URL" "http://127.0.0.1:${BACKEND_PORT}"
upsert_env "${BACKEND_ENV}" "FRONTEND_URL" "http://127.0.0.1:${FRONTEND_PORT}"

if [[ -f "${FRONTEND_ENV}" ]]; then
  echo "==> Overlay frontend"
  upsert_env "${FRONTEND_ENV}" "SERVER_PORT" "${FRONTEND_PORT}"
  upsert_env "${FRONTEND_ENV}" "REACT_APP_BACKEND_URL" "http://127.0.0.1:${BACKEND_PORT}"
fi

if [[ -f "${OFICIAL_ENV}" ]]; then
  echo "==> Overlay api_oficial"
  upsert_env "${OFICIAL_ENV}" "PORT" "${OFICIAL_PORT}"
  upsert_env "${OFICIAL_ENV}" "DATABASE_NAME" "${OFICIAL_DB}"
  upsert_env "${OFICIAL_ENV}" "DATABASE_LINK" "postgresql://${DB_NAME}:${DB_PASS}@localhost:5432/${OFICIAL_DB}?schema=public"
fi

# server.js do frontend muitas vezes tem porta fixa após sed do instalador
if [[ -f "${APP_ROOT}/frontend/server.js" ]]; then
  if grep -qE 'SERVER_PORT|process\.env\.PORT|3000' "${APP_ROOT}/frontend/server.js"; then
    # garante leitura de SERVER_PORT se o arquivo ainda for o template antigo
    sed -i -E 's/const port = process\.env\.PORT \|\| 3000;/const port = Number(process.env.SERVER_PORT || process.env.PORT || 3000);/' \
      "${APP_ROOT}/frontend/server.js" || true
  fi
fi

chmod 600 "${BACKEND_ENV}" "${FRONTEND_ENV}" 2>/dev/null || true
[[ -f "${OFICIAL_ENV}" ]] && chmod 600 "${OFICIAL_ENV}" || true

echo "OK: overlay aplicado em ${STANDBY} (portas ${BACKEND_PORT}/${FRONTEND_PORT}/${OFICIAL_PORT}, redis /${REDIS_DB}, db ${DB_NAME})"
