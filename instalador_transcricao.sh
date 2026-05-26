#!/bin/bash

GREEN='\033[1;32m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'

ARQUIVO_VARIAVEIS="VARIAVEIS_INSTALACAO"
default_transcricao_port=4002

if [ "$EUID" -ne 0 ]; then
  echo
  printf "${WHITE} >> Este script precisa ser executado como root ${RED}ou com privilégios de superusuário${WHITE}.\n"
  echo
  sleep 2
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
  echo "║              INSTALADOR API DE TRANSCRIÇÃO                   ║"
  echo "║                    MultiFlow System                          ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  printf "${WHITE}"
  echo
}

carregar_variaveis() {
  if [ -f "$ARQUIVO_VARIAVEIS" ]; then
    # shellcheck source=/dev/null
    source "$ARQUIVO_VARIAVEIS"
  else
    printf "${RED} >> ERRO: Arquivo VARIAVEIS_INSTALACAO não encontrado. Execute pelo instalador principal.${WHITE}\n"
    exit 1
  fi
  empresa="${empresa:-multiflow}"
}

instalar_deps_sistema() {
  banner
  printf "${WHITE} >> Instalando dependências do sistema (ffmpeg, Python)...\n"
  echo

  apt-get update -qq

  if ffmpeg -version &>/dev/null 2>&1; then
    printf "${GREEN} >> ffmpeg já instalado${WHITE}\n"
  else
    printf "${WHITE} >> Instalando ffmpeg...${WHITE}\n"
    apt-get install -y ffmpeg
  fi

  apt-get install -y python3 python3-pip python3-venv flac

  if ! command -v pm2 &>/dev/null; then
    printf "${WHITE} >> Instalando PM2...${WHITE}\n"
    npm install -g pm2
  fi

  printf "${GREEN} >> Dependências do sistema instaladas.${WHITE}\n"
  sleep 2
}

configurar_env_transcricao() {
  banner
  printf "${WHITE} >> Configurando .env da API de Transcrição...\n"
  echo

  local transcricao_dir="/home/deploy/${empresa}/api_transcricao"

  if [ ! -d "${transcricao_dir}" ]; then
    printf "${RED} >> ERRO: Diretório não encontrado: ${transcricao_dir}${WHITE}\n"
    printf "${YELLOW} >> Clone o repositório antes de instalar a transcrição.${WHITE}\n"
    exit 1
  fi

  chown -R deploy:deploy "${transcricao_dir}"

  sudo -u deploy cat > "${transcricao_dir}/.env" <<EOF
PORT=${default_transcricao_port}
EOF

  printf "${GREEN} >> .env configurado (PORT=${default_transcricao_port}).${WHITE}\n"
  sleep 2
}

instalar_transcricao() {
  banner
  printf "${WHITE} >> Instalando API de Transcrição (venv + PM2)...\n"
  echo

  local transcricao_dir="/home/deploy/${empresa}/api_transcricao"
  local pm2_name="${empresa}-api_transcricao"

  if [ ! -f "${transcricao_dir}/main.py" ]; then
    printf "${RED} >> ERRO: main.py não encontrado em ${transcricao_dir}${WHITE}\n"
    exit 1
  fi

  chown -R deploy:deploy "${transcricao_dir}"

  sudo su - deploy <<INSTALL_TRANSCRICAO
set -e
if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
  export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
else
  export PATH=/usr/bin:/usr/local/bin:\$PATH
fi

cd ${transcricao_dir}

printf "${WHITE} >> Criando ambiente virtual Python...${WHITE}\n"
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

printf "${WHITE} >> Configurando PM2 (${pm2_name})...${WHITE}\n"
pm2 delete ${pm2_name} 2>/dev/null || true
pm2 start main.py --name ${pm2_name} --interpreter ./venv/bin/python3
pm2 save

printf "${GREEN} >> API de Transcrição iniciada no PM2.${WHITE}\n"
INSTALL_TRANSCRICAO
}

validar_servico() {
  banner
  printf "${WHITE} >> Validando API de Transcrição...\n"
  echo

  sleep 3

  local max_tentativas=10
  local tentativa=0

  while [ "$tentativa" -lt "$max_tentativas" ]; do
    if curl -sf "http://127.0.0.1:${default_transcricao_port}/" >/dev/null 2>&1; then
      printf "${GREEN} >> API de Transcrição respondendo em http://127.0.0.1:${default_transcricao_port}/${WHITE}\n"
      sleep 2
      return 0
    fi
    tentativa=$((tentativa + 1))
    sleep 2
  done

  printf "${RED} >> ERRO: API de Transcrição não respondeu após ${max_tentativas} tentativas.${WHITE}\n"
  printf "${YELLOW} >> Verifique: pm2 logs ${empresa}-api_transcricao${WHITE}\n"
  exit 1
}

atualizar_env_backend() {
  banner
  printf "${WHITE} >> Atualizando TRANSCRIBE_URL no .env do backend...\n"
  echo

  local backend_env_path="/home/deploy/${empresa}/backend/.env"
  local transcribe_url="TRANSCRIBE_URL=http://127.0.0.1:${default_transcricao_port}"

  if [ ! -f "${backend_env_path}" ]; then
    printf "${RED} >> ERRO: .env do backend não encontrado: ${backend_env_path}${WHITE}\n"
    exit 1
  fi

  if grep -q "^TRANSCRIBE_URL=" "${backend_env_path}"; then
    sed -i "s|^TRANSCRIBE_URL=.*|${transcribe_url}|" "${backend_env_path}"
  else
    echo "${transcribe_url}" >> "${backend_env_path}"
  fi

  printf "${GREEN} >> TRANSCRIBE_URL configurado: http://127.0.0.1:${default_transcricao_port}${WHITE}\n"
  sleep 2
}

reiniciar_backend() {
  banner
  printf "${WHITE} >> Reiniciando backend para carregar TRANSCRIBE_URL...\n"
  echo

  sudo su - deploy <<RESTART_BACKEND
if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
  export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
else
  export PATH=/usr/bin:/usr/local/bin:\$PATH
fi
pm2 reload ${empresa}-backend 2>/dev/null || pm2 restart ${empresa}-backend 2>/dev/null || true
RESTART_BACKEND

  printf "${GREEN} >> Backend reiniciado.${WHITE}\n"
  sleep 2
}

main() {
  carregar_variaveis
  instalar_deps_sistema || trata_erro "instalar_deps_sistema"
  configurar_env_transcricao || trata_erro "configurar_env_transcricao"
  instalar_transcricao || trata_erro "instalar_transcricao"
  validar_servico || trata_erro "validar_servico"
  atualizar_env_backend || trata_erro "atualizar_env_backend"
  reiniciar_backend || trata_erro "reiniciar_backend"

  banner
  printf "${GREEN} >> Instalação da API de Transcrição concluída com sucesso!${WHITE}\n"
  echo
  printf "${WHITE} >> URL interna: ${YELLOW}http://127.0.0.1:${default_transcricao_port}${WHITE}\n"
  printf "${WHITE} >> PM2: ${YELLOW}${empresa}-api_transcricao${WHITE}\n"
  echo
  sleep 3
}

main
