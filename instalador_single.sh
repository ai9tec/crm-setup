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
default_apioficial_port=6000

if [ "$EUID" -ne 0 ]; then
  echo
  printf "${WHITE} >> Este script precisa ser executado como root ${RED}ou com privilégios de superusuário${WHITE}.\n"
  echo
  sleep 2
  exit 1
fi

banner() {
  printf " ${BLUE}"
  printf "\n\n"
  printf "██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██╗    ██╗██╗\n"
  printf "██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██║    ██║██║\n"
  printf "██║██╔██╗ ██║███████    ██║   ███████║██║     ██║     ███████╗██║ █╗ ██║██║\n"
  printf "██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ╚════██║██║███╗██║██║\n"
  printf "██║██║ ╚████║███████╗   ██║   ██║  ██║███████╗███████╗███████╗╚███╔███╔╝███████╗\n"
  printf "╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝ ╚══╝╚══╝ ╚══════╝\n"
  printf "                                INSTALADOR 6.1\n"
  printf "\n\n"
}

# Função para manipular erros e encerrar o script
trata_erro() {
  printf "${RED}Erro encontrado na etapa $1. Encerrando o script.${WHITE}\n"
  salvar_etapa "$1"
  exit 1
}

# Salvar variáveis
salvar_variaveis() {
  echo "subdominio_backend=${subdominio_backend}" >$ARQUIVO_VARIAVEIS
  echo "subdominio_frontend=${subdominio_frontend}" >>$ARQUIVO_VARIAVEIS
  echo "email_deploy=${email_deploy}" >>$ARQUIVO_VARIAVEIS
  echo "empresa=${empresa}" >>$ARQUIVO_VARIAVEIS
  echo "senha_deploy=${senha_deploy}" >>$ARQUIVO_VARIAVEIS
  # echo "subdominio_perfex=${subdominio_perfex}" >>$ARQUIVO_VARIAVEIS
  echo "senha_master=${senha_master}" >>$ARQUIVO_VARIAVEIS
  echo "nome_titulo=${nome_titulo}" >>$ARQUIVO_VARIAVEIS
  echo "numero_suporte=${numero_suporte}" >>$ARQUIVO_VARIAVEIS
  echo "facebook_app_id=${facebook_app_id}" >>$ARQUIVO_VARIAVEIS
  echo "facebook_app_secret=${facebook_app_secret}" >>$ARQUIVO_VARIAVEIS
  echo "repo_url=${repo_url}" >>$ARQUIVO_VARIAVEIS
  echo "repo_branch=${repo_branch}" >>$ARQUIVO_VARIAVEIS
  echo "repo_auth_type=${repo_auth_type}" >>$ARQUIVO_VARIAVEIS
  echo "proxy=${proxy}" >>$ARQUIVO_VARIAVEIS
  echo "backend_port=${backend_port}" >>$ARQUIVO_VARIAVEIS
  echo "frontend_port=${frontend_port}" >>$ARQUIVO_VARIAVEIS
  echo "instalar_api_oficial=${instalar_api_oficial}" >>$ARQUIVO_VARIAVEIS
  if [ "${instalar_api_oficial}" == "s" ] && [ -n "${subdominio_oficial}" ]; then
    echo "subdominio_oficial=${subdominio_oficial}" >>$ARQUIVO_VARIAVEIS
  fi
}

# Carregar variáveis
carregar_variaveis() {
  if [ -f $ARQUIVO_VARIAVEIS ]; then
    source $ARQUIVO_VARIAVEIS
  else
    empresa="multiflow"
    nome_titulo="MultiFlow"
  fi
}

# Salvar etapa concluída
salvar_etapa() {
  echo "$1" >$ARQUIVO_ETAPAS
}

# Carregar última etapa
carregar_etapa() {
  if [ -f $ARQUIVO_ETAPAS ]; then
    etapa=$(cat $ARQUIVO_ETAPAS)
    if [ -z "$etapa" ]; then
      etapa="0"
    fi
  else
    etapa="0"
  fi
}

# Resetar etapas e variáveis
resetar_instalacao() {
  rm -f $ARQUIVO_VARIAVEIS $ARQUIVO_ETAPAS
  printf "${GREEN} >> Instalação resetada! Iniciando uma nova instalação...${WHITE}\n"
  sleep 2
  instalacao_base
}

# Pergunta se deseja continuar ou recomeçar
verificar_arquivos_existentes() {
  if [ -f $ARQUIVO_VARIAVEIS ] && [ -f $ARQUIVO_ETAPAS ]; then
    banner
    printf "${YELLOW} >> Dados de instalação anteriores detectados.\n"
    echo
    carregar_etapa
    if [ "$etapa" -eq 21 ]; then
      printf "${WHITE}>> Instalação já concluída.\n"
      printf "${WHITE}>> Deseja resetar as etapas e começar do zero? (S/N): ${WHITE}\n"
      echo
      read -p "> " reset_escolha
      echo
      reset_escolha=$(echo "${reset_escolha}" | tr '[:lower:]' '[:upper:]')
      if [ "$reset_escolha" == "S" ]; then
        resetar_instalacao
      else
        printf "${GREEN} >> Voltando para o menu principal...${WHITE}\n"
        sleep 2
        menu
      fi
    elif [ "$etapa" -lt 21 ]; then
      printf "${YELLOW} >> Instalação Incompleta Detectada na etapa $etapa. \n"
      printf "${WHITE} >> Deseja continuar de onde parou? (S/N): ${WHITE}\n"
      echo
      read -p "> " escolha
      echo
      escolha=$(echo "${escolha}" | tr '[:lower:]' '[:upper:]')
      if [ "$escolha" == "S" ]; then
        instalacao_base
      else
        printf "${GREEN} >> Voltando ao menu principal...${WHITE}\n"
        printf "${WHITE} >> Caso deseje resetar as etapas, apague os arquivos ETAPAS_INSTALAÇÃO da pasta root...${WHITE}\n"
        sleep 5
        menu
      fi
    fi
  else
    instalacao_base
  fi
}

# Menu de Ferramentas
menu_ferramentas() {
  while true; do
    banner
    printf "${WHITE} Selecione abaixo a ferramenta desejada: \n"
    echo
    printf "   [${BLUE}1${WHITE}] Instalador RabbitMQ\n"
    printf "   [${BLUE}2${WHITE}] Instalar Push Notifications\n"
    printf "   [${BLUE}0${WHITE}] Voltar ao Menu Principal\n"
    echo
    read -p "> " option_tools
    case "${option_tools}" in
    1)
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      RABBIT_SCRIPT="${SCRIPT_DIR}/tools/instalador_rabbit.sh"
      if [ -f "$RABBIT_SCRIPT" ]; then
        printf "${GREEN} >> Executando Instalador RabbitMQ...${WHITE}\n"
        echo
        bash "$RABBIT_SCRIPT"
        echo
        printf "${GREEN} >> Pressione Enter para voltar ao menu de ferramentas...${WHITE}\n"
        read -r
      else
        printf "${RED} >> Erro: Arquivo ${RABBIT_SCRIPT} não encontrado!${WHITE}\n"
        sleep 3
      fi
      ;;
    2)
      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      PUSH_SCRIPT="${SCRIPT_DIR}/tools/instalar_push.sh"
      if [ -f "$PUSH_SCRIPT" ]; then
        printf "${GREEN} >> Executando Instalador Push Notifications...${WHITE}\n"
        echo
        bash "$PUSH_SCRIPT"
        echo
        printf "${GREEN} >> Pressione Enter para voltar ao menu de ferramentas...${WHITE}\n"
        read -r
      else
        printf "${RED} >> Erro: Arquivo ${PUSH_SCRIPT} não encontrado!${WHITE}\n"
        sleep 3
      fi
      ;;
    0)
      return
      ;;
    *)
      printf "${RED}Opção inválida. Tente novamente.${WHITE}"
      sleep 2
      ;;
    esac
  done
}

# Menu principal
menu() {
  while true; do
    banner
    printf "${WHITE} Selecione abaixo a opção desejada: \n"
    echo
    printf "   [${BLUE}1${WHITE}] Instalar ${nome_titulo}\n"
    printf "   [${BLUE}2${WHITE}] Atualizar ${nome_titulo}\n"
    printf "   [${BLUE}3${WHITE}] Instalar Transcrição de Audio Nativa\n"
    printf "   [${BLUE}4${WHITE}] Instalar API Oficial\n"
    printf "   [${BLUE}5${WHITE}] Atualizar API Oficial\n"
    printf "   [${BLUE}0${WHITE}] Sair\n"
    echo
    read -p "> " option
    case "${option}" in
    1)
      verificar_arquivos_existentes
      ;;
    2)
      atualizar_base
      ;;
    3)
      instalar_transcricao_audio_nativa
      ;;
    4)
      instalar_api_oficial
      ;;
    5)
      atualizar_api_oficial
      ;;
    6)
      migrar
      ;;
    10)
      menu
      ;;
    0)
      sair
      ;;
    *)
      printf "${RED}Opção inválida. Tente novamente.${WHITE}"
      sleep 2
      ;;
    esac
  done
}

# Etapa de instalação
instalacao_base() {
  carregar_etapa
  if [ "$etapa" == "0" ]; then
    questoes_dns_base || trata_erro "questoes_dns_base"
    verificar_dns_base || trata_erro "verificar_dns_base"
    questoes_variaveis_base || trata_erro "questoes_variaveis_base"
    define_proxy_base || trata_erro "define_proxy_base"
    define_portas_base || trata_erro "define_portas_base"
    confirma_dados_instalacao_base || trata_erro "confirma_dados_instalacao_base"
    salvar_variaveis || trata_erro "salvar_variaveis"
    salvar_etapa 1
  fi
  if [ "$etapa" -le "1" ]; then
    atualiza_vps_base || trata_erro "atualiza_vps_base"
    salvar_etapa 2
  fi
  if [ "$etapa" -le "2" ]; then
    cria_deploy_base || trata_erro "cria_deploy_base"
    salvar_etapa 3
  fi
  if [ "$etapa" -le "3" ]; then
    config_timezone_base || trata_erro "config_timezone_base"
    salvar_etapa 4
  fi
  if [ "$etapa" -le "4" ]; then
    config_firewall_base || trata_erro "config_firewall_base"
    salvar_etapa 5
  fi
  if [ "$etapa" -le "5" ]; then
    instala_puppeteer_base || trata_erro "instala_puppeteer_base"
    salvar_etapa 6
  fi
  if [ "$etapa" -le "6" ]; then
    instala_ffmpeg_base || trata_erro "instala_ffmpeg_base"
    salvar_etapa 7
  fi
  if [ "$etapa" -le "7" ]; then
    instala_postgres_base || trata_erro "instala_postgres_base"
    salvar_etapa 8
  fi
  if [ "$etapa" -le "8" ]; then
    instala_node_base || trata_erro "instala_node_base"
    salvar_etapa 9
  fi
  if [ "$etapa" -le "9" ]; then
    instala_redis_base || trata_erro "instala_redis_base"
    salvar_etapa 10
  fi
  if [ "$etapa" -le "10" ]; then
    instala_pm2_base || trata_erro "instala_pm2_base"
    salvar_etapa 11
  fi
  if [ "$etapa" -le "11" ]; then
    if [ "${proxy}" == "nginx" ]; then
      instala_nginx_base || trata_erro "instala_nginx_base"
      salvar_etapa 12
    elif [ "${proxy}" == "traefik" ]; then
      instala_traefik_base || trata_erro "instala_traefik_base"
      salvar_etapa 12
    fi
  fi
  if [ "$etapa" -le "12" ]; then
    cria_banco_base || trata_erro "cria_banco_base"
    salvar_etapa 13
  fi
  if [ "$etapa" -le "13" ]; then
    instala_git_base || trata_erro "instala_git_base"
    configura_deploy_key_ssh || trata_erro "configura_deploy_key_ssh"
    salvar_etapa 14
  fi
  if [ "$etapa" -le "14" ]; then
    codifica_clone_base || trata_erro "codifica_clone_base"
    baixa_codigo_base || trata_erro "baixa_codigo_base"
    salvar_etapa 15
  fi
  if [ "$etapa" -le "15" ]; then
    instala_backend_base || trata_erro "instala_backend_base"
    salvar_etapa 16
  fi
  if [ "$etapa" -le "16" ]; then
    instala_frontend_base || trata_erro "instala_frontend_base"
    salvar_etapa 17
  fi
  if [ "$etapa" -le "17" ]; then
    config_cron_base || trata_erro "config_cron_base"
    salvar_etapa 18
  fi
  if [ "$etapa" -le "18" ]; then
    if [ "${proxy}" == "nginx" ]; then
      config_nginx_base || trata_erro "config_nginx_base"
      salvar_etapa 19
    elif [ "${proxy}" == "traefik" ]; then
      config_traefik_base || trata_erro "config_traefik_base"
      salvar_etapa 19
    fi
  fi
  if [ "$etapa" -le "19" ]; then
    config_latencia_base || trata_erro "config_latencia_base"
    salvar_etapa 20
  fi
  if [ "$etapa" -le "20" ]; then
    verificar_dns_apioficial || trata_erro "verificar_dns_apioficial"
    salvar_etapa 21
  fi
  if [ "$etapa" -le "21" ]; then
    configurar_nginx_apioficial || trata_erro "configurar_nginx_apioficial"
    salvar_etapa 22
  fi
  if [ "$etapa" -le "22" ]; then
    criar_banco_apioficial || trata_erro "criar_banco_apioficial"
    salvar_etapa 23
  fi
  if [ "$etapa" -le "23" ]; then
    configurar_env_apioficial || trata_erro "configurar_env_apioficial"
    salvar_etapa 24
  fi
  if [ "$etapa" -le "24" ]; then
    instalar_apioficial || trata_erro "instalar_apioficial"
    salvar_etapa 25
  fi
  if [ "$etapa" -le "25" ]; then
    atualizar_env_backend_apioficial || trata_erro "atualizar_env_backend_apioficial"
    salvar_etapa 26
  fi
  if [ "$etapa" -le "26" ]; then
    fim_instalacao_base || trata_erro "fim_instalacao_base"
    salvar_etapa 27
  fi
}

