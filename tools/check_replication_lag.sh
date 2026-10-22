#!/usr/bin/env bash
# Alerta de replicação lógica. Só lê. Não derruba slot e não altera o Postgres.
# Rode como root, via cron, em cada publicação e na Oracle.
# Config: /etc/crm-replication-monitor.conf
set -euo pipefail

CONF="${REPLICATION_MONITOR_CONF:-/etc/crm-replication-monitor.conf}"
if [[ ! -f "${CONF}" ]]; then
  echo "ERRO: configure ${CONF} (modelo: tools/check_replication_lag.conf.example)"
  exit 1
fi
# shellcheck disable=SC1090
source "${CONF}"

: "${ROLE:?ROLE=publisher ou subscriber}"
: "${ALERT_URL:=}"
: "${ALERT_FORMAT:=ntfy}"
: "${REALERT_SECONDS:=3600}"
: "${WAL_WARN_BYTES:=1073741824}"
: "${WAL_CRIT_BYTES:=5368709120}"
: "${DISK_WARN_PERCENT:=75}"
: "${DISK_CRIT_PERCENT:=85}"
: "${SUB_LAG_SECONDS:=180}"

if [[ "${ROLE}" != "publisher" && "${ROLE}" != "subscriber" ]]; then
  echo "ERRO: ROLE deve ser publisher ou subscriber"
  exit 1
fi

HOST_NAME="$(hostname -s)"
STATE_DIR="/var/lib/crm-replication-monitor"
STATE_FILE="${STATE_DIR}/state"
mkdir -p "${STATE_DIR}"

LOCK_FILE="/var/lock/crm-replication-monitor.lock"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "Outra checagem em andamento — saindo"
  exit 0
fi

human_bytes() {
  local b="$1"
  if (( b >= 1073741824 )); then
    awk -v b="${b}" 'BEGIN { printf "%.1f GB", b/1073741824 }'
  elif (( b >= 1048576 )); then
    awk -v b="${b}" 'BEGIN { printf "%.0f MB", b/1048576 }'
  else
    echo "${b} B"
  fi
}

psql_at() {
  local db="${1:-postgres}"
  shift
  sudo -u postgres psql -d "${db}" -v ON_ERROR_STOP=1 -At -c "$*"
}

problems=()
worst="ok"

add_problem() {
  local level="$1"
  local text="$2"
  problems+=("${level}|${text}")
  if [[ "${level}" == "critico" ]]; then
    worst="critico"
  elif [[ "${worst}" != "critico" ]]; then
    worst="aviso"
  fi
}

check_disk() {
  local used
  used="$(df -P / | awk 'NR==2 { gsub(/%/, "", $5); print $5 }')"
  if [[ ! "${used}" =~ ^[0-9]+$ ]]; then
    add_problem "aviso" "Não foi possível ler o uso de disco em /."
    return
  fi
  if (( used >= DISK_CRIT_PERCENT )); then
    add_problem "critico" "Disco em ${used}% (limite ${DISK_CRIT_PERCENT}%)."
  elif (( used >= DISK_WARN_PERCENT )); then
    add_problem "aviso" "Disco em ${used}% (aviso a partir de ${DISK_WARN_PERCENT}%)."
  fi
}

check_publisher() {
  local rows line name active retained
  if ! rows="$(psql_at postgres \
    "SELECT slot_name || '|' || CASE WHEN active THEN '1' ELSE '0' END || '|' || COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn), 0)::bigint FROM pg_replication_slots WHERE slot_type = 'logical' ORDER BY slot_name;")"; then
    add_problem "critico" "Falha ao consultar pg_replication_slots."
    return
  fi
  if [[ -z "${rows}" ]]; then
    add_problem "aviso" "Nenhum slot lógico de replicação encontrado."
    return
  fi
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    IFS='|' read -r name active retained <<<"${line}"
    if [[ "${active}" != "1" ]]; then
      add_problem "critico" "Slot ${name} inativo. WAL retido: $(human_bytes "${retained}"). A assinatura parou de consumir. O slot foi mantido."
    elif (( retained >= WAL_CRIT_BYTES )); then
      add_problem "critico" "Slot ${name} ativo com $(human_bytes "${retained}") de WAL retido (limite $(human_bytes "${WAL_CRIT_BYTES}"))."
    elif (( retained >= WAL_WARN_BYTES )); then
      add_problem "aviso" "Slot ${name} ativo com $(human_bytes "${retained}") de WAL retido (aviso a partir de $(human_bytes "${WAL_WARN_BYTES}"))."
    fi
  done <<<"${rows}"
  check_disk
}

