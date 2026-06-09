#!/bin/bash
# Credenciais padrão do CRM (seed: backend/src/database/seeds/20200904070006-create-default-user.ts)

DEFAULT_ADMIN_EMAIL="admin@equipechat.com"
DEFAULT_ADMIN_PASSWORD="adminpro"
DEFAULT_API_TOKEN="adminpro"

exibir_credenciais_crm() {
  printf "   ${WHITE}Login CRM — Usuário: ${BLUE}%s${WHITE}\n" "${DEFAULT_ADMIN_EMAIL}"
  printf "   ${WHITE}Login CRM — Senha:   ${BLUE}%s${WHITE}\n" "${DEFAULT_ADMIN_PASSWORD}"
  printf "   ${YELLOW}   (a Senha Master informada na instalação também funciona como senha de login)${WHITE}\n"
}