# Etapa de instalação
atualizar_base() {
  carregar_variaveis
  if [ ! -f "$ARQUIVO_VARIAVEIS" ]; then
    banner
    printf "${RED} >> Para atualizar é necessário o arquivo VARIAVEIS_INSTALACAO neste diretório.${WHITE}\n"
    printf "${WHITE} >> Crie-o com empresa, repo_url, repo_branch, subdominio_backend, subdominio_frontend, etc. Consulte a documentação.${WHITE}\n"
    echo
    read -p "Pressione Enter para voltar ao menu..."
    return
  fi
  if [ -z "${empresa}" ]; then
    banner
    printf "${RED} >> Variável 'empresa' não definida no VARIAVEIS_INSTALACAO. Corrija o arquivo e tente novamente.${WHITE}\n"
    echo
    read -p "Pressione Enter para voltar ao menu..."
    return
  fi
  preparar_git_para_atualizacao || trata_erro "preparar_git_para_atualizacao"
  backup_app_atualizar || trata_erro "backup_app_atualizar"
  instala_ffmpeg_base || trata_erro "instala_ffmpeg_base"
  config_cron_base || trata_erro "config_cron_base"
  baixa_codigo_atualizar || trata_erro "baixa_codigo_atualizar"
}

sair() {
  exit 0
}

################################################################
#                         INSTALAÇÃO                           #
################################################################

# Questões base
questoes_dns_base() {
  # ARMAZENA URL BACKEND
  banner
  printf "${WHITE} >> Insira a URL do Backend: \n"
  echo
  read -p "> " subdominio_backend
  echo
  # ARMAZENA URL FRONTEND
  banner
  printf "${WHITE} >> Insira a URL do Frontend: \n"
  echo
  read -p "> " subdominio_frontend
  echo
}

# Valida se o domínio ou subdomínio está apontado para o IP da VPS
verificar_dns_base() {
  banner
  printf "${WHITE} >> Verificando o DNS dos dominios/subdominios...\n"
  echo
  sleep 2
  sudo apt-get install dnsutils -y >/dev/null 2>&1
  subdominios_incorretos=""

  verificar_dns() {
    local domain=$1
    local resolved_ip
    local cname_target

    cname_target=$(dig +short CNAME ${domain})

    if [ -n "${cname_target}" ]; then
      resolved_ip=$(dig +short ${cname_target})
    else
      resolved_ip=$(dig +short ${domain})
    fi

    if [ "${resolved_ip}" != "${ip_atual}" ]; then
      echo "O domínio ${domain} (resolvido para ${resolved_ip}) não está apontando para o IP público atual (${ip_atual})."
      subdominios_incorretos+="${domain} "
      sleep 2
    fi
  }
  verificar_dns ${subdominio_backend}
  verificar_dns ${subdominio_frontend}
  if [ -n "${subdominios_incorretos}" ]; then
    echo
    printf "${YELLOW} >> ATENÇÃO: Os seguintes subdomínios não estão apontando para o IP público atual (${ip_atual}):${WHITE}\n"
    printf "${YELLOW} >> ${subdominios_incorretos}${WHITE}\n"
    echo
    printf "${WHITE} >> Deseja continuar a instalação mesmo assim? (S/N): ${WHITE}\n"
    echo
    read -p "> " continuar_dns
    continuar_dns=$(echo "${continuar_dns}" | tr '[:lower:]' '[:upper:]')
    echo
    if [ "${continuar_dns}" != "S" ]; then
      printf "${GREEN} >> Retornando ao menu principal...${WHITE}\n"
      sleep 2
      menu
      return 0
    else
      printf "${YELLOW} >> Continuando a instalação mesmo com DNS não configurado corretamente...${WHITE}\n"
      sleep 2
    fi
  else
    echo "Todos os subdomínios estão apontando corretamente para o IP público da VPS."
    sleep 2
  fi
  echo
  printf "${WHITE} >> Continuando...\n"
  sleep 2
  echo
}

questoes_variaveis_base() {
  # DEFINE EMAIL
  banner
  printf "${WHITE} >> Digite o seu melhor email: \n"
  echo
  read -p "> " email_deploy
  echo
  # DEFINE NOME DA EMPRESA
  banner
  printf "${WHITE} >> Digite o nome da sua empresa (Letras minusculas e sem espaço): \n"
  echo
  read -p "> " empresa
  echo
  # DEFINE SENHA BASE
  banner
  printf "${WHITE} >> Insira a senha para o usuario Deploy, Redis e Banco de Dados ${RED}IMPORTANTE${WHITE}: Não utilizar caracteres especiais\n"
  echo
  read -p "> " senha_deploy
  echo
  # ARMAZENA URL BACKEND
  # banner
  # printf "${WHITE} >> Insira a URL do PerfexCRM: \n"
  # echo
  # read -p "> " subdominio_perfex
  echo
  # DEFINE SENHA MASTER
  banner
  printf "${WHITE} >> Insira a senha para o MASTER: \n"
  echo
  read -p "> " senha_master
  echo
  # DEFINE TITULO DO APP NO NAVEGADOR
  banner
  printf "${WHITE} >> Insira o Titulo da Aplicação (Permitido Espaço): \n"
  echo
  read -p "> " nome_titulo
  echo
  # DEFINE TELEFONE SUPORTE
  banner
  printf "${WHITE} >> Digite o numero de telefone para suporte: \n"
  echo
  read -p "> " numero_suporte
  echo
  # DEFINE FACEBOOK_APP_ID
  banner
  printf "${WHITE} >> Digite o FACEBOOK_APP_ID caso tenha: \n"
  echo
  read -p "> " facebook_app_id
  echo
  # DEFINE FACEBOOK_APP_SECRET
  banner
  printf "${WHITE} >> Digite o FACEBOOK_APP_SECRET caso tenha: \n"
  echo
  read -p "> " facebook_app_secret
  echo
  # DEFINE TIPO DE AUTENTICAÇÃO DO REPOSITÓRIO
  banner
  printf "${WHITE} >> Escolha o tipo de autenticação do repositório: \n"
  printf "${WHITE} >> 1 - Repositório Público (HTTPS sem autenticação) \n"
  printf "${WHITE} >> 2 - Repositório Privado (SSH com Deploy Key) \n"
  echo
  read -p "> " auth_choice
  echo
  
  if [ "${auth_choice}" == "1" ]; then
    repo_auth_type="public"
    # DEFINE LINK REPO GITHUB
    banner
    printf "${WHITE} >> Digite a URL HTTPS do repositório no GitHub: \n"
    printf "${WHITE} >> (ex: https://github.com/usuario/repo.git) \n"
    echo
    read -p "> " repo_url
    echo
    printf "${GREEN} >> Usando repositório público via HTTPS...${WHITE}\n"
    sleep 2
  elif [ "${auth_choice}" == "2" ]; then
    repo_auth_type="ssh"
    # DEFINE LINK REPO GITHUB (SSH)
    banner
    printf "${WHITE} >> Digite a URL SSH do repositório no GitHub: \n"
    printf "${WHITE} >> (ex: git@github.com:usuario/repo.git) \n"
    echo
    read -p "> " repo_url
    echo
    printf "${GREEN} >> Usando repositório privado via SSH...${WHITE}\n"
    printf "${YELLOW} >> NOTA: A chave SSH será gerada durante a instalação.${WHITE}\n"
    sleep 2
  else
    printf "${RED} >> Opção inválida! Retornando ao menu...\n${WHITE}"
    sleep 2
    menu
    return
  fi
  
  # DEFINE BRANCH DO REPOSITÓRIO
  banner
  printf "${WHITE} >> Digite o nome da branch a ser usada: \n"
  printf "${WHITE} >> (ex: main, master, develop) \n"
  echo
  read -p "> " repo_branch
  echo
  if [ -z "${repo_branch}" ]; then
    repo_branch="main"
    printf "${YELLOW} >> Nenhuma branch informada. Usando branch padrão: main${WHITE}\n"
  else
    printf "${GREEN} >> Branch selecionada: ${repo_branch}${WHITE}\n"
  fi
  sleep 2
  
  # PERGUNTA SOBRE API OFICIAL
  banner
  printf "${WHITE} >> Deseja instalar a API Oficial (WhatsApp Business)? (S/N): \n"
  echo
  read -p "> " instalar_api_oficial
  instalar_api_oficial=$(echo "${instalar_api_oficial}" | tr '[:upper:]' '[:lower:]')
  echo
  
  if [ "${instalar_api_oficial}" == "s" ]; then
    # DEFINE SUBDOMINIO API OFICIAL
    banner
    printf "${WHITE} >> Digite o subdomínio da API Oficial: \n"
    printf "${WHITE} >> (ex: apioficial.seudominio.com.br) \n"
    echo
    read -p "> " temp_subdominio_oficial
    echo
    # Limpar subdomínio (sem protocolo)
    subdominio_oficial=$(echo "${temp_subdominio_oficial}" | sed 's|https://||g' | sed 's|http://||g' | cut -d'/' -f1)
    printf "${GREEN} >> API Oficial será instalada em: https://${subdominio_oficial}${WHITE}\n"
    sleep 2
  else
    instalar_api_oficial="n"
    subdominio_oficial=""
    printf "${YELLOW} >> API Oficial não será instalada.${WHITE}\n"
    sleep 2
  fi
}

# Define proxy usado
define_proxy_base() {
  banner
  while true; do
    printf "${WHITE} >> Instalar usando Nginx ou Traefik? (Nginx/Traefik): ${WHITE}\n"
    echo
    read -p "> " proxy
    echo
    proxy=$(echo "${proxy}" | tr '[:upper:]' '[:lower:]')

    if [ "${proxy}" = "nginx" ] || [ "${proxy}" = "traefik" ]; then
      sleep 2
      break
    else
      printf "${RED} >> Por favor, digite 'Nginx' ou 'Traefik' para continuar... ${WHITE}\n"
      echo
    fi
  done
  export proxy
}

# Define portas backend e frontend
define_portas_base() {
  banner
  printf "${WHITE} >> Usar as portas padrão para Backend (8080) e Frontend (3000) ? (S/N): ${WHITE}\n"
  echo
  read -p "> " use_default_ports
  use_default_ports=$(echo "${use_default_ports}" | tr '[:upper:]' '[:lower:]')
  echo

  default_backend_port=8080
  default_frontend_port=3000

  if [ "${use_default_ports}" = "s" ]; then
    backend_port=${default_backend_port}
    frontend_port=${default_frontend_port}
  else
    while true; do
      printf "${WHITE} >> Qual porta deseja para o Backend? ${WHITE}\n"
      echo
      read -p "> " backend_port
      echo
      if ! lsof -i:${backend_port} &>/dev/null; then
        break
      else
        printf "${RED} >> A porta ${backend_port} já está em uso. Por favor, escolha outra.${WHITE}\n"
        echo
      fi
    done

    while true; do
      printf "${WHITE} >> Qual porta deseja para o Frontend? ${WHITE}\n"
      echo
      read -p "> " frontend_port
      echo
      if ! lsof -i:${frontend_port} &>/dev/null; then
        break
      else
        printf "${RED} >> A porta ${frontend_port} já está em uso. Por favor, escolha outra.${WHITE}\n"
        echo
      fi
    done
  fi

  sleep 2
}

# Informa os dados de instalação
dados_instalacao_base() {
  # Define tipo de autenticação para exibição
  if [ "${repo_auth_type}" == "ssh" ]; then
    auth_display="SSH (Deploy Key)"
  elif [ "${repo_auth_type}" == "public" ]; then
    auth_display="HTTPS Público (sem autenticação)"
  else
    auth_display="HTTPS Público"
  fi
  
  printf "   ${WHITE}Anote os dados abaixo\n\n"
  printf "   ${WHITE}Subdominio Backend: ---->> ${YELLOW}${subdominio_backend}\n"
  printf "   ${WHITE}Subdominio Frontend: --->> ${YELLOW}${subdominio_frontend}\n"
  printf "   ${WHITE}Seu Email: ------------->> ${YELLOW}${email_deploy}\n"
  printf "   ${WHITE}Nome da Empresa: ------->> ${YELLOW}${empresa}\n"
  printf "   ${WHITE}Senha Deploy: ---------->> ${YELLOW}${senha_deploy}\n"
  # printf "   ${WHITE}Subdominio Perfex: ----->> ${YELLOW}${subdominio_perfex}\n"
  printf "   ${WHITE}Senha Master: ---------->> ${YELLOW}${senha_master}\n"
  printf "   ${WHITE}Titulo da Aplicação: --->> ${YELLOW}${nome_titulo}\n"
  printf "   ${WHITE}Numero de Suporte: ----->> ${YELLOW}${numero_suporte}\n"
  printf "   ${WHITE}FACEBOOK_APP_ID: ------->> ${YELLOW}${facebook_app_id}\n"
  printf "   ${WHITE}FACEBOOK_APP_SECRET: --->> ${YELLOW}${facebook_app_secret}\n"
  printf "   ${WHITE}Tipo de Autenticação: -->> ${YELLOW}${auth_display}\n"
  printf "   ${WHITE}URL do Repositório: ---->> ${YELLOW}${repo_url}\n"
  printf "   ${WHITE}Branch: ---------------->> ${YELLOW}${repo_branch:-main}\n"
  printf "   ${WHITE}Proxy Usado: ----------->> ${YELLOW}${proxy}\n"
  printf "   ${WHITE}Porta Backend: --------->> ${YELLOW}${backend_port}\n"
  printf "   ${WHITE}Porta Frontend: -------->> ${YELLOW}${frontend_port}\n"
}