check_subscriber() {
  local databases db subs line name has_pid lag
  if ! databases="$(psql_at postgres \
    "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY 1;")"; then
    add_problem "critico" "Falha ao listar bancos na Oracle."
    return
  fi
  while IFS= read -r db; do
    [[ -z "${db}" ]] && continue
    if ! subs="$(psql_at "${db}" \
      "SELECT subname || '|' || CASE WHEN pid IS NULL THEN '0' ELSE '1' END || '|' || COALESCE(EXTRACT(EPOCH FROM (clock_timestamp() - last_msg_receipt_time))::bigint, -1) FROM pg_stat_subscription ORDER BY 1;" 2>/dev/null)"; then
      continue
    fi
    [[ -z "${subs}" ]] && continue
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      IFS='|' read -r name has_pid lag <<<"${line}"
      if [[ "${lag}" -lt 0 ]]; then
        add_problem "critico" "Assinatura ${name} no banco ${db} ainda não recebeu dados."
      elif [[ "${has_pid}" != "1" ]]; then
        add_problem "critico" "Assinatura ${name} no banco ${db} sem worker. Último recebimento há ${lag}s."
      elif (( lag > SUB_LAG_SECONDS )); then
        add_problem "critico" "Assinatura ${name} no banco ${db} sem avançar há ${lag}s (limite ${SUB_LAG_SECONDS}s)."
      fi
    done <<<"${subs}"
  done <<<"${databases}"
}

send_alert() {
  local title="$1"
  local body="$2"
  local priority="default"
  [[ "${worst}" == "critico" ]] && priority="high"

  logger -t crm-replication -p user.warning "${title}: ${body}"

  if [[ -z "${ALERT_URL}" ]]; then
    return 0
  fi

  if [[ "${ALERT_FORMAT}" == "slack" ]]; then
    ALERT_TITLE="${title}" ALERT_BODY="${body}" \
      node -e 'process.stdout.write(JSON.stringify({text: process.env.ALERT_TITLE + "\n" + process.env.ALERT_BODY}))' \
      | curl -fsS -m 20 -H "Content-Type: application/json" -d @- "${ALERT_URL}" >/dev/null
  elif [[ "${ALERT_FORMAT}" == "n8n" ]]; then
    ALERT_TITLE="${title}" ALERT_BODY="${body}" ALERT_PRIORITY="${priority}" ALERT_HOST="${HOST_NAME}" ALERT_ROLE="${ROLE}" \
      node -e 'process.stdout.write(JSON.stringify({title:process.env.ALERT_TITLE,body:process.env.ALERT_BODY,priority:process.env.ALERT_PRIORITY,host:process.env.ALERT_HOST,role:process.env.ALERT_ROLE}))' \
      | curl -fsS -m 20 -H "Content-Type: application/json" -d @- "${ALERT_URL}" >/dev/null
  else
    curl -fsS -m 20 \
      -H "Title: ${title}" \
      -H "Priority: ${priority}" \
      --data-binary "${body}" \
      "${ALERT_URL}" >/dev/null
  fi
}

fingerprint() {
  printf '%s\n' "${problems[@]}" | sort | sha256sum | awk '{print $1}'
}

if [[ "${ROLE}" == "publisher" ]]; then
  check_publisher
else
  check_subscriber
fi

now="$(date +%s)"
prev_hash=""
prev_at=0
if [[ -f "${STATE_FILE}" ]]; then
  IFS='|' read -r prev_hash prev_at <"${STATE_FILE}" || true
fi

if (( ${#problems[@]} == 0 )); then
  if [[ -n "${prev_hash}" ]]; then
    worst="ok"
    send_alert "[ok] replicação ${HOST_NAME}" "A replicação lógica voltou ao normal em ${HOST_NAME} (${ROLE})."
    rm -f "${STATE_FILE}"
  fi
  echo "OK ${HOST_NAME} ${ROLE} $(date -Iseconds)"
  exit 0
fi

body=""
for item in "${problems[@]}"; do
  body+="${item#*|}"$'\n'
done
body+=$'\n'"O slot não foi alterado. Corrija a assinatura na Oracle e deixe o WAL ser consumido."
body+=$'\n'"Log: sudo grep -A3 'logical replication apply worker' /var/log/postgresql/postgresql-17-main.log | tail -40"

hash="$(fingerprint)"
if [[ "${hash}" == "${prev_hash}" && $(( now - prev_at )) -lt "${REALERT_SECONDS}" ]]; then
  echo "ALERTA já enviado, aguardando ${REALERT_SECONDS}s — ${HOST_NAME}"
  exit 0
fi

title="[${worst}] replicação ${HOST_NAME}"
send_alert "${title}" "${body}"
printf '%s|%s\n' "${hash}" "${now}" >"${STATE_FILE}"
printf '%s\n%s\n' "${title}" "${body}"
exit 1
