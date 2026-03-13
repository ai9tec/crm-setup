#!/bin/bash

GREEN='\033[1;32m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'

# Variaveis Padrão
ARCH=$(uname -m)
UBUNTU_VERSION=$(lsb_release -sr)
ARQUIVO_VARIAVEIS="VARIAVEIS_INSTALACAO"
ARQUIVO_ETAPAS="ETAPA_INSTALACAO"
FFMPEG="$(pwd)/ffmpeg.x"
FFMPEG_DIR="$(pwd)/ffmpeg"
ip_atual=$(curl -s http://checkip.amazonaws.com)
jwt_secret=$(openssl rand -base64 32)
jwt_refresh_secret=$(openssl rand -base64 32)

if [ "$EUID" -ne 0 ]; then
  echo
  printf "${WHITE} >> Este script precisa ser executado como root ${RED}ou com privilégios de superusuário${WHITE}.\n"
  echo
  sleep 2
  exit 1
fi

# Branch opcional por parâmetro (sobrescreve repo_branch do VARIAVEIS_INSTALACAO)
BRANCH_PARAM="$1"

# Função para manipular erros e encerrar o script
trata_erro() {
  printf "${RED}Erro encontrado na etapa $1. Encerrando o script.${WHITE}\n"
  exit 1
}

# Carregar variáveis
dummy_carregar_variaveis() {
  if [ -f $ARQUIVO_VARIAVEIS ]; then
    source $ARQUIVO_VARIAVEIS
  else
    empresa="multiflow"
    nome_titulo="MultiFlow"
  fi
}

# Função para verificar e instalar Node.js 20.19.4
verificar_e_instalar_nodejs() {
  printf "${WHITE} >> Verificando versão do Node.js instalada...\n"
  
  # Verificar se o Node.js está instalado e qual versão
  if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v | sed 's/v//')
    printf "${BLUE} >> Versão atual do Node.js: ${NODE_VERSION}\n"
    
    # Verificar se a versão é diferente de 20.19.4
    if [ "$NODE_VERSION" != "20.19.4" ]; then
      printf "${YELLOW} >> Versão do Node.js diferente de 20.19.4. Iniciando atualização...\n"
      
      {
        echo "=== Removendo Node.js antigo (apt) ==="
        sudo apt remove -y nodejs npm || true
        sudo apt purge -y nodejs || true
        sudo apt autoremove -y || true

        echo "=== Limpando links antigos ==="
        sudo rm -f /usr/bin/node || true
        sudo rm -f /usr/bin/npm || true
        sudo rm -f /usr/bin/npx || true

        echo "=== Removendo repositórios antigos do NodeSource ==="
        sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/nodesource*.list 2>/dev/null || true

        echo "=== Instalando Node.js temporário para ter npm ==="
        # Tenta primeiro com Node.js 22.x (LTS atual), depois 20.x
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>&1 | grep -v "does not have a Release file" || \
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - 2>&1 | grep -v "does not have a Release file" || true
        
        sudo apt-get update -y 2>&1 | grep -v "does not have a Release file" | grep -v "Key is stored in legacy" || true
        sudo apt install -y nodejs

        echo "=== Instalando gerenciador 'n' ==="
        sudo npm install -g n

        echo "=== Instalando Node.js 20.19.4 ==="
        sudo n 20.19.4

        echo "=== Ajustando links globais para a versão correta ==="
        if [ -f /usr/local/n/versions/node/20.19.4/bin/node ]; then
          sudo ln -sf /usr/local/n/versions/node/20.19.4/bin/node /usr/bin/node
          sudo ln -sf /usr/local/n/versions/node/20.19.4/bin/npm /usr/bin/npm
          sudo ln -sf /usr/local/n/versions/node/20.19.4/bin/npx /usr/bin/npx 2>/dev/null || true
        fi

        # Atualiza o PATH no perfil do sistema
        if ! grep -q "/usr/local/n/versions/node" /etc/profile 2>/dev/null; then
          echo 'export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH' | sudo tee -a /etc/profile > /dev/null
        fi

        echo "=== Versões instaladas ==="
        export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH
        node -v
        npm -v

        printf "${GREEN}✅ Instalação finalizada! Node.js 20.19.4 está ativo.\n"
        
      } || trata_erro "verificar_e_instalar_nodejs"
      
    else
      printf "${GREEN} >> Node.js já está na versão correta (20.19.4). Prosseguindo...\n"
    fi
  else
    printf "${YELLOW} >> Node.js não encontrado. Iniciando instalação...\n"
    
    {
      echo "=== Removendo repositórios antigos do NodeSource ==="
      sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
      sudo rm -f /etc/apt/sources.list.d/nodesource*.list 2>/dev/null || true

      echo "=== Instalando Node.js temporário para ter npm ==="
      # Tenta primeiro com Node.js 22.x (LTS atual), depois 20.x
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>&1 | grep -v "does not have a Release file" || \
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - 2>&1 | grep -v "does not have a Release file" || true
      
      sudo apt-get update -y 2>&1 | grep -v "does not have a Release file" | grep -v "Key is stored in legacy" || true
      sudo apt install -y nodejs

      echo "=== Instalando gerenciador 'n' ==="
      sudo npm install -g n

      echo "=== Instalando Node.js 20.19.4 ==="
      sudo n 20.19.4

      echo "=== Ajustando links globais para a versão correta ==="
      if [ -f /usr/local/n/versions/node/20.19.4/bin/node ]; then
        sudo ln -sf /usr/local/n/versions/node/20.19.4/bin/node /usr/bin/node
        sudo ln -sf /usr/local/n/versions/node/20.19.4/bin/npm /usr/bin/npm
        sudo ln -sf /usr/local/n/versions/node/20.19.4/bin/npx /usr/bin/npx 2>/dev/null || true
      fi

      # Atualiza o PATH no perfil do sistema
      if ! grep -q "/usr/local/n/versions/node" /etc/profile 2>/dev/null; then
        echo 'export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH' | sudo tee -a /etc/profile > /dev/null
      fi

      echo "=== Versões instaladas ==="
      export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH
      node -v
      npm -v

      printf "${GREEN}✅ Instalação finalizada! Node.js 20.19.4 está ativo.\n"
      
    } || trata_erro "verificar_e_instalar_nodejs"
  fi
  
  sleep 2
}

