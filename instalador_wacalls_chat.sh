#!/bin/bash
# =====================================================================
#  WaCalls Chat (WhatsApp Plus) — instalador integrado ao CRM
#  Compila o microserviço Go+React em /home/deploy/<empresa>/wacalls-chat,
#  sobe via systemd na porta 8081 e configura WACALLS_CHAT_* no backend.
#
#  Uso (root):
#    sudo ./instalador_wacalls_chat.sh
#    EMPRESA=minhaempresa sudo -E ./instalador_wacalls_chat.sh
#    sudo ./instalador_wacalls_chat.sh --rebuild-only   # só rebuild (atualizador)
# =====================================================================

set -o pipefail

GREEN='\033[1;32m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'

ARQUIVO_VARIAVEIS="VARIAVEIS_INSTALACAO"
DEFAULT_WACALLS_PORT=8081
DEFAULT_ADMIN_EMAIL="wacalls@admin.com"
DEFAULT_ADMIN_PASSWORD="admin"
REBUILD_ONLY="n"

for arg in "$@"; do
  case "$arg" in
    --rebuild-only|rebuild-only) REBUILD_ONLY="s" ;;
  esac
done

if [ "$EUID" -ne 0 ]; then
  echo
  printf "${WHITE} >> Este script precisa ser executado como root ${RED}ou com privilégios de superusuário${WHITE}.\n"
  echo
  exit 1
fi

trata_erro() {
  printf "${RED}Erro encontrado na etapa $1. Encerrando o script.${WHITE}\n"
  exit 1
}

banner() {
  clear
  printf "${BLUE}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║           INSTALADOR WACALLS-CHAT (WhatsApp Plus)            ║"
  echo "║                      CRM / MultiFlow                         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  printf "${WHITE}"
  echo
}

carregar_variaveis() {
  if [ -n "${EMPRESA}" ]; then
    empresa="${EMPRESA}"
  elif [ -f "$ARQUIVO_VARIAVEIS" ]; then
    # shellcheck source=/dev/null
    source "$ARQUIVO_VARIAVEIS"
  elif [ -f "/root/crm-setup/${ARQUIVO_VARIAVEIS}" ]; then
    # shellcheck source=/dev/null
    source "/root/crm-setup/${ARQUIVO_VARIAVEIS}"
  else
    printf "${RED} >> ERRO: informe EMPRESA=... ou rode a partir do crm-setup com VARIAVEIS_INSTALACAO.${WHITE}\n"
    exit 1
  fi
  empresa="${empresa:-multiflow}"
  wacalls_port="${wacalls_port:-${DEFAULT_WACALLS_PORT}}"
  wacalls_admin_email="${wacalls_admin_email:-${DEFAULT_ADMIN_EMAIL}}"
  wacalls_admin_password="${wacalls_admin_password:-${DEFAULT_ADMIN_PASSWORD}}"
}

SCRIPT_DIR_WACALLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/garantir_golang.sh
if [ -f "${SCRIPT_DIR_WACALLS}/lib/garantir_golang.sh" ]; then
  source "${SCRIPT_DIR_WACALLS}/lib/garantir_golang.sh"
elif [ -f "${SCRIPT_DIR_WACALLS}/../crm-setup/lib/garantir_golang.sh" ]; then
  source "${SCRIPT_DIR_WACALLS}/../crm-setup/lib/garantir_golang.sh"
else
  garantir_golang() {
    export PATH="/usr/local/go/bin:${PATH}"
    command -v go >/dev/null 2>&1 || {
      echo "ERRO: Go não instalado e lib/garantir_golang.sh ausente"
      return 1
    }
  }
fi

app_dir() {
  echo "/home/deploy/${empresa}/wacalls-chat"
}

service_name() {
  echo "${empresa}-wacalls-chat"
}

backend_env_path() {
  echo "/home/deploy/${empresa}/backend/.env"
}