# Confirma os dados de instalação
confirma_dados_instalacao_base() {
  printf " >> Confira abaixo os dados dessa instalação! \n"
  echo
  dados_instalacao_base
  echo
  printf "${WHITE} >> Os dados estão corretos? ${GREEN}S/${RED}N:${WHITE} \n"
  echo
  read -p "> " confirmacao
  echo
  confirmacao=$(echo "${confirmacao}" | tr '[:lower:]' '[:upper:]')
  if [ "${confirmacao}" == "S" ]; then
    printf "${GREEN} >> Continuando a Instalação... ${WHITE} \n"
    echo
  else
    printf "${GREEN} >> Retornando ao Menu Principal... ${WHITE} \n"
    echo
    sleep 2
    menu
  fi
}

# Atualiza sistema operacional
atualiza_vps_base() {
  UPDATE_FILE="$(pwd)/update.x"
  {
    sudo DEBIAN_FRONTEND=noninteractive apt update -y && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && sudo DEBIAN_FRONTEND=noninteractive apt-get install build-essential -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apparmor-utils
    touch "${UPDATE_FILE}"
    sleep 2
  } || trata_erro "atualiza_vps_base"
}

# Cria usuário deploy
cria_deploy_base() {
  banner
  printf "${WHITE} >> Agora, vamos criar o usuário para deploy...\n"
  echo
  {
    sudo useradd -m -p $(openssl passwd -1 ${senha_deploy}) -s /bin/bash -G sudo deploy
    sudo usermod -aG sudo deploy
    sleep 2
  } || trata_erro "cria_deploy_base"
}

# Configura timezone
config_timezone_base() {
  banner
  printf "${WHITE} >> Configurando Timezone...\n"
  echo
  {
    sudo su - root <<EOF
  timedatectl set-timezone America/Sao_Paulo
EOF
    sleep 2
  } || trata_erro "config_timezone_base"
}

# Configura firewall
config_firewall_base() {
  banner
  printf "${WHITE} >> Configurando o firewall Portas 80 e 443...\n"
  echo
  {
    if [ "${ARCH}" = "x86_64" ]; then
      sudo su - root <<EOF >/dev/null 2>&1
  ufw allow 80/tcp && ufw allow 22/tcp && ufw allow 443/tcp
EOF
      sleep 2

    elif [ "${ARCH}" = "aarch64" ]; then
      sudo su - root <<EOF >/dev/null 2>&1
  sudo iptables -F &&
  sudo iptables -A INPUT -i lo -j ACCEPT &&
  sudo iptables -A OUTPUT -o lo -j ACCEPT &&
  sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT &&
  sudo iptables -A INPUT -p udp --dport 80 -j ACCEPT &&
  sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT &&
  sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT &&
  sudo service netfilter-persistent save
EOF
      sleep 2

    else
      echo "Arquitetura não suportada."
    fi
  } || trata_erro "config_firewall_base"
}

# Instala dependência puppeteer
instala_puppeteer_base() {
  banner
  printf "${WHITE} >> Instalando puppeteer dependencies...\n"
  echo
  {
    sudo su - root <<EOF
apt-get install -y libaom-dev libass-dev libfreetype6-dev libfribidi-dev \
                   libharfbuzz-dev libgme-dev libgsm1-dev libmp3lame-dev \
                   libopencore-amrnb-dev libopencore-amrwb-dev libopenmpt-dev \
                   libopus-dev libfdk-aac-dev librubberband-dev libspeex-dev \
                   libssh-dev libtheora-dev libvidstab-dev libvo-amrwbenc-dev \
                   libvorbis-dev libvpx-dev libwebp-dev libx264-dev libx265-dev \
                   libxvidcore-dev libzmq3-dev libsdl2-dev build-essential \
                   yasm cmake libtool libc6 libc6-dev unzip wget pkg-config texinfo zlib1g-dev \
                   libxshmfence-dev libgcc1 libgbm-dev fontconfig locales gconf-service libasound2 \
                   libatk1.0-0 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc-s1 \
                   libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 \
                   libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 \
                   libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 \
                   libxss1 libxtst6 ca-certificates fonts-liberation libappindicator1 libnss3 \
                   lsb-release xdg-utils

if grep -q "20.04" /etc/os-release; then
    apt-get install -y libsrt-dev
else
    apt-get install -y libsrt-openssl-dev
fi

EOF
    sleep 2
  } || trata_erro "instala_puppeteer_base"
}

# Instala FFMPEG
instala_ffmpeg_base() {
  banner
  printf "${WHITE} >> Instalando FFMPEG 6...\n"
  echo

  if [ -f "${FFMPEG}" ]; then
    printf " >> FFMPEG já foi instalado. Continuando a instalação...\n"
    echo
  else

    sleep 2

    {
      sudo apt install ffmpeg -y
      # Dynamic fetch of latest FFmpeg build from BtbN/FFmpeg-Builds
      download_ok=false
      asset_url=""
      if [ "${ARCH}" = "x86_64" ]; then
        asset_url=$(curl -sL https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest | grep -oP '"browser_download_url":\s*"\K[^"]+' | grep -E 'linux64-gpl.*\.tar\.xz$' | head -n1)
      elif [ "${ARCH}" = "aarch64" ]; then
        asset_url=$(curl -sL https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest | grep -oP '"browser_download_url":\s*"\K[^"]+' | grep -E 'linuxarm64-gpl.*\.tar\.xz$' | head -n1)
      else
        echo "Arquitetura não suportada: ${ARCH}"
      fi

      if [ -n "${asset_url}" ]; then
        FFMPEG_FILE="${asset_url##*/}"
        wget -q "${asset_url}" -O "${FFMPEG_FILE}"
        if [ $? -eq 0 ]; then
          mkdir -p ${FFMPEG_DIR}
          tar -xvf ${FFMPEG_FILE} -C ${FFMPEG_DIR} >/dev/null 2>&1
          extracted_dir=$(tar -tf ${FFMPEG_FILE} | head -1 | cut -d/ -f1)
          if [ -n "${extracted_dir}" ] && [ -d "${FFMPEG_DIR}/${extracted_dir}/bin" ]; then
            sudo cp ${FFMPEG_DIR}/${extracted_dir}/bin/ffmpeg /usr/bin/ >/dev/null 2>&1
            sudo cp ${FFMPEG_DIR}/${extracted_dir}/bin/ffprobe /usr/bin/ >/dev/null 2>&1
            sudo cp ${FFMPEG_DIR}/${extracted_dir}/bin/ffplay /usr/bin/ >/dev/null 2>&1
            rm -rf ${FFMPEG_DIR} >/dev/null 2>&1
            rm -f ${FFMPEG_FILE} >/dev/null 2>&1
            download_ok=true
          fi
        fi
      fi

      if [ "${download_ok}" != true ]; then
        printf "${YELLOW} >> Não foi possível baixar o FFmpeg dos builds oficiais. Usando pacote da distribuição...${WHITE}\n"
      fi

      export PATH=/usr/bin:${PATH}
      echo 'export PATH=/usr/bin:${PATH}' >>~/.bashrc
      source ~/.bashrc >/dev/null 2>&1
      if command -v ffmpeg >/dev/null 2>&1; then
        touch "${FFMPEG}"
      fi
    } || trata_erro "instala_ffmpeg_base"
  fi
}

# Instala Postgres
instala_postgres_base() {
  banner
  printf "${WHITE} >> Instalando postgres...\n"
  echo
  {
    sudo su - root <<EOF
  sudo apt-get install gnupg -y
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get update -y && sudo apt-get -y install postgresql-17
EOF
    sleep 2
  } || trata_erro "instala_postgres_base"
}

# Instala NodeJS
instala_node_base() {
  banner
 printf "${WHITE} >> Instalando nodejs...\n"
 echo
  {
    sudo su - root <<'NODEINSTALL'
    # Remove repositórios antigos do NodeSource que podem estar causando problemas
    rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null
    rm -f /etc/apt/sources.list.d/nodesource*.list 2>/dev/null
    
    # Tenta primeiro com Node.js 22.x (LTS atual disponível no repositório oficial)
    printf " >> Tentando instalar Node.js 22.x LTS (repositório oficial)...\n"
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>&1 | grep -v "does not have a Release file" || {
      printf " >> Node.js 22.x não disponível. Tentando Node.js 20.x...\n"
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>&1 | grep -v "does not have a Release file" || {
        printf " >> Erro ao configurar repositório. Tentando método alternativo...\n"
        # Método alternativo: baixa e executa o script manualmente
        curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource_setup.sh 2>/dev/null || \
        curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
        bash /tmp/nodesource_setup.sh 2>&1 | grep -v "does not have a Release file" || {
          printf " >> Falha ao configurar repositório NodeSource.\n"
          exit 1
        }
      }
    }
    
    # Atualiza lista de pacotes (ignorando erros de outros repositórios)
    printf " >> Atualizando lista de pacotes...\n"
    apt-get update -y 2>&1 | grep -v "does not have a Release file" | grep -v "Key is stored in legacy" || true
    
    # Instala Node.js
    printf " >> Instalando Node.js...\n"
    apt-get install -y nodejs || {
      printf " >> Erro ao instalar Node.js via apt.\n"
      exit 1
    }
    
    # Verifica se Node.js foi instalado
    if ! command -v node &> /dev/null; then
      printf " >> Erro: Node.js não foi encontrado no PATH após instalação.\n"
      printf " >> Verificando localização...\n"
      find /usr -name node -type f 2>/dev/null | head -5
      exit 1
    fi
    
    # Verifica se npm está disponível
    if ! command -v npm &> /dev/null; then
      printf " >> Erro: npm não foi encontrado no PATH após instalação.\n"
      printf " >> Verificando localização...\n"
      find /usr -name npm -type f 2>/dev/null | head -5
      exit 1
    fi
    
    # Mostra versões instaladas
    printf " >> Node.js instalado: "
    node --version
    printf " >> npm instalado: "
    npm --version
    
    # Instala o gerenciador de versões 'n' e configura a versão específica 20.19.4
    printf " >> Instalando gerenciador de versões 'n'...\n"
    npm install -g n || {
      printf " >> Aviso: Não foi possível instalar 'n'. Continuando com versão padrão.\n"
    }
    
    # Tenta instalar versão específica se 'n' foi instalado
    if command -v n &> /dev/null; then
      printf " >> Configurando Node.js versão 20.19.4...\n"
      n 20.19.4 || {
        printf " >> Aviso: Não foi possível instalar versão específica. Usando versão padrão.\n"
      }
      
      # Garante que os binários estão no PATH do sistema
      if [ -f /usr/local/n/versions/node/20.19.4/bin/node ]; then
        ln -sf /usr/local/n/versions/node/20.19.4/bin/node /usr/bin/node
        ln -sf /usr/local/n/versions/node/20.19.4/bin/npm /usr/bin/npm
        ln -sf /usr/local/n/versions/node/20.19.4/bin/npx /usr/bin/npx 2>/dev/null || true
      fi
    fi
    
    # Cria links simbólicos para garantir acesso global
    NODE_BIN=$(which node 2>/dev/null || find /usr -name node -type f 2>/dev/null | head -1)
    NPM_BIN=$(which npm 2>/dev/null || find /usr -name npm -type f 2>/dev/null | head -1)
    
    if [ -n "$NODE_BIN" ] && [ "$NODE_BIN" != "/usr/bin/node" ]; then
      ln -sf "$NODE_BIN" /usr/bin/node
    fi
    
    if [ -n "$NPM_BIN" ] && [ "$NPM_BIN" != "/usr/bin/npm" ]; then
      ln -sf "$NPM_BIN" /usr/bin/npm
    fi
    
    # Atualiza o PATH no perfil do sistema
    if ! grep -q "/usr/local/n/versions/node" /etc/profile 2>/dev/null; then
      echo 'export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH' >> /etc/profile
    fi
    
    # Atualiza o PATH no bashrc do root e deploy
    for user_home in /root /home/deploy; do
      if [ -d "$user_home" ]; then
        if ! grep -q "/usr/local/n/versions/node" "$user_home/.bashrc" 2>/dev/null; then
          echo 'export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH' >> "$user_home/.bashrc"
        fi
      fi
    done
    
    # Verifica novamente se node e npm estão disponíveis
    printf " >> Verificando instalação final...\n"
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH
    node --version || exit 1
    npm --version || exit 1
NODEINSTALL
    
    sleep 2
  } || trata_erro "instala_node_base"
}

# Instala Redis
instala_redis_base() {
  {
    sudo su - root <<EOF
  apt install redis-server -y
  systemctl enable redis-server.service
  sed -i 's/# requirepass foobared/requirepass ${senha_deploy}/g' /etc/redis/redis.conf
  sed -i 's/^appendonly no/appendonly yes/g' /etc/redis/redis.conf
  systemctl restart redis-server.service
EOF
    sleep 2
  } || trata_erro "instala_redis_base"
}