# Funções de atualização
backup_app_atualizar() {

  dummy_carregar_variaveis
  
  # Verifica se a variável empresa está definida
  if [ -z "${empresa}" ]; then
    printf "${RED} >> ERRO: Variável 'empresa' não está definida!\n${WHITE}"
    exit 1
  fi
  
  # Verifica se o arquivo .env existe
  ENV_FILE="/home/deploy/${empresa}/backend/.env"
  if [ ! -f "$ENV_FILE" ]; then
    printf "${YELLOW} >> AVISO: Arquivo .env não encontrado em $ENV_FILE. Pulando backup.\n${WHITE}"
    return 0
  fi
  
  source "$ENV_FILE"
  {
    printf "${WHITE} >> Fazendo backup do banco de dados da empresa ${empresa}...\n"
    db_password=$(grep "DB_PASS=" "$ENV_FILE" | cut -d '=' -f2)
    [ ! -d "/home/deploy/backups" ] && mkdir -p "/home/deploy/backups"
    backup_file="/home/deploy/backups/${empresa}_$(date +%d-%m-%Y_%Hh).sql"
    PGPASSWORD="${db_password}" pg_dump -U ${empresa} -h localhost ${empresa} >"${backup_file}"
    printf "${GREEN} >> Backup do banco de dados ${empresa} concluído. Arquivo de backup: ${backup_file}\n"
    sleep 2
  } || trata_erro "backup_app_atualizar"

# Dados do Whaticket
TOKEN="u"
QUEUE_ID="15"
USER_ID=""
MENSAGEM="🚨 INICIANDO Atualização do ${nome_titulo}"

# Lista de números
NUMEROS=("${numero_suporte}" "5")

# Enviar para cada número
for NUMERO in "${NUMEROS[@]}"; do
  curl -s -X POST https://api \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "number": "'"$NUMERO"'",
      "body": "'"$MENSAGEM"'",
      "userId": "'"$USER_ID"'",
      "queueId": "'"$QUEUE_ID"'",
      "sendSignature": false,
      "closeTicket": true
    }'