ler_redis_url() {
  local env_path
  env_path="$(backend_env_path)"
  local redis_uri=""
  if [ -f "${env_path}" ]; then
    redis_uri=$(grep -E '^REDIS_URI=' "${env_path}" 2>/dev/null | cut -d= -f2- | tr -d '\r"' || true)
  fi
  if [ -z "${redis_uri}" ]; then
    # Fallback: Redis local sem senha / senha do VARIAVEIS
    if [ -n "${senha_deploy}" ]; then
      redis_uri="redis://:${senha_deploy}@127.0.0.1:6379"
    else
      redis_uri="redis://127.0.0.1:6379"
    fi
  fi
  # Usa DB 1 para não colidir com filas/cache do CRM (DB 0)
  if [[ "${redis_uri}" =~ /[0-9]+$ ]]; then
    echo "${redis_uri}" | sed -E 's|/[0-9]+$|/1|'
  else
    echo "${redis_uri%/}/1"
  fi
}

configurar_env_wacalls() {
  banner
  printf "${WHITE} >> Configurando .env do wacalls-chat...\n"
  echo

  local dir
  dir="$(app_dir)"
  if [ ! -d "${dir}" ]; then
    printf "${RED} >> ERRO: diretório não encontrado: ${dir}${WHITE}\n"
    printf "${YELLOW} >> Atualize o código do CRM (git pull) antes de instalar o wacalls-chat.${WHITE}\n"
    exit 1
  fi
  if [ ! -f "${dir}/go.mod" ] || [ ! -d "${dir}/cmd/server" ]; then
    printf "${RED} >> ERRO: código Go incompleto em ${dir}${WHITE}\n"
    exit 1
  fi

  chown -R deploy:deploy "${dir}"

  local redis_url env_file
  redis_url="$(ler_redis_url)"
  env_file="${dir}/.env"

  if [ -f "${env_file}" ] && grep -q '^REDIS_URL=' "${env_file}"; then
    printf "${YELLOW} >> Preservando .env existente (${env_file}).${WHITE}\n"
  else
    cat > "${env_file}" <<EOF
# Gerado pelo instalador CRM (wacalls-chat)
# Banco: SQLite em ${dir}/wacalls.db
REDIS_URL=${redis_url}
EOF
    chmod 600 "${env_file}"
    chown deploy:deploy "${env_file}"
    printf "${GREEN} >> .env criado com REDIS_URL (DB 1).${WHITE}\n"
  fi
  sleep 1
}

build_wacalls() {
  banner
  printf "${WHITE} >> Compilando wacalls-chat (frontend + Go)...\n"
  echo

  local dir
  dir="$(app_dir)"

  garantir_golang "${dir}/go.mod" || trata_erro "garantir_golang"

  # Node já existe nas VPS do CRM; garante no PATH do n/nodesource
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/local/go/bin:/usr/bin:/usr/local/bin:$PATH
  else
    export PATH=/usr/local/go/bin:/usr/bin:/usr/local/bin:$PATH
  fi

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    printf "${RED} >> ERRO: Node.js/npm não encontrados. Instale Node 20+ antes.${WHITE}\n"
    exit 1
  fi

  chown -R deploy:deploy "${dir}"

  sudo -u deploy -H bash <<BUILD
set -e
export PATH="${PATH}"
export CGO_ENABLED=0
export GO111MODULE=on
cd "${dir}"

echo ">> go mod download"
go mod download

echo ">> build frontend (client -> dist)"
if [ -f package.json ]; then
  npm run build
else
  npm --prefix client install --no-audit --no-fund
  npm --prefix client run build
fi

test -f dist/index.html || {
  echo "ERRO: dist/index.html não gerado"
  exit 1
}

echo ">> go build -> wacalls-server"
go build -o wacalls-server ./cmd/server
chmod +x wacalls-server
test -x wacalls-server
BUILD

  [ $? -eq 0 ] || trata_erro "build_wacalls"
  printf "${GREEN} >> Build concluído: ${dir}/wacalls-server${WHITE}\n"
  sleep 1
}