# Instala PM2
instala_pm2_base() {
  banner
  printf "${WHITE} >> Instalando pm2...\n"
  echo
  
  {
    sudo su - root <<'PM2INSTALL'
    # Configura PATH para incluir Node.js
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:$PATH
    
    # Tenta encontrar node em vários locais possíveis
    NODE_BIN=""
    if command -v node &> /dev/null; then
      NODE_BIN=$(which node)
      printf " >> Node.js encontrado em: $NODE_BIN\n"
    elif [ -f /usr/local/n/versions/node/20.19.4/bin/node ]; then
      NODE_BIN="/usr/local/n/versions/node/20.19.4/bin/node"
      export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH
      printf " >> Node.js encontrado em: $NODE_BIN\n"
    elif [ -f /usr/bin/node ]; then
      NODE_BIN="/usr/bin/node"
      printf " >> Node.js encontrado em: $NODE_BIN\n"
    else
      printf " >> ERRO: Node.js não está instalado ou não foi encontrado no sistema.\n"
      printf " >> Procurando Node.js no sistema...\n"
      find /usr -name node -type f 2>/dev/null | head -5
      exit 1
    fi
    
    # Verifica npm
    if ! command -v npm &> /dev/null; then
      printf " >> ERRO: npm não está instalado ou não foi encontrado no sistema.\n"
      printf " >> Procurando npm no sistema...\n"
      find /usr -name npm -type f 2>/dev/null | head -5
      exit 1
    fi
    
    # Mostra versões
    printf " >> Versão do Node.js: "
    node --version || exit 1
    printf " >> Versão do npm: "
    npm --version || exit 1
    
    # Instala PM2 globalmente
    printf " >> Instalando PM2...\n"
    npm install -g pm2 || {
      printf " >> Erro ao instalar PM2. Tentando com sudo...\n"
      exit 1
    }
    
    # Verifica se PM2 foi instalado
    if ! command -v pm2 &> /dev/null; then
      printf " >> PM2 não encontrado no PATH. Procurando...\n"
      PM2_BIN=$(find /usr -name pm2 -type f 2>/dev/null | head -1)
      if [ -n "$PM2_BIN" ]; then
        printf " >> PM2 encontrado em: $PM2_BIN\n"
        ln -sf "$PM2_BIN" /usr/bin/pm2 2>/dev/null || true
      else
        printf " >> ERRO: PM2 não foi instalado corretamente\n"
        exit 1
      fi
    fi
    
    printf " >> PM2 instalado com sucesso!\n"
    pm2 --version || exit 1
    
    # Configura o PM2 para iniciar automaticamente
    printf " >> Configurando PM2 para iniciar automaticamente...\n"
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:$PATH
    
    # Garante que o usuário deploy existe
    if id "deploy" &>/dev/null; then
      pm2 startup ubuntu -u deploy --hp /home/deploy || {
        printf " >> Aviso: Não foi possível configurar startup automático. Continuando...\n"
      }
    else
      printf " >> Aviso: Usuário deploy não existe ainda. Startup será configurado depois.\n"
    fi
PM2INSTALL
    
    sleep 2
  } || trata_erro "instala_pm2_base"
}

# Instala Nginx e dependências
instala_nginx_base() {
  banner
  printf "${WHITE} >> Instalando Nginx...\n"
  echo
  {
    sudo su - root <<EOF
    apt install -y nginx
    rm /etc/nginx/sites-enabled/default
EOF

    sleep 2

    sudo su - root <<EOF
echo 'client_max_body_size 100M;' > /etc/nginx/conf.d/${empresa}.conf
EOF

    sleep 2

    sudo su - root <<EOF
  service nginx restart
EOF

    sleep 2

    sudo su - root <<EOF
  apt install -y snapd
  snap install core
  snap refresh core
EOF

    sleep 2

    sudo su - root <<EOF
  apt-get remove certbot
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot
EOF

    sleep 2
  } || trata_erro "instala_nginx_base"
}

# Instala Traefik
instala_traefik_base() {
  useradd --system --shell /bin/false --user-group --no-create-home traefik
  cd /tmp
  mkdir traefik
  cd traefik/
  if [ "${ARCH}" = "x86_64" ]; then
    traefik_arch="amd64"
  elif [ "${ARCH}" = "aarch64" ]; then
    traefik_arch="arm64"
  else
    echo "Arquitetura não suportada: ${ARCH}"
    exit 1
  fi
  traefik_url="https://github.com/traefik/traefik/releases/download/v2.10.5/traefik_v2.10.5_linux_${traefik_arch}.tar.gz"
  curl --remote-name --location "${traefik_url}"
  tar -zxf traefik_v2.10.5_linux_${traefik_arch}.tar.gz
  cp traefik /usr/local/bin/traefik
  chmod a+x /usr/local/bin/traefik
  cd ..
  rm -rf traefik
  mkdir --parents /etc/traefik
  mkdir --parents /etc/traefik/conf.d

  sleep 2

  sudo su - root <<EOF
cat > /etc/traefik/traefik.toml << 'END'
################################################################
# Global configuration
################################################################
[global]
  checkNewVersion = "false"
  sendAnonymousUsage = "true"

################################################################
# Entrypoints configuration
################################################################
[entryPoints]
  [entryPoints.websecure]
    address = ":443"
  [entryPoints.web]
    address = ":80"

################################################################
# CertificatesResolvers configuration for Let's Encrypt
################################################################
[certificatesResolvers.letsencryptresolver.acme]
  email = "${email_deploy}"
  storage = "/etc/traefik/acme.json"
  [certificatesResolvers.letsencryptresolver.acme.httpChallenge]
    # Define the entrypoint which will receive the HTTP challenge
    entryPoint = "web"

################################################################
# Log configuration
################################################################
[log]
  level = "INFO"
  format = "json"
  filePath = "/var/log/traefik/traefik.log"

################################################################
# Access Log configuration
################################################################
[accessLog]
  filePath = "/var/log/traefik/access.log"
  format = "common"

################################################################
# API and Dashboard configuration
################################################################
[api]
  dashboard = false
  insecure = false
  # [entryPoints.dashboard]
  #   address = ":9090"

################################################################
# Providers configuration
################################################################
# Since the original setup was intended for Docker and this setup is for systemd,
# we don't use Docker provider settings but we keep file provider.
[providers]
  [providers.file]
    directory = "/etc/traefik/conf.d/"
    watch = "true"
END
EOF

  sleep 2

  sudo su - root <<EOF
cat > /etc/traefik/traefik.service << 'END'
# Systemd Traefik service
[Unit]
Description=Traefik - Proxy
Documentation=https://docs.traefik.io
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
AssertFileIsExecutable=/usr/local/bin/traefik
AssertPathExists=/etc/traefik/traefik.toml
#RequiresMountsFor=/var/log

[Service]
User=traefik
AmbientCapabilities=CAP_NET_BIND_SERVICE
Type=notify
ExecStart=/usr/local/bin/traefik --configFile=/etc/traefik/traefik.toml
Restart=always
WatchdogSec=2s

LogsDirectory=traefik

[Install]
WantedBy=multi-user.target
END
EOF

  sleep 2

  sudo su - root <<EOF
cat > /etc/traefik/conf.d/tls.toml << 'END'
[tls.options]
  [tls.options.default]
    sniStrict = true
    minVersion = "VersionTLS12"
END
EOF
  sleep 2

  cp /etc/traefik/traefik.service /etc/systemd/system/
  chown -R traefik:traefik /etc/traefik/
  rm -rf /etc/traefik/traefik.service
  systemctl daemon-reload
  sleep 2
  systemctl enable --now traefik.service
  sleep 2
}

# Cria banco de dados
cria_banco_base() {
  banner
  printf "${WHITE} >> Criando Banco Postgres...\n"
  echo
  {
    sudo su - postgres <<EOF
    createdb ${empresa};
    psql
    CREATE USER ${empresa} SUPERUSER INHERIT CREATEDB CREATEROLE;
    ALTER USER ${empresa} PASSWORD '${senha_deploy}';
    \q
    exit
EOF

    sleep 2
  } || trata_erro "cria_banco_base"
}

# Instala Git
instala_git_base() {
  banner
  printf "${WHITE} >> Instalando o GIT...\n"
  echo
  {
    sudo su - root <<EOF
  apt install -y git
  apt -y autoremove
EOF
    sleep 2
  } || trata_erro "instala_git_base"
}

# Configura Deploy Key SSH para repositório privado
configura_deploy_key_ssh() {
  # Só executa se o tipo de autenticação for SSH
  if [ "${repo_auth_type}" != "ssh" ]; then
    return 0
  fi
  
  banner
  printf "${WHITE} >> Configurando Deploy Key SSH para repositório privado...\n"
  echo
  {
    # Verifica se usuário deploy existe
    if ! id "deploy" &>/dev/null; then
      printf "${RED} >> ERRO: Usuário deploy não existe!${WHITE}\n"
      exit 1
    fi
    
    # Gera chave SSH para o usuário deploy se não existir
    if [ ! -f "/home/deploy/.ssh/id_rsa" ]; then
      banner
      printf "${WHITE} >> Gerando chave SSH RSA 4096 bits...\n"
      echo
      sudo su - deploy <<'SSHKEYGEN'
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        ssh-keygen -t rsa -b 4096 -C "deploy@multiflow" -f ~/.ssh/id_rsa -N ""
SSHKEYGEN
      
      if [ $? -eq 0 ]; then
        printf "${GREEN} >> Chave SSH gerada com sucesso!\n${WHITE}"
      else
        printf "${RED} >> ERRO ao gerar chave SSH!${WHITE}\n"
        exit 1
      fi
    else
      printf "${YELLOW} >> Chave SSH já existe, usando a chave existente...\n${WHITE}"
    fi
    
    echo
    banner
    printf "${GREEN}══════════════════════════════════════════════════════════════════${WHITE}\n"
    printf "${GREEN} >> Chave Pública SSH (Deploy Key):${WHITE}\n"
    printf "${YELLOW}══════════════════════════════════════════════════════════════════${WHITE}\n"
    echo
    sudo cat /home/deploy/.ssh/id_rsa.pub
    echo
    printf "${YELLOW}══════════════════════════════════════════════════════════════════${WHITE}\n"
    echo
    printf "${WHITE} >> PASSOS PARA CONFIGURAR NO GITHUB:\n"
    printf "${WHITE} >> 1. Copie a chave pública acima\n"
    printf "${WHITE} >> 2. Vá até o repositório no GitHub: ${BLUE}${repo_url}${WHITE}\n"
    printf "${WHITE} >> 3. Acesse: ${YELLOW}Settings > Deploy keys > Add deploy key${WHITE}\n"
    printf "${WHITE} >> 4. Cole a chave pública no campo 'Key'\n"
    printf "${WHITE} >> 5. Dê um título (ex: 'Servidor Produção')\n"
    printf "${WHITE} >> 6. Marque '${GREEN}Allow write access${WHITE}' se necessário\n"
    printf "${WHITE} >> 7. Clique em '${GREEN}Add key${WHITE}'\n"
    echo
    printf "${YELLOW} >> Após adicionar a Deploy Key no GitHub, pressione Enter para continuar...${WHITE}\n"
    read -p ""
    echo
    
    # Configura o SSH para aceitar a chave do GitHub
    printf "${WHITE} >> Configurando known_hosts para GitHub...\n"
    sudo su - deploy <<'SSHCONFIG'
      mkdir -p ~/.ssh
      chmod 700 ~/.ssh
      ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null
      chmod 600 ~/.ssh/known_hosts
      chmod 600 ~/.ssh/id_rsa
      chmod 644 ~/.ssh/id_rsa.pub
SSHCONFIG
    
    echo
    printf "${GREEN} >> Deploy Key SSH configurada com sucesso!${WHITE}\n"
    sleep 2
  } || trata_erro "configura_deploy_key_ssh"
}

# Função para codificar URL de clone
codifica_clone_base() {
  local length="${#1}"
  for ((i = 0; i < length; i++)); do
    local c="${1:i:1}"
    case $c in
    [a-zA-Z0-9.~_-]) printf "$c" ;;
    *) printf '%%%02X' "'$c" ;;
    esac
  done
}