done
  
}

otimiza_banco_atualizar() {
  printf "${WHITE} >> Realizando Manutenção do Banco de Dados da empresa ${empresa}... \n"
  
  # Verifica se a variável empresa está definida
  if [ -z "${empresa}" ]; then
    printf "${RED} >> ERRO: Variável 'empresa' não está definida!\n${WHITE}"
    exit 1
  fi
  
  # Verifica se o arquivo .env existe
  ENV_FILE="/home/deploy/${empresa}/backend/.env"
  if [ ! -f "$ENV_FILE" ]; then
    printf "${YELLOW} >> AVISO: Arquivo .env não encontrado em $ENV_FILE. Pulando otimização do banco.\n${WHITE}"
    return 0
  fi
  
  {
    db_password=$(grep "DB_PASS=" "$ENV_FILE" | cut -d '=' -f2)
    if [ -z "$db_password" ]; then
      printf "${YELLOW} >> AVISO: Senha do banco não encontrada. Pulando otimização.\n${WHITE}"
      return 0
    fi
    sudo su - root <<EOF
    PGPASSWORD="$db_password" vacuumdb -U "${empresa}" -h localhost -d "${empresa}" --full --analyze
    PGPASSWORD="$db_password" psql -U ${empresa} -h 127.0.0.1 -d ${empresa} -c "REINDEX DATABASE ${empresa};"
    PGPASSWORD="$db_password" psql -U ${empresa} -h 127.0.0.1 -d ${empresa} -c "ANALYZE;"
EOF
    sleep 2
  } || trata_erro "otimiza_banco_atualizar"
}