configurar_systemd() {
  banner
  printf "${WHITE} >> Configurando serviço systemd...\n"
  echo

  local dir name port
  dir="$(app_dir)"
  name="$(service_name)"
  port="${wacalls_port}"

  cat > "/etc/systemd/system/${name}.service" <<EOF
[Unit]
Description=WaCalls Chat (WhatsApp Plus) - ${empresa}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=${dir}
EnvironmentFile=-${dir}/.env
Environment=WACALLS_MEDIA_READY_TIMEOUT_SECONDS=25
ExecStart=${dir}/wacalls-server -addr :${port} -static ${dir}/dist -db ${dir}/wacalls.db -seed-admin-email ${wacalls_admin_email} -seed-admin-password ${wacalls_admin_password}
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "${name}.service"
  systemctl restart "${name}.service"
  sleep 2
  systemctl --no-pager --full status "${name}.service" || true
  printf "${GREEN} >> Serviço ${name} ativo na porta ${port}.${WHITE}\n"
  sleep 1
}

validar_servico() {
  banner
  printf "${WHITE} >> Validando wacalls-chat...\n"
  echo

  local port max_tentativas tentativa
  port="${wacalls_port}"
  max_tentativas=15
  tentativa=0

  while [ "$tentativa" -lt "$max_tentativas" ]; do
    if curl -sf -o /dev/null -w "%{http_code}" \
      -X POST "http://127.0.0.1:${port}/api/auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${wacalls_admin_email}\",\"password\":\"${wacalls_admin_password}\"}" \
      | grep -Eq '200|401|400'; then
      # 200 = login ok; 401/400 = API no ar (credenciais podem diferir em reinstall)
      printf "${GREEN} >> API respondendo em http://127.0.0.1:${port}${WHITE}\n"
      sleep 1
      return 0
    fi
    # fallback: SPA
    if curl -sf "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
      printf "${GREEN} >> Frontend respondendo em http://127.0.0.1:${port}/${WHITE}\n"
      sleep 1
      return 0
    fi
    tentativa=$((tentativa + 1))
    sleep 2
  done

  printf "${RED} >> ERRO: wacalls-chat não respondeu após ${max_tentativas} tentativas.${WHITE}\n"
  printf "${YELLOW} >> Verifique: journalctl -u $(service_name) -n 80 --no-pager${WHITE}\n"
  exit 1
}

atualizar_env_backend() {
  banner
  printf "${WHITE} >> Atualizando WACALLS_CHAT_* no .env do backend...\n"
  echo

  local env_path url
  env_path="$(backend_env_path)"
  url="http://127.0.0.1:${wacalls_port}"

  if [ ! -f "${env_path}" ]; then
    printf "${RED} >> ERRO: .env do backend não encontrado: ${env_path}${WHITE}\n"
    exit 1
  fi

  set_env_kv() {
    local key="$1" value="$2" file="$3"
    if grep -qE "^${key}=" "${file}"; then
      sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
    else
      echo "${key}=${value}" >> "${file}"
    fi
  }

  # Bloco comentário se ainda não houver
  if ! grep -qE '^WACALLS_CHAT_URL=' "${env_path}"; then
    {
      echo ""
      echo "# WaCalls Chat (WhatsApp Plus)"
    } >> "${env_path}"
  fi

  set_env_kv "WACALLS_CHAT_URL" "${url}" "${env_path}"
  set_env_kv "WACALLS_CHAT_EMAIL" "${wacalls_admin_email}" "${env_path}"
  set_env_kv "WACALLS_CHAT_PASSWORD" "${wacalls_admin_password}" "${env_path}"

  printf "${GREEN} >> Backend .env: WACALLS_CHAT_URL=${url}${WHITE}\n"
  printf "${GREEN} >> Credenciais serviço: ${wacalls_admin_email} / (senha configurada)${WHITE}\n"
  sleep 1
}

reiniciar_backend() {
  banner
  printf "${WHITE} >> Reiniciando backend para carregar WACALLS_CHAT_*...\n"
  echo

  sudo su - deploy <<RESTART_BACKEND
if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
  export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
else
  export PATH=/usr/bin:/usr/local/bin:\$PATH
fi
pm2 reload ${empresa}-backend 2>/dev/null || pm2 restart ${empresa}-backend 2>/dev/null || pm2 restart all || true
RESTART_BACKEND

  printf "${GREEN} >> Backend reiniciado.${WHITE}\n"
  sleep 1
}