# Clona código de repo privado ou público
baixa_codigo_base() {
  banner
  printf "${WHITE} >> Fazendo download do ${nome_titulo}...\n"
  echo
  {
    if [ -z "${repo_url}" ]; then
      printf "${RED} >> Erro: URL do repositório não definida.\n"
      exit 1
    fi

    dest_dir="/home/deploy/${empresa}/"
    
    # Clone baseado no tipo de autenticação
    if [ "${repo_auth_type}" == "ssh" ]; then
      # Repositório privado com Deploy Key SSH
      printf "${WHITE} >> Clonando repositório via SSH (Deploy Key)...\n"
      echo
      
      # Clone como usuário deploy para usar a chave SSH configurada
      sudo su - deploy <<GITCLONE
        if [ ! -f ~/.ssh/id_rsa ]; then
          echo "ERRO: Chave SSH não encontrada. Execute a configuração novamente."
          exit 1
        fi
        
        # Garante permissões corretas na chave SSH
        chmod 600 ~/.ssh/id_rsa
        chmod 644 ~/.ssh/id_rsa.pub
        
        # Clone usando SSH (branch: ${repo_branch:-main})
        GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no" git clone -b ${repo_branch:-main} ${repo_url} ${dest_dir}
GITCLONE
      
      clone_status=$?
      
    else
      # Repositório público via HTTPS
      printf "${WHITE} >> Clonando repositório público via HTTPS...\n"
      echo
      
      # Garante que a URL tem o protocolo correto
      if [[ ! "${repo_url}" =~ ^https?:// ]]; then
        repo_url="https://${repo_url}"
      fi
      
      # Clone direto como root e depois ajusta permissões (branch: ${repo_branch:-main})
      git clone -b ${repo_branch:-main} ${repo_url} ${dest_dir}
      clone_status=$?
    fi
    
    echo
    if [ ${clone_status} -eq 0 ]; then
      printf "${GREEN} >> Repositório clonado com sucesso!${WHITE}\n"
      printf "${WHITE} >> Continuando a instalação...\n"
      echo
    else
      printf "${RED} >> ERRO: Falha ao clonar repositório!${WHITE}\n"
      if [ "${repo_auth_type}" == "ssh" ]; then
        printf "${RED} >> Verifique:${WHITE}\n"
        printf "${RED} >> - Deploy Key foi adicionada corretamente no GitHub${WHITE}\n"
        printf "${RED} >> - URL SSH está correta (git@github.com:usuario/repo.git)${WHITE}\n"
        printf "${RED} >> - Chave SSH foi gerada corretamente${WHITE}\n"
      else
        printf "${RED} >> Verifique:${WHITE}\n"
        printf "${RED} >> - URL HTTPS está correta${WHITE}\n"
        printf "${RED} >> - Repositório é realmente público${WHITE}\n"
        printf "${RED} >> - Conexão com a internet está funcionando${WHITE}\n"
      fi
      echo
      exit 1
    fi

    mkdir -p /home/deploy/${empresa}/backend/public/
    chown deploy:deploy -R /home/deploy/${empresa}/
    chmod 775 -R /home/deploy/${empresa}/backend/public/
    sleep 2
  } || trata_erro "baixa_codigo_base"
}

# Instala e configura backend
instala_backend_base() {
  banner
  printf "${WHITE} >> Configurando variáveis de ambiente do ${BLUE}backend${WHITE}...\n"
  echo
  
  # Verifica se a variável empresa está definida
  if [ -z "${empresa}" ]; then
    printf "${RED} >> ERRO: Variável 'empresa' não está definida!\n${WHITE}"
    printf "${YELLOW} >> Carregando variáveis salvas...\n${WHITE}"
    carregar_variaveis
    if [ -z "${empresa}" ]; then
      printf "${RED} >> ERRO: Não foi possível carregar a variável 'empresa'. Abortando.\n${WHITE}"
      exit 1
    fi
  fi
  
  # Verifica se o diretório do código existe
  if [ ! -d "/home/deploy/${empresa}" ]; then
    printf "${RED} >> ERRO: Diretório /home/deploy/${empresa} não existe!\n${WHITE}"
    printf "${YELLOW} >> O código precisa ser clonado primeiro. Verifique a etapa anterior.\n${WHITE}"
    exit 1
  fi
  
  {
    sleep 2
    subdominio_backend=$(echo "${subdominio_backend/https:\/\//}")
    subdominio_backend=${subdominio_backend%%/*}
    subdominio_backend=https://${subdominio_backend}
    subdominio_frontend=$(echo "${subdominio_frontend/https:\/\//}")
    subdominio_frontend=${subdominio_frontend%%/*}
    subdominio_frontend=https://${subdominio_frontend}
    # subdominio_perfex=$(echo "${subdominio_perfex/https:\/\//}")
    # subdominio_perfex=${subdominio_perfex%%/*}
    # subdominio_perfex=https://${subdominio_perfex}
    sudo su - deploy <<EOF
  cat <<[-]EOF > /home/deploy/${empresa}/backend/.env
# Equipechat  - (81) 9 9998-8876
NODE_ENV=
BACKEND_URL=${subdominio_backend}
FRONTEND_URL=${subdominio_frontend}
PROXY_PORT=443
PORT=${backend_port}

# CREDENCIAIS BD
DB_HOST=localhost
DB_DIALECT=postgres
DB_PORT=5432
DB_USER=${empresa}
DB_PASS=${senha_deploy}
DB_NAME=${empresa}

# DADOS REDIS
REDIS_URI=redis://:${senha_deploy}@127.0.0.1:6379
REDIS_OPT_LIMITER_MAX=1
REDIS_OPT_LIMITER_DURATION=3000
# REDIS_URI_ACK=redis://:${senha_deploy}@127.0.0.1:6379
# BULL_BOARD=true
# BULL_USER=${email_deploy}
# BULL_PASS=${senha_deploy}

# --- RabbitMQ ---
RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBIT_USER=${empresa}
RABBIT_PASS=${senha_deploy}
RABBITMQ_URI=amqp://\${empresa}:\${senha_deploy}@localhost:5672/

TIMEOUT_TO_IMPORT_MESSAGE=1000

# SECRETS
JWT_SECRET=${jwt_secret}
JWT_REFRESH_SECRET=${jwt_refresh_secret}
MASTER_KEY=${senha_master}

# PERFEX_URL=${subdominio_perfex}
# PERFEX_MODULE=Multi100
VERIFY_TOKEN=whaticket
FACEBOOK_APP_ID=${facebook_app_id}
FACEBOOK_APP_SECRET=${facebook_app_secret}

#METODOS DE PAGAMENTO

STRIPE_PRIVATE=
STRIPE_OK_URL=BACKEND_URL/subscription/stripewebhook
STRIPE_CANCEL_URL=FRONTEND_URL/financeiro

# MERCADO PAGO

MPACCESSTOKEN=SEU TOKEN
MPNOTIFICATIONURL=https://SUB_DOMINIO_API/subscription/mercadopagowebhook

MP_ACCESS_TOKEN=SEU TOKEN
MP_NOTIFICATION_URL=https://SUB_DOMINIO_API/subscription/mercadopagowebhook

ASAAS_TOKEN=SEU TOKEN
MP_NOTIFICATION_URL=https://SUB_DOMINIO_API/subscription/asaaswebhook

MPNOTIFICATION_URL=https://SUB_DOMINIO_API/subscription/asaaswebhook
ASAASTOKEN=SEU TOKEN

GERENCIANET_SANDBOX=
GERENCIANET_CLIENT_ID=
GERENCIANET_CLIENT_SECRET=
GERENCIANET_PIX_CERT=
GERENCIANET_PIX_KEY=

# EMAIL
MAIL_HOST="smtp.gmail.com"
MAIL_USER="SEUGMAIL@gmail.com"
MAIL_PASS="SENHA DE APP"
MAIL_FROM="Recuperação de Senha <SEU GMAIL@gmail.com>"
MAIL_PORT="465"

# WhatsApp Oficial
USE_WHATSAPP_OFICIAL=true
# URL_API_OFICIAL=https://SubDominioDaOficial.SEUDOMINIO.com.br
TOKEN_API_OFICIAL="adminpro"
OFFICIAL_CAMPAIGN_CONCURRENCY=10  # Processa até 10 campanhas ao mesmo tempo

# API de Transcrição de Audio
TRANSCRIBE_URL=http://localhost:4002
[-]EOF
EOF

    sleep 2

    banner
    printf "${WHITE} >> Instalando dependências do ${BLUE}backend${WHITE}...\n"
    echo
    sudo su - deploy <<BACKENDINSTALL
  # Configura PATH para Node.js
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  elif [ -f /usr/bin/node ]; then
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  else
    # Tenta encontrar node no sistema
    NODE_DIR=\$(find /usr -type d -name "node" -o -type f -name "node" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
    if [ -n "\$NODE_DIR" ]; then
      export PATH=\$NODE_DIR:/usr/bin:\$PATH
    fi
  fi
  
  # Verifica se node e npm estão disponíveis
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "ERRO: Node.js ou npm não encontrado. PATH atual: \$PATH"
    which node || echo "node não encontrado"
    which npm || echo "npm não encontrado"
    exit 1
  fi
  
  # Verifica se o diretório existe antes de tentar acessar
  BACKEND_DIR="/home/deploy/${empresa}/backend"
  if [ ! -d "\$BACKEND_DIR" ]; then
    echo "ERRO: Diretório do backend não existe: \$BACKEND_DIR"
    echo "Verificando diretórios disponíveis em /home/deploy/${empresa}/..."
    ls -la /home/deploy/${empresa}/ 2>/dev/null || echo "Diretório /home/deploy/${empresa}/ não existe"
    exit 1
  fi
  
  cd "\$BACKEND_DIR"
  
  # Verifica se package.json existe
  if [ ! -f "package.json" ]; then
    echo "ERRO: package.json não encontrado em \$BACKEND_DIR"
    echo "Conteúdo do diretório:"
    ls -la
    exit 1
  fi
  
  export PUPPETEER_SKIP_DOWNLOAD=true
  rm -rf node_modules 2>/dev/null || true
  rm -f package-lock.json 2>/dev/null || true
  npm install --force
  npm install puppeteer-core --force
  npm i glob
  npm run build
BACKENDINSTALL

    sleep 2

    sudo su - deploy <<FFMPEGFIX
  BACKEND_DIR="/home/deploy/${empresa}/backend"
  FFMPEG_FILE="\${BACKEND_DIR}/node_modules/@ffmpeg-installer/ffmpeg/index.js"
  
  # Verifica se o arquivo existe antes de tentar modificá-lo
  if [ -f "\$FFMPEG_FILE" ]; then
    sed -i 's|npm3Binary = .*|npm3Binary = "/usr/bin/ffmpeg";|' "\$FFMPEG_FILE"
  else
    echo "Aviso: Arquivo ffmpeg-installer não encontrado. Pulando modificação."
  fi
  
  # Cria o diretório e arquivo se necessário
  mkdir -p "\${BACKEND_DIR}/node_modules/@ffmpeg-installer/linux-x64/" 2>/dev/null || true
  if [ -d "\${BACKEND_DIR}/node_modules/@ffmpeg-installer/linux-x64/" ]; then
    echo '{ "version": "1.1.0", "name": "@ffmpeg-installer/linux-x64" }' > "\${BACKEND_DIR}/node_modules/@ffmpeg-installer/linux-x64/package.json"
  fi
FFMPEGFIX

    sleep 2

    banner
    printf "${WHITE} >> Executando db:migrate...\n"
    echo
    sudo su - deploy <<MIGRATEINSTALL
  # Configura PATH para Node.js
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  
  BACKEND_DIR="/home/deploy/${empresa}/backend"
  if [ ! -d "\$BACKEND_DIR" ]; then
    echo "ERRO: Diretório do backend não existe: \$BACKEND_DIR"
    exit 1
  fi
  
  cd "\$BACKEND_DIR"
  npx sequelize db:migrate
MIGRATEINSTALL

    sleep 2

    banner
    printf "${WHITE} >> Executando db:seed...\n"
    echo
    sudo su - deploy <<SEEDINSTALL
  # Configura PATH para Node.js
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  
  BACKEND_DIR="/home/deploy/${empresa}/backend"
  if [ ! -d "\$BACKEND_DIR" ]; then
    echo "ERRO: Diretório do backend não existe: \$BACKEND_DIR"
    exit 1
  fi
  
  cd "\$BACKEND_DIR"
  npx sequelize db:seed:all
SEEDINSTALL

    sleep 2

    banner
    printf "${WHITE} >> Iniciando pm2 ${BLUE}backend${WHITE}...\n"
    echo
    sudo su - deploy <<PM2BACKEND
  # Configura PATH para Node.js e PM2
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  
  BACKEND_DIR="/home/deploy/${empresa}/backend"
  if [ ! -d "\$BACKEND_DIR" ]; then
    echo "ERRO: Diretório do backend não existe: \$BACKEND_DIR"
    exit 1
  fi
  
  cd "\$BACKEND_DIR"
  
  # Verifica se o arquivo dist/server.js existe
  if [ ! -f "dist/server.js" ]; then
    echo "ERRO: Arquivo dist/server.js não encontrado. O build pode ter falhado."
    exit 1
  fi
  
  pm2 start dist/server.js --name ${empresa}-backend
PM2BACKEND

    sleep 2
  } || trata_erro "instala_backend_base"
}

# Instala e configura frontend
instala_frontend_base() {
  banner
  printf "${WHITE} >> Instalando dependências do ${BLUE}frontend${WHITE}...\n"
  echo
  
  # Verifica se a variável empresa está definida
  if [ -z "${empresa}" ]; then
    printf "${RED} >> ERRO: Variável 'empresa' não está definida!\n${WHITE}"
    printf "${YELLOW} >> Carregando variáveis salvas...\n${WHITE}"
    carregar_variaveis
    if [ -z "${empresa}" ]; then
      printf "${RED} >> ERRO: Não foi possível carregar a variável 'empresa'. Abortando.\n${WHITE}"
      exit 1
    fi
  fi
  
  # Verifica se o diretório do código existe
  if [ ! -d "/home/deploy/${empresa}" ]; then
    printf "${RED} >> ERRO: Diretório /home/deploy/${empresa} não existe!\n${WHITE}"
    printf "${YELLOW} >> O código precisa ser clonado primeiro. Verifique a etapa anterior.\n${WHITE}"
    exit 1
  fi
  
  {
    sudo su - deploy <<FRONTENDINSTALL
  # Configura PATH para Node.js
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  
  FRONTEND_DIR="/home/deploy/${empresa}/frontend"
  if [ ! -d "\$FRONTEND_DIR" ]; then
    echo "ERRO: Diretório do frontend não existe: \$FRONTEND_DIR"
    exit 1
  fi
  
  cd "\$FRONTEND_DIR"
  
  # Verifica se package.json existe
  if [ ! -f "package.json" ]; then
    echo "ERRO: package.json não encontrado em \$FRONTEND_DIR"
    exit 1
  fi
  
  npm install --force
  npm install express dotenv --save
  npx browserslist@latest --update-db
FRONTENDINSTALL

    sleep 2

    banner
    printf "${WHITE} >> Configurando variáveis de ambiente ${BLUE}frontend${WHITE}...\n"
    echo
    subdominio_backend=$(echo "${subdominio_backend/https:\/\//}")
    subdominio_backend=${subdominio_backend%%/*}
    subdominio_backend=https://${subdominio_backend}
    frontend_chatbot_url=$(echo "${frontend_chatbot_url/https:\/\//}")
    frontend_chatbot_url=${frontend_chatbot_url%%/*}
    frontend_chatbot_url=https://${frontend_chatbot_url}
    sudo su - deploy <<EOF
  cat <<[-]EOF > /home/deploy/${empresa}/frontend/.env
REACT_APP_BACKEND_URL=${subdominio_backend}
REACT_APP_FACEBOOK_APP_ID=${facebook_app_id}
REACT_APP_REQUIRE_BUSINESS_MANAGEMENT=TRUE
REACT_APP_NAME_SYSTEM=${nome_titulo}
REACT_APP_NUMBER_SUPPORT=${numero_suporte}
SERVER_PORT=${frontend_port}
[-]EOF
EOF

    sleep 2

    banner
    printf "${WHITE} >> Compilando o código do ${BLUE}frontend${WHITE}...\n"
    echo
    sudo su - deploy <<FRONTENDBUILD
  # Configura PATH para Node.js
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  
  FRONTEND_DIR="/home/deploy/${empresa}/frontend"
  if [ ! -d "\$FRONTEND_DIR" ]; then
    echo "ERRO: Diretório do frontend não existe: \$FRONTEND_DIR"
    exit 1
  fi
  
  cd "\$FRONTEND_DIR"
  
  # Criar server.js se não existir
  if [ ! -f "server.js" ]; then
    echo "Criando arquivo server.js para servir o frontend..."
    cat > server.js << 'SERVERJS'
const express = require("express");
const path = require("path");
const app = express();
const dotenv = require("dotenv");

// Load environment variables
dotenv.config();

app.use(express.static(path.join(__dirname, "build")));
app.get("/*", function (req, res) {
    res.sendFile(path.join(__dirname, "build", "index.html"));
});

const port = process.env.PORT || 3000;

app.listen(port, () => {
    console.log(\`Server is running on port \${port}\`);
});
SERVERJS
    echo "Arquivo server.js criado com sucesso!"
  fi
  
  # Copiar arquivos necessários para o build
  if [ -f "\$FRONTEND_DIR/public/logo.png" ]; then
    cp "\$FRONTEND_DIR/public/logo.png" "\$FRONTEND_DIR/src/assets/logo.png"
    echo "Logo principal copiado para src/assets/"
  fi
  if [ -f "\$FRONTEND_DIR/public/logo-black.png" ]; then
    cp "\$FRONTEND_DIR/public/logo-black.png" "\$FRONTEND_DIR/src/assets/logo-black.png"
    echo "Logo black copiado para src/assets/"
  fi
  if [ -f "\$FRONTEND_DIR/public/favicon.ico" ]; then
    cp "\$FRONTEND_DIR/public/favicon.ico" "\$FRONTEND_DIR/src/assets/favicon.ico"
    echo "Favicon copiado para src/assets/"
  fi
  
  sed -i 's/3000/'"${frontend_port}"'/g' server.js
  NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" npm run build
FRONTENDBUILD

    sleep 2

    banner
    printf "${WHITE} >> Iniciando pm2 ${BLUE}frontend${WHITE}...\n"
    echo
    sudo su - deploy <<PM2FRONTEND
  # Configura PATH para Node.js e PM2
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:\$PATH
  fi
  
  FRONTEND_DIR="/home/deploy/${empresa}/frontend"
  if [ ! -d "\$FRONTEND_DIR" ]; then
    echo "ERRO: Diretório do frontend não existe: \$FRONTEND_DIR"
    exit 1
  fi
  
  cd "\$FRONTEND_DIR"
  
  pm2 start server.js --name ${empresa}-frontend
  pm2 save
PM2FRONTEND

    sleep 2
  } || trata_erro "instala_frontend_base"
}

# ==================== FUNÇÕES DA API OFICIAL ====================

# Verificar DNS da API Oficial
verificar_dns_apioficial() {
  if [ "${instalar_api_oficial}" != "s" ]; then
    printf "${YELLOW} >> Pulando verificação DNS da API Oficial (não será instalada)...${WHITE}\n"
    return 0
  fi
  
  banner
  printf "${WHITE} >> Verificando o DNS do subdomínio da API Oficial...\n"
  printf "${YELLOW} >> Subdomínio: ${subdominio_oficial}${WHITE}\n"
  echo
  sleep 2

  if ! command -v dig &> /dev/null; then
      sudo apt-get update >/dev/null 2>&1
      sudo apt-get install dnsutils -y >/dev/null 2>&1
  fi

  local domain=${subdominio_oficial}
  local resolved_ip

  if [ -z "${domain}" ]; then
      printf "${RED} >> ERRO: Subdomínio da API Oficial está vazio.${WHITE}\n"
      return 1
  fi

  # Consulta DNS (A record)
  resolved_ip=$(dig +short ${domain} @8.8.8.8)

  if [[ "${resolved_ip}" != "${ip_atual}"* ]] || [ -z "${resolved_ip}" ]; then
      echo "AVISO: O domínio ${domain} (resolvido para ${resolved_ip}) não está apontando para o IP público atual (${ip_atual})."
      echo
      printf "${YELLOW} >> AVISO: Verifique o apontamento de DNS do subdomínio: ${subdominio_oficial}${WHITE}\n"
      printf "${YELLOW} >> A instalação continuará, mas o SSL pode falhar.${WHITE}\n"
      sleep 5
  else
      echo "Subdomínio ${domain} está apontando corretamente para o IP público da VPS."
      sleep 2
  fi
  echo
  printf "${WHITE} >> Continuando...\n"
  sleep 2
  echo
}

# Configurar Nginx para API Oficial
configurar_nginx_apioficial() {
  if [ "${instalar_api_oficial}" != "s" ]; then
    printf "${YELLOW} >> Pulando configuração da API Oficial (não será instalada)...${WHITE}\n"
    return 0
  fi
  
  if [ -z "${subdominio_oficial}" ]; then
    printf "${RED} >> ERRO: subdominio_oficial está vazio! Pulando configuração da API Oficial.${WHITE}\n"
    return 0
  fi
  
  banner
  printf "${WHITE} >> Configurando Nginx para API Oficial...\n"
  printf "${YELLOW} >> Subdomínio: ${subdominio_oficial}${WHITE}\n"
  echo

  local sites_available_path="/etc/nginx/sites-available/${empresa}-oficial"
  local sites_enabled_link="/etc/nginx/sites-enabled/${empresa}-oficial"

  # Remove configurações antigas se existirem
  if [ -L "${sites_enabled_link}" ]; then
      printf "${YELLOW} >> Removendo link simbólico antigo...${WHITE}\n"
      sudo rm -f "${sites_enabled_link}"
  fi

  if [ -f "${sites_available_path}" ]; then
      printf "${YELLOW} >> Removendo arquivo de configuração antigo...${WHITE}\n"
      sudo rm -f "${sites_available_path}"
  fi

  {
      local oficial_hostname=${subdominio_oficial} 
      
      # Criação do arquivo de configuração do Nginx
      sudo cat > ${sites_available_path} << EOF
# Configuração Nginx para API Oficial
# Subdomínio: ${oficial_hostname}
# Porta: ${default_apioficial_port}
upstream oficial {
    server 127.0.0.1:${default_apioficial_port};
    keepalive 32;
}
server {
    server_name ${oficial_hostname};
    location / {
        proxy_pass http://oficial;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering on;
    }
}
EOF

      sudo ln -sf ${sites_available_path} ${sites_enabled_link}
      sleep 2
      
      # Recarrega Nginx
      sudo systemctl reload nginx 

      banner
      printf "${WHITE} >> Emitindo SSL para https://${subdominio_oficial}...\n"
      echo
      local oficial_domain=${subdominio_oficial}
      
      if [ -z "${email_deploy}" ]; then
          printf "${RED} >> ERRO: O email para o Certbot não foi encontrado.${WHITE}\n"
          return 1
      fi
      
      if [ -z "${oficial_domain}" ]; then
          printf "${RED} >> ERRO: Domínio da API Oficial está vazio!${WHITE}\n"
          return 1
      fi

      printf "${GREEN} >> ==================================================${WHITE}\n"
      printf "${GREEN} >> EMITINDO SSL PARA API OFICIAL${WHITE}\n"
      printf "${GREEN} >> Domínio: ${oficial_domain}${WHITE}\n"
      printf "${GREEN} >> Email: ${email_deploy}${WHITE}\n"
      printf "${GREEN} >> Arquivo Nginx: ${sites_available_path}${WHITE}\n"
      printf "${GREEN} >> ==================================================${WHITE}\n"
      echo
      
      sudo certbot -m "${email_deploy}" \
                  --nginx \
                  --agree-tos \
                  -n \
                  -d "${oficial_domain}"
      
      if [ $? -ne 0 ]; then
          printf "${RED} >> ERRO: Falha ao emitir o certificado SSL/TLS para ${oficial_domain}.${WHITE}\n"
          printf "${YELLOW} >> A instalação continuará sem SSL. Configure manualmente depois.${WHITE}\n"
          sleep 5
      fi

      sleep 2
  } || trata_erro "configurar_nginx_apioficial"
}

# Criar banco de dados para API Oficial
criar_banco_apioficial() {
  if [ "${instalar_api_oficial}" != "s" ]; then
    return 0
  fi
  
  banner
  printf "${WHITE} >> Criando banco de dados 'oficialseparado' para API Oficial...\n"
  echo
  {
      if [ -z "${empresa}" ] || [ -z "${senha_deploy}" ]; then
          printf "${RED} >> ERRO: Variáveis 'empresa' ou 'senha_deploy' não estão definidas!${WHITE}\n"
          return 1
      fi
      
      sudo -u postgres psql <<EOF
CREATE DATABASE oficialseparado WITH OWNER ${empresa};
\q
EOF
      printf "${GREEN} >> Banco de dados 'oficialseparado' criado com sucesso!${WHITE}\n"
      sleep 2
  } || trata_erro "criar_banco_apioficial"
}

# Configurar arquivo .env da API Oficial
configurar_env_apioficial() {
  if [ "${instalar_api_oficial}" != "s" ]; then
    return 0
  fi
  
  banner
  printf "${WHITE} >> Configurando arquivo .env da API Oficial...\n"
  echo
  {
      local backend_env_path="/home/deploy/${empresa}/backend/.env"
      local jwt_refresh_secret_backend=$(grep "^JWT_REFRESH_SECRET=" "${backend_env_path}" 2>/dev/null | cut -d '=' -f2-)
      local backend_url_full=$(grep "^BACKEND_URL=" "${backend_env_path}" 2>/dev/null | cut -d '=' -f2-)
      
      if [ -z "${jwt_refresh_secret_backend}" ] || [ -z "${backend_url_full}" ]; then
      	printf "${RED} >> ERRO: Não foi possível obter JWT_REFRESH_SECRET ou BACKEND_URL do backend principal.${WHITE}\n"
      	return 1
      fi

      local api_oficial_dir="/home/deploy/${empresa}/api_oficial"
      
      # Ajusta permissões do diretório
      mkdir -p "${api_oficial_dir}"
      chown -R deploy:deploy "${api_oficial_dir}"
      
      # Cria o arquivo .env
      sudo -u deploy cat > "${api_oficial_dir}/.env" <<EOF
# Configurações de acesso ao Banco de Dados (Postgres)
DATABASE_LINK=postgresql://${empresa}:${senha_deploy}@localhost:5432/oficialseparado?schema=public
DATABASE_URL=localhost
DATABASE_PORT=5432
DATABASE_USER=${empresa}
DATABASE_PASSWORD=${senha_deploy}
DATABASE_NAME=oficialseparado

# Configurações do MultiFlow Backend (URL Completa com https://)
TOKEN_ADMIN=adminpro
URL_BACKEND_MULT100=${backend_url_full}
JWT_REFRESH_SECRET=${jwt_refresh_secret_backend}

# Configurações da API Oficial
REDIS_URI=redis://:${senha_deploy}@127.0.0.1:6379
PORT=${default_apioficial_port}
URL_API_OFICIAL=${subdominio_oficial}

# Configurações de Usuário Inicial
NAME_ADMIN=SetupAutomatizado
EMAIL_ADMIN=admin@multi100.com.br
PASSWORD_ADMIN=adminpro
EOF

      printf "${GREEN} >> Arquivo .env da API Oficial configurado com sucesso!${WHITE}\n"
      sleep 2
  } || trata_erro "configurar_env_apioficial"
}

# Instalar e configurar API Oficial
instalar_apioficial() {
  if [ "${instalar_api_oficial}" != "s" ]; then
    return 0
  fi
  
  banner
  printf "${WHITE} >> Instalando e configurando API Oficial...\n"
  echo
  {
      local api_oficial_dir="/home/deploy/${empresa}/api_oficial"
      
      chown -R deploy:deploy "${api_oficial_dir}"

      sudo su - deploy <<INSTALL_API
# Configura PATH para Node.js (PM2, npm, npx)
if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
  export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
else
  export PATH=/usr/bin:/usr/local/bin:\$PATH
fi

cd ${api_oficial_dir}

printf "${WHITE} >> Instalando dependências (npm install)...\n"
npm install --force

printf "${WHITE} >> Gerando Prisma (npx prisma generate)...\n"
npx prisma generate

printf "${WHITE} >> Buildando aplicação (npm run build)...\n"
npm run build

printf "${WHITE} >> Executando migrações (npx prisma migrate deploy)...\n"
npx prisma migrate deploy

printf "${WHITE} >> Gerando cliente Prisma (npx prisma generate client)...\n"
npx prisma generate client

printf "${WHITE} >> Iniciando aplicação com PM2...\n"
pm2 start dist/main.js --name=${empresa}-api_oficial
pm2 save

printf "${GREEN} >> API Oficial instalada e configurada com sucesso!${WHITE}\n"
sleep 2
INSTALL_API
  } || trata_erro "instalar_apioficial"
}

# Atualizar .env do backend com URL da API Oficial
atualizar_env_backend_apioficial() {
  if [ "${instalar_api_oficial}" != "s" ]; then
    return 0
  fi
  
  banner
  printf "${WHITE} >> Atualizando .env do backend com URL da API Oficial...\n"
  echo
  {
      local backend_env_path="/home/deploy/${empresa}/backend/.env"
      
      local new_url="URL_API_OFICIAL=https://${subdominio_oficial}"
      
      # Ativa USE_WHATSAPP_OFICIAL
      if ! grep -q "^USE_WHATSAPP_OFICIAL=true" "${backend_env_path}"; then
          sudo sed -i 's|^USE_WHATSAPP_OFICIAL=.*|USE_WHATSAPP_OFICIAL=true|' "${backend_env_path}" || echo "USE_WHATSAPP_OFICIAL=true" | sudo tee -a "${backend_env_path}" >/dev/null
      fi

      # Substitui ou adiciona URL_API_OFICIAL
      if grep -q "^URL_API_OFICIAL=" "${backend_env_path}"; then
          sudo sed -i "s|^URL_API_OFICIAL=.*|${new_url}|" "${backend_env_path}"
      else
          echo "${new_url}" | sudo tee -a "${backend_env_path}" >/dev/null
      fi
      
      # Reiniciar o Backend
      sudo su - deploy <<RESTART_BACKEND
if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
  export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:\$PATH
else
  export PATH=/usr/bin:/usr/local/bin:\$PATH
fi
pm2 reload ${empresa}-backend
RESTART_BACKEND

      printf "${GREEN} >> .env do backend atualizado e backend reiniciado!${WHITE}\n"
      sleep 2
  } || trata_erro "atualizar_env_backend_apioficial"
}

# ==================== FIM DAS FUNÇÕES DA API OFICIAL ====================

# Configura cron de atualização de dados da pasta public
config_cron_base() {
  printf "${GREEN} >> Adicionando cron atualizar o uso da public às 3h da manhã...${WHITE} \n"
  echo
  {
    if ! command -v cron >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y cron
    fi
    sleep 2
    wget -O /home/deploy/atualiza_public.sh https://raw.githubusercontent.com/FilipeCamillo/busca_tamaho_pasta/main/busca_tamaho_pasta.sh >/dev/null 2>&1
    chmod +x /home/deploy/atualiza_public.sh >/dev/null 2>&1
    chown deploy:deploy /home/deploy/atualiza_public.sh >/dev/null 2>&1
    echo '#!/bin/bash
# Configura PATH para Node.js e PM2
if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
  export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:$PATH
elif [ -f /usr/bin/node ]; then
  export PATH=/usr/bin:/usr/local/bin:$PATH
else
  # Tenta encontrar node no sistema
  NODE_DIR=$(find /usr -type d -name "node" -o -type f -name "node" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
  if [ -n "$NODE_DIR" ]; then
    export PATH=$NODE_DIR:/usr/bin:$PATH
  fi
fi
pm2 restart all' >/home/deploy/reinicia_instancia.sh
    chmod +x /home/deploy/reinicia_instancia.sh
    chown deploy:deploy /home/deploy/reinicia_instancia.sh >/dev/null 2>&1
    sudo su - deploy <<'EOF'
        CRON_JOB1="0 3 * * * wget -O /home/deploy/atualiza_public.sh https://raw.githubusercontent.com/FilipeCamillo/busca_tamaho_pasta/main/busca_tamaho_pasta.sh && bash /home/deploy/atualiza_public.sh >> /home/deploy/cron.log 2>&1"
        CRON_JOB2="0 1 * * * /bin/bash /home/deploy/reinicia_instancia.sh >> /home/deploy/cron.log 2>&1"
        CRON_EXISTS1=$(crontab -l 2>/dev/null | grep -F "${CRON_JOB1}")
        CRON_EXISTS2=$(crontab -l 2>/dev/null | grep -F "${CRON_JOB2}")

        if [[ -z "${CRON_EXISTS1}" ]] || [[ -z "${CRON_EXISTS2}" ]]; then
            printf "${GREEN} >> Cron não detectado, agendando agora...${WHITE} "
            {
                crontab -l 2>/dev/null
                [[ -z "${CRON_EXISTS1}" ]] && echo "${CRON_JOB1}"
                [[ -z "${CRON_EXISTS2}" ]] && echo "${CRON_JOB2}"
            } | crontab -
        else
            printf "${GREEN} >> Crons já existem, continuando...${WHITE} \n"
        fi
EOF

    sleep 2
  } || trata_erro "config_cron_base"
}

# Configura Nginx
config_nginx_base() {
  banner
  printf "${WHITE} >> Configurando nginx ${BLUE}frontend${WHITE}...\n"
  echo
  {
    frontend_hostname=$(echo "${subdominio_frontend/https:\/\//}")
    sudo su - root <<EOF
cat > /etc/nginx/sites-available/${empresa}-frontend << 'END'
# Configuração Nginx para FRONTEND
# Subdomínio: ${frontend_hostname}
# Porta: ${frontend_port}
server {
  server_name ${frontend_hostname};
  location / {
    proxy_pass http://127.0.0.1:${frontend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
END
ln -s /etc/nginx/sites-available/${empresa}-frontend /etc/nginx/sites-enabled
EOF

    sleep 2

    banner
    printf "${WHITE} >> Configurando Nginx ${BLUE}backend${WHITE}...\n"
    echo
    backend_hostname=$(echo "${subdominio_backend/https:\/\//}")
    sudo su - root <<EOF
cat > /etc/nginx/sites-available/${empresa}-backend << 'END'
# Configuração Nginx para BACKEND
# Subdomínio: ${backend_hostname}
# Porta: ${backend_port}
upstream backend {
        server 127.0.0.1:${backend_port};
        keepalive 32;
    }
server {
  server_name ${backend_hostname};
  location / {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
    proxy_buffering on;
  }
}
END
ln -s /etc/nginx/sites-available/${empresa}-backend /etc/nginx/sites-enabled
EOF

    sleep 2

    banner
    printf "${WHITE} >> Emitindo SSL do ${subdominio_backend}...\n"
    echo
    backend_domain=$(echo "${subdominio_backend/https:\/\//}")
    
    printf "${GREEN} >> ==================================================${WHITE}\n"
    printf "${GREEN} >> EMITINDO SSL PARA BACKEND${WHITE}\n"
    printf "${GREEN} >> Domínio: ${backend_domain}${WHITE}\n"
    printf "${GREEN} >> Email: ${email_deploy}${WHITE}\n"
    printf "${GREEN} >> ==================================================${WHITE}\n"
    echo
    
    sudo su - root <<EOF
    certbot -m ${email_deploy} \
            --nginx \
            --agree-tos \
            -n \
            -d ${backend_domain}
EOF

    sleep 2

    banner
    printf "${WHITE} >> Emitindo SSL do ${subdominio_frontend}...\n"
    echo
    frontend_domain=$(echo "${subdominio_frontend/https:\/\//}")
    
    printf "${GREEN} >> ==================================================${WHITE}\n"
    printf "${GREEN} >> EMITINDO SSL PARA FRONTEND${WHITE}\n"
    printf "${GREEN} >> Domínio: ${frontend_domain}${WHITE}\n"
    printf "${GREEN} >> Email: ${email_deploy}${WHITE}\n"
    printf "${GREEN} >> ==================================================${WHITE}\n"
    echo
    
    sudo su - root <<EOF
    certbot -m ${email_deploy} \
            --nginx \
            --agree-tos \
            -n \
            -d ${frontend_domain}
EOF

    sleep 2
  } || trata_erro "config_nginx_base"
}

# Configura Traefik
config_traefik_base() {
  {
    source /home/deploy/${empresa}/backend/.env
    subdominio_backend=$(echo ${BACKEND_URL} | sed 's|https://||')
    subdominio_frontend=$(echo ${FRONTEND_URL} | sed 's|https://||')
    sudo su - root <<EOF
cat > /etc/traefik/conf.d/routers-${subdominio_backend}.toml << 'END'
[http.routers]
  [http.routers.backend]
    rule = "Host(\`${subdominio_backend}\`)"
    service = "backend"
    entryPoints = ["web"]
    middlewares = ["https-redirect"]

  [http.routers.backend-secure]
    rule = "Host(\`${subdominio_backend}\`)"
    service = "backend"
    entryPoints = ["websecure"]
    [http.routers.backend-secure.tls]
      certResolver = "letsencryptresolver"

[http.services]
  [http.services.backend]
    [http.services.backend.loadBalancer]
      [[http.services.backend.loadBalancer.servers]]
        url = "http://127.0.0.1:${backend_port}"

[http.middlewares]
  [http.middlewares.https-redirect.redirectScheme]
    scheme = "https"
    permanent = true
END
EOF

    sleep 2

    sudo su - root <<EOF
cat > /etc/traefik/conf.d/routers-${subdominio_frontend}.toml << 'END'
[http.routers]
  [http.routers.frontend]
    rule = "Host(\`${subdominio_frontend}\`)"
    service = "frontend"
    entryPoints = ["web"]
    middlewares = ["https-redirect"]

  [http.routers.frontend-secure]
    rule = "Host(\`${subdominio_frontend}\`)"
    service = "frontend"
    entryPoints = ["websecure"]
    [http.routers.frontend-secure.tls]
      certResolver = "letsencryptresolver"

[http.services]
  [http.services.frontend]
    [http.services.frontend.loadBalancer]
      [[http.services.frontend.loadBalancer.servers]]
        url = "http://127.0.0.1:${frontend_port}"

[http.middlewares]
  [http.middlewares.https-redirect.redirectScheme]
    scheme = "https"
    permanent = true
END
EOF

    sleep 2
  } || trata_erro "config_traefik_base"
}

# Ajusta latência - necessita reiniciar a VPS para funcionar de fato
config_latencia_base() {
  banner
  printf "${WHITE} >> Reduzindo Latência...\n"
  echo
  {
    sudo su - root <<EOF
cat >> /etc/hosts << 'END'
127.0.0.1   ${subdominio_backend}
127.0.0.1   ${subdominio_frontend}
END
EOF

    sleep 2

    sudo su - deploy <<'RESTARTPM2'
  # Configura PATH para Node.js e PM2
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:$PATH
  fi
  pm2 restart all
RESTARTPM2

    sleep 2
  } || trata_erro "config_latencia_base"
}

# Finaliza a instalação e mostra dados de acesso
fim_instalacao_base() {
  banner
  printf "   ${GREEN} >> Instalação concluída...\n"
  echo
  printf "   ${WHITE}Backend: ${BLUE}${subdominio_backend}\n"
  printf "   ${WHITE}Frontend: ${BLUE}${subdominio_frontend}\n"
  if [ "${instalar_api_oficial}" == "s" ]; then
    printf "   ${WHITE}API Oficial: ${BLUE}https://${subdominio_oficial}\n"
  fi
  echo
  printf "   ${WHITE}Usuário ${BLUE}admin@multi100.com.br\n"
  printf "   ${WHITE}Senha   ${BLUE}adminpro\n"
  echo
  printf "${WHITE}>> Aperte qualquer tecla para voltar ao menu principal ou CTRL+C Para finalizar esse script\n"
  read -p ""
  echo
}

################################################################
#                         ATUALIZAÇÃO                          #
################################################################

# Garante Deploy Key e remote Git antes do fetch (instalação manual pode não ter chave nem .git)
preparar_git_para_atualizacao() {
  if [ ! -d "/home/deploy/${empresa}" ]; then
    printf "${RED} >> ERRO: Diretório /home/deploy/${empresa} não existe. Atualização apenas para instalação existente.${WHITE}\n"
    exit 1
  fi

  # Instalação manual: diretório existe mas não é repositório Git — inicializa e alinha com o remoto
  if [ ! -d "/home/deploy/${empresa}/.git" ]; then
    printf "${YELLOW} >> O diretório da aplicação não é um repositório Git (instalação manual).${WHITE}\n"
    printf "${WHITE} >> Inicializando Git e alinhando com o repositório remoto (branch: ${repo_branch:-main})...${WHITE}\n"
    echo
    if [ "${repo_auth_type}" = "ssh" ]; then
      # Garante que a Deploy Key existe (gera e exibe se não existir)
      if [ ! -f "/home/deploy/.ssh/id_rsa" ]; then
        printf "${WHITE} >> Deploy Key não encontrada. Gerando e configurando...${WHITE}\n"
        configura_deploy_key_ssh || exit 1
      else
        # Configura known_hosts para GitHub se ainda não estiver (evita prompt)
        sudo su - deploy <<'SSHCONFIG' 2>/dev/null || true
          mkdir -p ~/.ssh
          chmod 700 ~/.ssh
          [ -f ~/.ssh/id_rsa ] && chmod 600 ~/.ssh/id_rsa
          [ -f ~/.ssh/id_rsa.pub ] && chmod 644 ~/.ssh/id_rsa.pub
          grep -q github.com ~/.ssh/known_hosts 2>/dev/null || ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null
SSHCONFIG
      fi
      # Testa acesso ao repositório ANTES de init/fetch (sem precisar de .git)
      printf "${WHITE} >> Testando acesso ao repositório: ${BLUE}${repo_url}${WHITE}\n"
      if ! sudo -u deploy env GIT_SSH_COMMAND="ssh -i /home/deploy/.ssh/id_rsa -o StrictHostKeyChecking=accept-new" git ls-remote "${repo_url}" HEAD &>/dev/null; then
        banner
        printf "${YELLOW} >> Ainda não há acesso ao repositório. Adicione a Deploy Key no GitHub.${WHITE}\n"
        printf "${WHITE} >> Repositório: ${BLUE}${repo_url}${WHITE}\n"
        printf "${WHITE} >> No GitHub: Settings > Deploy keys > Add deploy key${WHITE}\n"
        echo
        printf "${GREEN} >> Chave Pública SSH (Deploy Key):${WHITE}\n"
        printf "${YELLOW}══════════════════════════════════════════════════════════════════${WHITE}\n"
        echo
        sudo cat /home/deploy/.ssh/id_rsa.pub
        echo
        printf "${YELLOW}══════════════════════════════════════════════════════════════════${WHITE}\n"
        echo
        read -p "Após adicionar a Deploy Key no GitHub, pressione Enter para continuar..."
        if ! sudo -u deploy env GIT_SSH_COMMAND="ssh -i /home/deploy/.ssh/id_rsa -o StrictHostKeyChecking=accept-new" git ls-remote "${repo_url}" HEAD &>/dev/null; then
          printf "${RED} >> ERRO: Acesso ao repositório falhou. Verifique a Deploy Key e tente novamente.${WHITE}\n"
          exit 1
        fi
      fi
      printf "${GREEN} >> Acesso ao repositório OK. Inicializando Git no diretório da aplicação...${WHITE}\n"
      echo
      sudo su - deploy <<INITGIT
        set -e
        cd /home/deploy/${empresa}
        git init
        git remote add origin "${repo_url}"
        env GIT_SSH_COMMAND="ssh -i /home/deploy/.ssh/id_rsa -o StrictHostKeyChecking=accept-new" git fetch origin
        git checkout -B "${repo_branch:-main}" "origin/${repo_branch:-main}"
INITGIT
    else
      sudo su - deploy <<INITGIT
        set -e
        cd /home/deploy/${empresa}
        git init
        git remote add origin "${repo_url}"
        git fetch origin
        git checkout -B "${repo_branch:-main}" "origin/${repo_branch:-main}"
INITGIT
    fi
    chown deploy:deploy -R "/home/deploy/${empresa}"
    printf "${GREEN} >> Repositório Git inicializado e alinhado com o remoto.${WHITE}\n"
    echo
    return 0
  fi

  if [ "${repo_auth_type}" = "ssh" ]; then
    if [ ! -f "/home/deploy/.ssh/id_rsa" ]; then
      printf "${WHITE} >> Deploy Key não encontrada. Configurando...${WHITE}\n"
      configura_deploy_key_ssh || exit 1
    fi

    sudo -u deploy git -C "/home/deploy/${empresa}" remote set-url origin "${repo_url}" 2>/dev/null || true
    printf "${WHITE} >> Testando acesso ao repositório: ${BLUE}${repo_url}${WHITE}\n"
    printf "${WHITE} >> (A Deploy Key deve estar em Settings > Deploy keys desse repositório no GitHub.)\n"
    echo
    if ! sudo -u deploy env GIT_SSH_COMMAND="ssh -i /home/deploy/.ssh/id_rsa -o StrictHostKeyChecking=accept-new" git -C "/home/deploy/${empresa}" fetch origin 2>&1; then
      banner
      printf "${YELLOW} >> Falha ao acessar o repositório. Confirme que a Deploy Key foi adicionada no GitHub.${WHITE}\n"
      printf "${WHITE} >> Repositório esperado: ${BLUE}${repo_url}${WHITE}\n"
      echo
      printf "${GREEN} >> Chave Pública SSH (Deploy Key):${WHITE}\n"
      printf "${YELLOW}══════════════════════════════════════════════════════════════════${WHITE}\n"
      echo
      sudo cat /home/deploy/.ssh/id_rsa.pub
      echo
      printf "${YELLOW}══════════════════════════════════════════════════════════════════${WHITE}\n"
      printf "${WHITE} >> No GitHub: Settings > Deploy keys > Add deploy key | Cole a chave acima${WHITE}\n"
      echo
      read -p "Após adicionar a Deploy Key no GitHub, pressione Enter para tentar novamente..."
      if ! sudo -u deploy env GIT_SSH_COMMAND="ssh -i /home/deploy/.ssh/id_rsa -o StrictHostKeyChecking=accept-new" git -C "/home/deploy/${empresa}" fetch origin; then
        printf "${RED} >> ERRO: Ainda sem acesso ao repositório. Verifique a Deploy Key e tente novamente.${WHITE}\n"
        exit 1
      fi
    fi
  else
    # HTTPS ou outro: apenas garante remote com a URL do VARIAVEIS_INSTALACAO
    sudo -u deploy git -C "/home/deploy/${empresa}" remote set-url origin "${repo_url}" 2>/dev/null || true
  fi
}

backup_app_atualizar() {
  carregar_variaveis
  {
    banner
    printf "${WHITE} >> Antes de atualizar deseja fazer backup do banco de dados? ${GREEN}S/${RED}N:${WHITE}\n"
    echo
    read -p "> " confirmacao_backup
    echo
    confirmacao_backup=$(echo "${confirmacao_backup}" | tr '[:lower:]' '[:upper:]')
    if [ "${confirmacao_backup}" == "S" ]; then
      db_password=$(grep -E '^DB_PASS=' "/home/deploy/${empresa}/backend/.env" 2>/dev/null | cut -d '=' -f2- | tr -d '\r"' || true)
      [ ! -d "/home/deploy/backups" ] && mkdir -p "/home/deploy/backups"
      backup_file="/home/deploy/backups/${empresa}_$(date +%d-%m-%Y_%Hh).sql"
      PGPASSWORD="${db_password}" pg_dump -U ${empresa} -h localhost ${empresa} >"${backup_file}"
      printf "${GREEN} >> Backup do banco de dados ${empresa} concluído. Arquivo de backup: ${backup_file}\n"
      sleep 2
    else
      printf " >> Continuando a atualização...\n"
      echo
    fi

    sleep 2
  } || trata_erro "backup_app_atualizar"
}

baixa_codigo_atualizar() {
  # Carrega variáveis da instalação (empresa, repo_branch, etc.)
  carregar_variaveis
  if [ -z "${empresa}" ]; then
    printf "${RED} >> ERRO: Variável 'empresa' não está definida! Verifique o arquivo VARIAVEIS_INSTALACAO.\n${WHITE}"
    exit 1
  fi
  if [ ! -d "/home/deploy/${empresa}" ]; then
    printf "${RED} >> ERRO: Diretório /home/deploy/${empresa} não existe!\n${WHITE}"
    exit 1
  fi

  banner
  printf "${WHITE} >> Recuperando Permissões... \n"
  echo
  sleep 2
  chown deploy -R /home/deploy/${empresa}
  chmod 775 -R /home/deploy/${empresa}

  sleep 2

  banner
  printf "${WHITE} >> Parando Instancias... \n"
  echo
  sleep 2
  sudo su - deploy <<'STOPPM2'
  # Configura PATH para Node.js e PM2
  if [ -d /usr/local/n/versions/node/20.19.4/bin ]; then
    export PATH=/usr/local/n/versions/node/20.19.4/bin:/usr/bin:/usr/local/bin:$PATH
  else
    export PATH=/usr/bin:/usr/local/bin:$PATH
  fi
  pm2 stop all
STOPPM2

  sleep 2

  otimiza_banco_atualizar

  banner
  printf "${WHITE} >> Atualizando a Aplicação... \n"
  echo
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
  npm install --force
  npm install puppeteer-core --force
  npm i glob
  npm run build
  sleep 2
  printf "${WHITE} >> Atualizando Banco...\n"
  echo
  sleep 2
  npx sequelize db:migrate
  sleep 2
  printf "${WHITE} >> Atualizando Frontend...\n"
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
  npm install --force
  npm install express dotenv --save
  
  # Criar server.js se não existir
  if [ ! -f "server.js" ]; then
    echo "Criando arquivo server.js para servir o frontend..."
    cat > server.js << 'SERVERJS'
const express = require("express");
const path = require("path");
const app = express();
const dotenv = require("dotenv");

// Load environment variables
dotenv.config();

app.use(express.static(path.join(__dirname, "build")));
app.get("/*", function (req, res) {
    res.sendFile(path.join(__dirname, "build", "index.html"));
});

const port = process.env.PORT || 3000;

app.listen(port, () => {
    console.log(\`Server is running on port \${port}\`);
});
SERVERJS
  fi
  
  sed -i 's/3000/'"$frontend_port"'/g' server.js
  
  NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider" npm run build
  sleep 2
  pm2 flush
  pm2 reset all
  pm2 restart all
  pm2 save
  pm2 startup
UPDATEAPP

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
  menu
}

otimiza_banco_atualizar() {
  banner
  printf "${WHITE} >> Realizando Manutenção do Banco de Dados... \n"
  echo
  {
    db_password=$(grep "DB_PASS=" /home/deploy/${empresa}/backend/.env | cut -d '=' -f2)
    sudo su - root <<EOF
    PGPASSWORD="$db_password" vacuumdb -U "${empresa}" -h localhost -d "${empresa}" --full --analyze
    PGPASSWORD="$db_password" psql -U ${empresa} -h 127.0.0.1 -d ${empresa} -c "REINDEX DATABASE ${empresa};"
    PGPASSWORD="$db_password" psql -U ${empresa} -h 127.0.0.1 -d ${empresa} -c "ANALYZE;"
EOF

    sleep 2
  } || trata_erro "otimiza_banco_atualizar"
}

# Adicionar função para instalar transcrição de áudio nativa
instalar_transcricao_audio_nativa() {
  banner
  printf "${WHITE} >> Instalando Transcrição de Áudio Nativa...\n"
  echo
  local script_path="/home/deploy/${empresa}/api_transcricao/install-python-app.sh"
  if [ -f "$script_path" ]; then
    chmod 775 "$script_path"
    bash "$script_path"
  else
    printf "${RED} >> Script não encontrado em: $script_path${WHITE}\n"
    sleep 2
  fi
  printf "${GREEN} >> Processo de instalação da transcrição finalizado. Voltando ao menu...${WHITE}\n"
  sleep 2
}

# Adicionar função para instalar API Oficial
instalar_api_oficial() {
  banner
  printf "${WHITE} >> Instalando API Oficial...\n"
  echo
  local script_path="$(pwd)/instalador_apioficial.sh"
  if [ -f "$script_path" ]; then
    chmod 775 "$script_path"
    bash "$script_path"
  else
    printf "${RED} >> Script não encontrado em: $script_path${WHITE}\n"
    sleep 2
  fi
  printf "${GREEN} >> Processo de instalação da API Oficial finalizado. Voltando ao menu...${WHITE}\n"
  sleep 2
}

# Adicionar função para atualizar API Oficial
atualizar_api_oficial() {
  banner
  printf "${WHITE} >> Atualizando API Oficial...\n"
  echo
  local script_path="$(pwd)/atualizar_apioficial.sh"
  if [ -f "$script_path" ]; then
    chmod 775 "$script_path"
    bash "$script_path"
  else
    printf "${RED} >> Script não encontrado em: $script_path${WHITE}\n"
    sleep 2
  fi
  printf "${GREEN} >> Processo de atualização da API Oficial finalizado. Voltando ao menu...${WHITE}\n"
  sleep 2
}

# Adicionar função para migrar para Multiflow-PRO
migrar_multiflow_pro() {
  banner
  printf "${WHITE} >> Migrando para Multiflow-PRO...\n"
  echo
  local script_path="$(pwd)/atualizador_pro.sh"
  if [ -f "$script_path" ]; then
    chmod 775 "$script_path"
    bash "$script_path"
  else
    printf "${RED} >> Script não encontrado em: $script_path${WHITE}\n"
    printf "${RED} >> Certifique-se de que o arquivo atualizador_pro.sh está no mesmo diretório do instalador.${WHITE}\n"
    sleep 2
  fi
  printf "${GREEN} >> Processo de migração para Multiflow-PRO finalizado. Voltando ao menu...${WHITE}\n"
  sleep 2
}

carregar_variaveis
menu