baixa_codigo_atualizar() {
  # Carrega variáveis (empresa, repo_branch, etc.) do arquivo da instalação
  dummy_carregar_variaveis
  [ -n "$BRANCH_PARAM" ] && repo_branch="$BRANCH_PARAM"
  [ -n "$BRANCH_PARAM" ] && printf "${WHITE} >> Usando branch informada por parâmetro: ${BLUE}%s${WHITE}\n" "$repo_branch"
  if [ -z "${empresa}" ]; then
    printf "${RED} >> ERRO: Variável 'empresa' não está definida! Verifique o arquivo VARIAVEIS_INSTALACAO.\n${WHITE}"
    exit 1
  fi
  
  # Verifica se o diretório existe
  if [ ! -d "/home/deploy/${empresa}" ]; then
    printf "${RED} >> ERRO: Diretório /home/deploy/${empresa} não existe!\n${WHITE}"
    exit 1
  fi
  
  printf "${WHITE} >> Recuperando Permissões da empresa ${empresa}... \n"
  sleep 2
  chown deploy -R /home/deploy/${empresa}
  chmod 775 -R /home/deploy/${empresa}

  sleep 2

  printf "${WHITE} >> Parando Instancias... \n"
  sleep 2
  sudo su - deploy <<STOPPM2
  # Configura PATH para Node.js e PM2
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  pm2 stop all || true
STOPPM2

  sleep 2

  otimiza_banco_atualizar

  printf "${WHITE} >> Atualizando a Aplicação da Empresa ${empresa}... \n"
  sleep 2

  # Lê apenas SERVER_PORT do .env (evita source: .env pode ter TOKEN etc. que quebram no shell)
  frontend_port=$(grep -E '^SERVER_PORT=' "/home/deploy/${empresa}/frontend/.env" 2>/dev/null | cut -d '=' -f2- | tr -d '\r"' || true)
  frontend_port=${frontend_port:-3000}
  sudo su - deploy <<UPDATEAPP
  # Configura PATH para Node.js e PM2
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  
  APP_DIR="/home/deploy/${empresa}"
  BACKEND_DIR="\${APP_DIR}/backend"
  FRONTEND_DIR="\${APP_DIR}/frontend"
  
  # Verifica se os diretórios existem
  if [ ! -d "\$APP_DIR" ]; then
    echo "ERRO: Diretório da aplicação não existe: \$APP_DIR"
    exit 1
  fi
  
  printf "${WHITE} >> Atualizando Backend...\n"
  echo
  cd "\$APP_DIR"
  
  # Usa a branch definida na instalação (VARIAVEIS_INSTALACAO -> repo_branch)
  echo "Atualizando branch: ${repo_branch:-main}"
  git fetch origin
  git reset --hard origin/${repo_branch:-main}
  
  if [ ! -d "\$BACKEND_DIR" ]; then
    echo "ERRO: Diretório do backend não existe: \$BACKEND_DIR"
    exit 1
  fi
  
  cd "\$BACKEND_DIR"
  
  if [ ! -f "package.json" ]; then
    echo "ERRO: package.json não encontrado em \$BACKEND_DIR"
    exit 1
  fi
  
  npm prune --force > /dev/null 2>&1
  export PUPPETEER_SKIP_DOWNLOAD=true
  rm -rf node_modules 2>/dev/null || true
  rm -f package-lock.json 2>/dev/null || true
  rm -rf dist 2>/dev/null || true
  npm install --force
  npm install puppeteer-core --force
  npm i glob
  npm run build
  sleep 2
  printf "${WHITE} >> Atualizando Banco da empresa ${empresa}...\n"
  echo
  sleep 2
  npx sequelize db:migrate
  sleep 2
  printf "${WHITE} >> Atualizando Frontend da ${empresa}...\n"
  echo
  sleep 2
  
  if [ ! -d "\$FRONTEND_DIR" ]; then
    echo "ERRO: Diretório do frontend não existe: \$FRONTEND_DIR"
    exit 1
  fi
  
  cd "\$FRONTEND_DIR"
  
  if [ ! -f "package.json" ]; then
    echo "ERRO: package.json não encontrado em \$FRONTEND_DIR"
    exit 1
  fi
  
  npm prune --force > /dev/null 2>&1
  rm -rf node_modules 2>/dev/null || true
  rm -f package-lock.json 2>/dev/null || true
  npm install --force
  
  if [ -f "server.js" ]; then
    sed -i 's/3000/'"$frontend_port"'/g' server.js
  fi
  
  NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" npm run build
  sleep 2
  pm2 flush
  pm2 reset all
  pm2 restart all
  pm2 save
  pm2 startup
UPDATEAPP

  # Atualizar API Oficial se estiver instalada (atualização completa: npm install + build + migrate)
  if [ "${instalar_api_oficial}" = "s" ] && [ -d "/home/deploy/${empresa}/api_oficial" ]; then
    printf "${WHITE} >> Atualizando API Oficial...\n"
    sleep 2
    sudo su - deploy <<API_OFICIAL
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  cd /home/deploy/${empresa}/api_oficial
  npm install
  npx prisma generate
  npm run build
  npx prisma migrate deploy
  npx prisma generate client
  pm2 restart all
  pm2 save
API_OFICIAL
    if [ $? -ne 0 ]; then
      printf "${RED} >> Erro ao atualizar API Oficial. Verifique os logs.${WHITE}\n"
      exit 1
    fi
    printf "${GREEN} >> API Oficial atualizada.\n${WHITE}"
    sleep 2
  fi

  sudo su - root <<EOF
    if systemctl is-active --quiet nginx; then
      sudo systemctl restart nginx
    elif systemctl is-active --quiet traefik; then
      sudo systemctl restart traefik.service
    else
      printf "${GREEN}Nenhum serviço de proxy (Nginx ou Traefik) está em execução.${WHITE}"
    fi
EOF

  echo
  printf "${WHITE} >> Atualização do ${nome_titulo} concluída...\n"
  echo
  sleep 5

# Dados do Whaticket
TOKEN="u"
QUEUE_ID="15"
USER_ID=""
MENSAGEM="🚨 Atualização do ${nome_titulo} FINALIZADA"

# Lista de números
NUMEROS=("${numero_suporte}" "55")

# Enviar para cada número
for NUMERO in "${NUMEROS[@]}"; do
  curl -s -X POST https://api \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "number": "'"$NUMERO"'",
      "body": "'"$MENSAGEM"'",
      "userId": "'"$USER_ID"'",
      "queueId": "'"$QUEUE_ID"'",
      "sendSignature": false,
      "closeTicket": true
    }'
done

}

# Execução automática do fluxo de atualização
verificar_e_instalar_nodejs
backup_app_atualizar
baixa_codigo_atualizar