persistir_flag_instalacao() {
  local vars_file=""
  if [ -f "$ARQUIVO_VARIAVEIS" ]; then
    vars_file="$ARQUIVO_VARIAVEIS"
  elif [ -f "/root/crm-setup/${ARQUIVO_VARIAVEIS}" ]; then
    vars_file="/root/crm-setup/${ARQUIVO_VARIAVEIS}"
  fi
  [ -z "${vars_file}" ] && return 0

  if grep -qE '^instalar_wacalls_chat=' "${vars_file}"; then
    sed -i 's|^instalar_wacalls_chat=.*|instalar_wacalls_chat=s|' "${vars_file}"
  else
    echo "instalar_wacalls_chat=s" >> "${vars_file}"
  fi
  if grep -qE '^wacalls_port=' "${vars_file}"; then
    sed -i "s|^wacalls_port=.*|wacalls_port=${wacalls_port}|" "${vars_file}"
  else
    echo "wacalls_port=${wacalls_port}" >> "${vars_file}"
  fi
}

salvar_credenciais() {
  local cred="/root/${empresa}-wacalls-credenciais.txt"
  cat > "${cred}" <<EOF
empresa=${empresa}
url=http://127.0.0.1:${wacalls_port}
usuario=${wacalls_admin_email}
senha=${wacalls_admin_password}
servico=$(service_name)
diretorio=$(app_dir)
EOF
  chmod 600 "${cred}"
}

main() {
  carregar_variaveis

  if [ "${REBUILD_ONLY}" = "s" ]; then
    banner
    printf "${WHITE} >> Modo rebuild-only (atualizador remoto)...${WHITE}\n"
    echo
    if [ ! -d "$(app_dir)" ]; then
      printf "${YELLOW} >> Pasta wacalls-chat ausente — pulando rebuild.${WHITE}\n"
      exit 0
    fi
    if [ ! -f "/etc/systemd/system/$(service_name).service" ] && [ "${instalar_wacalls_chat}" != "s" ]; then
      printf "${YELLOW} >> Serviço ainda não instalado — pulando rebuild.${WHITE}\n"
      exit 0
    fi
    build_wacalls || trata_erro "build_wacalls"
    systemctl restart "$(service_name)" || trata_erro "restart_wacalls"
    validar_servico || trata_erro "validar_servico"
    printf "${GREEN} >> Rebuild do wacalls-chat concluído.${WHITE}\n"
    exit 0
  fi

  configurar_env_wacalls || trata_erro "configurar_env_wacalls"
  build_wacalls || trata_erro "build_wacalls"
  configurar_systemd || trata_erro "configurar_systemd"
  validar_servico || trata_erro "validar_servico"
  atualizar_env_backend || trata_erro "atualizar_env_backend"
  reiniciar_backend || trata_erro "reiniciar_backend"
  persistir_flag_instalacao
  salvar_credenciais

  banner
  printf "${GREEN} >> Instalação do wacalls-chat concluída!${WHITE}\n"
  echo
  printf "${WHITE} >> URL interna:   ${YELLOW}http://127.0.0.1:${wacalls_port}${WHITE}\n"
  printf "${WHITE} >> Serviço:       ${YELLOW}$(service_name)${WHITE}\n"
  printf "${WHITE} >> Diretório:     ${YELLOW}$(app_dir)${WHITE}\n"
  printf "${WHITE} >> Admin:         ${YELLOW}${wacalls_admin_email} / ${wacalls_admin_password}${WHITE}\n"
  printf "${WHITE} >> Credenciais:   ${YELLOW}/root/${empresa}-wacalls-credenciais.txt${WHITE}\n"
  printf "${WHITE} >> Backend .env:  ${YELLOW}WACALLS_CHAT_URL / EMAIL / PASSWORD${WHITE}\n"
  echo
  printf "${YELLOW} >> Troque a senha do admin após o primeiro acesso ao painel WaCalls.${WHITE}\n"
  echo
  sleep 2
}

main
