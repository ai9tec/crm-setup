#!/bin/bash
# Repara ffmpeg na VPS (libavdevice.so ausente) e reinicia API de transcrição.
# Uso: sudo ./tools/reparar_ffmpeg.sh [empresa]
# Exemplo: sudo ./tools/reparar_ffmpeg.sh chat

set -e

GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'

if [ "$EUID" -ne 0 ]; then
  echo "Execute como root: sudo $0 [empresa]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/garantir_ffmpeg.sh
source "${SCRIPT_DIR}/lib/garantir_ffmpeg.sh"

empresa="${1:-}"
ARQUIVO_VARIAVEIS="${SCRIPT_DIR}/VARIAVEIS_INSTALACAO"

if [ -z "$empresa" ] && [ -f "$ARQUIVO_VARIAVEIS" ]; then
  # shellcheck source=/dev/null
  source "$ARQUIVO_VARIAVEIS"
fi

empresa="${empresa:-multiflow}"

printf "${WHITE} >> Reparando ffmpeg...${WHITE}\n"
garantir_ffmpeg || exit 1

# Substitui /usr/bin/ffmpeg quebrado pelo binário funcional (código legado usa PATH padrão)
if [ -x /usr/local/bin/ffmpeg ] && ffmpeg_test_funcional /usr/local/bin/ffmpeg; then
  cp -f /usr/local/bin/ffmpeg /usr/bin/ffmpeg
  [ -x /usr/local/bin/ffprobe ] && cp -f /usr/local/bin/ffprobe /usr/bin/ffprobe || true
  FFMPEG_PATH="/usr/bin/ffmpeg"
  printf "${GREEN} >> /usr/bin/ffmpeg atualizado com build funcional.${WHITE}\n"
fi

transcricao_dir="/home/deploy/${empresa}/api_transcricao"
env_file="${transcricao_dir}/.env"

if [ -f "$env_file" ]; then
  if grep -q "^FFMPEG_PATH=" "$env_file"; then
    sed -i "s|^FFMPEG_PATH=.*|FFMPEG_PATH=${FFMPEG_PATH}|" "$env_file"
  else
    echo "FFMPEG_PATH=${FFMPEG_PATH}" >> "$env_file"
  fi
  printf "${GREEN} >> FFMPEG_PATH=${FFMPEG_PATH} em ${env_file}${WHITE}\n"
else
  printf "${YELLOW} >> .env não encontrado em ${transcricao_dir} (configure FFMPEG_PATH manualmente).${WHITE}\n"
fi

pm2_name="${empresa}-api_transcricao"
if sudo -u deploy pm2 describe "$pm2_name" &>/dev/null; then
  printf "${WHITE} >> Reiniciando PM2 ${pm2_name}...${WHITE}\n"
  sudo -u deploy env FFMPEG_PATH="${FFMPEG_PATH}" pm2 restart "$pm2_name" --update-env
  sudo -u deploy pm2 save
  printf "${GREEN} >> Concluído. Teste a transcrição novamente.${WHITE}\n"
else
  printf "${YELLOW} >> Processo PM2 '${pm2_name}' não encontrado. Reinicie a API de transcrição manualmente.${WHITE}\n"
fi
