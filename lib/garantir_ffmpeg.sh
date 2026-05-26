#!/bin/bash
# Repara ou instala ffmpeg funcional (evita libavdevice.so.* ausente).
# Uso: source lib/garantir_ffmpeg.sh && garantir_ffmpeg

garantir_ffmpeg__GREEN='\033[1;32m'
garantir_ffmpeg__YELLOW='\033[1;33m'
garantir_ffmpeg__RED='\033[1;31m'
garantir_ffmpeg__WHITE='\033[1;37m'

ffmpeg_test_funcional() {
  local bin="${1:-ffmpeg}"
  command -v "$bin" >/dev/null 2>&1 || return 1

  local stderr_file
  stderr_file=$(mktemp)
  if ! "$bin" -hide_banner -version 2>"$stderr_file" >/dev/null; then
    rm -f "$stderr_file"
    return 1
  fi
  if grep -qi "error while loading shared libraries" "$stderr_file" 2>/dev/null; then
    rm -f "$stderr_file"
    return 1
  fi
  rm -f "$stderr_file"

  stderr_file=$(mktemp)
  if ! "$bin" -hide_banner -f lavfi -i anullsrc=d=0.1 -f null - 2>"$stderr_file" >/dev/null; then
    if grep -qi "error while loading shared libraries\|No such file or directory" "$stderr_file" 2>/dev/null; then
      rm -f "$stderr_file"
      return 1
    fi
  fi
  rm -f "$stderr_file"
  return 0
}

instalar_ffmpeg_estatico_btbN() {
  local ARCH
  ARCH=$(uname -m)
  local asset_url=""
  local FFMPEG_WORK
  FFMPEG_WORK=$(mktemp -d)

  if [ "$ARCH" = "x86_64" ]; then
    asset_url=$(curl -sL https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest \
      | grep -o '"browser_download_url": "[^"]*linux64-gpl[^"]*\.tar\.xz"' \
      | head -n1 \
      | cut -d'"' -f4)
  elif [ "$ARCH" = "aarch64" ]; then
    asset_url=$(curl -sL https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest \
      | grep -o '"browser_download_url": "[^"]*linuxarm64-gpl[^"]*\.tar\.xz"' \
      | head -n1 \
      | cut -d'"' -f4)
  else
    printf "${garantir_ffmpeg__RED} >> Arquitetura não suportada para ffmpeg estático: ${ARCH}${garantir_ffmpeg__WHITE}\n"
    return 1
  fi

  if [ -z "$asset_url" ]; then
    printf "${garantir_ffmpeg__RED} >> Não foi possível obter URL do build estático do ffmpeg.${garantir_ffmpeg__WHITE}\n"
    return 1
  fi

  local FFMPEG_FILE="${asset_url##*/}"
  printf "${garantir_ffmpeg__WHITE} >> Baixando ffmpeg estático: ${FFMPEG_FILE}...${garantir_ffmpeg__WHITE}\n"

  if ! wget -q "$asset_url" -O "${FFMPEG_WORK}/${FFMPEG_FILE}"; then
    printf "${garantir_ffmpeg__RED} >> Falha no download do ffmpeg.${garantir_ffmpeg__WHITE}\n"
    rm -rf "$FFMPEG_WORK"
    return 1
  fi

  tar -xf "${FFMPEG_WORK}/${FFMPEG_FILE}" -C "$FFMPEG_WORK" >/dev/null 2>&1
  local extracted_dir
  extracted_dir=$(tar -tf "${FFMPEG_WORK}/${FFMPEG_FILE}" | head -1 | cut -d/ -f1)

  if [ -z "$extracted_dir" ] || [ ! -f "${FFMPEG_WORK}/${extracted_dir}/bin/ffmpeg" ]; then
    printf "${garantir_ffmpeg__RED} >> Pacote ffmpeg extraído em formato inesperado.${garantir_ffmpeg__WHITE}\n"
    rm -rf "$FFMPEG_WORK"
    return 1
  fi

  cp -f "${FFMPEG_WORK}/${extracted_dir}/bin/ffmpeg" /usr/local/bin/ffmpeg
  cp -f "${FFMPEG_WORK}/${extracted_dir}/bin/ffprobe" /usr/local/bin/ffprobe 2>/dev/null || true
  chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe 2>/dev/null || chmod +x /usr/local/bin/ffmpeg

  rm -rf "$FFMPEG_WORK"
  FFMPEG_PATH="/usr/local/bin/ffmpeg"
  export FFMPEG_PATH
  return 0
}

garantir_ffmpeg() {
  FFMPEG_PATH="${FFMPEG_PATH:-}"

  if [ -n "$FFMPEG_PATH" ] && ffmpeg_test_funcional "$FFMPEG_PATH"; then
    printf "${garantir_ffmpeg__GREEN} >> ffmpeg OK: ${FFMPEG_PATH}${garantir_ffmpeg__WHITE}\n"
    export FFMPEG_PATH
    return 0
  fi

  if ffmpeg_test_funcional /usr/local/bin/ffmpeg; then
    FFMPEG_PATH="/usr/local/bin/ffmpeg"
    export FFMPEG_PATH
    printf "${garantir_ffmpeg__GREEN} >> ffmpeg OK: ${FFMPEG_PATH}${garantir_ffmpeg__WHITE}\n"
    return 0
  fi

  if ffmpeg_test_funcional /usr/bin/ffmpeg; then
    FFMPEG_PATH="/usr/bin/ffmpeg"
    export FFMPEG_PATH
    printf "${garantir_ffmpeg__GREEN} >> ffmpeg OK: ${FFMPEG_PATH}${garantir_ffmpeg__WHITE}\n"
    return 0
  fi

  if ffmpeg_test_funcional ffmpeg; then
    FFMPEG_PATH="$(command -v ffmpeg)"
    export FFMPEG_PATH
    printf "${garantir_ffmpeg__GREEN} >> ffmpeg OK: ${FFMPEG_PATH}${garantir_ffmpeg__WHITE}\n"
    return 0
  fi

  printf "${garantir_ffmpeg__YELLOW} >> ffmpeg quebrado ou ausente. Tentando reparar via apt...${garantir_ffmpeg__WHITE}\n"
  apt-get remove --purge -y ffmpeg 2>/dev/null || true
  apt-get autoremove -y -qq 2>/dev/null || true
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg 2>/dev/null || true

  if ffmpeg_test_funcional /usr/bin/ffmpeg; then
    FFMPEG_PATH="/usr/bin/ffmpeg"
    export FFMPEG_PATH
    printf "${garantir_ffmpeg__GREEN} >> ffmpeg reparado via apt: ${FFMPEG_PATH}${garantir_ffmpeg__WHITE}\n"
    return 0
  fi

  printf "${garantir_ffmpeg__YELLOW} >> apt não resolveu. Instalando build estático em /usr/local/bin/ffmpeg ...${garantir_ffmpeg__WHITE}\n"
  if instalar_ffmpeg_estatico_btbN && ffmpeg_test_funcional "$FFMPEG_PATH"; then
    printf "${garantir_ffmpeg__GREEN} >> ffmpeg estático instalado: ${FFMPEG_PATH}${garantir_ffmpeg__WHITE}\n"
    return 0
  fi

  printf "${garantir_ffmpeg__RED} >> ERRO: Não foi possível instalar um ffmpeg funcional.${garantir_ffmpeg__WHITE}\n"
  return 1
}
