# Scripts de Instalação - CRM AI9

Scripts automatizados para instalação do CRM completo (Backend + Frontend + API Oficial) em servidores Ubuntu.

## 🚀 Instalação Rápida

### Primeira Instalação

```bash
# 1. Instalar dependências básicas
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git

# 2. Clonar scripts de instalação
git clone https://github.com/ai9tec/crm-setup
cd crm-setup

# 3. Dar permissões e executar
sudo chmod +x instalador_single.sh atualizador_remoto.sh instalador_apioficial.sh
sudo ./instalador_single.sh
```

### Reexecutar Instalação

```bash
cd /root/crm-setup
git reset --hard
git pull
sudo chmod +x instalador_single.sh
sudo ./instalador_single.sh
```

## ✨ Novidades v2.0

### 🎯 Repositório Padrão

Agora você pode usar o repositório **ai9tec/crm** (público) com apenas um clique!

Quando perguntado:
```
>> Usar repositório padrão (https://github.com/ai9tec/crm.git)? (S/N):
```
- Digite **S** → Usa repositório ai9tec/crm (não precisa token)
- Digite **N** → Informa outro repositório manualmente

### 🔓 Suporte a Repositórios Públicos

Não precisa mais de token para repositórios públicos:
- **Repositório público** → Token opcional (deixe vazio)
- **Repositório privado** → Token obrigatório

### 🔐 Segurança Melhorada

Token GitHub nunca é exibido completo na tela:
- Mostra apenas: `ghp_****************`
- Ou: `(não fornecido - repositório público)`

## 📦 Componentes Instalados

O script instala automaticamente:

✅ **Backend** - Node.js + TypeScript + Sequelize + PostgreSQL  
✅ **Frontend** - React + Material-UI + Build otimizado  
✅ **API Oficial** - NestJS + Prisma (WhatsApp Business)  
✅ **Nginx** - Proxy reverso + SSL/TLS  
✅ **PostgreSQL** - Bancos de dados  
✅ **Redis** - Cache e filas  
✅ **PM2** - Gerenciador de processos  
✅ **Certbot** - Certificados SSL automáticos  

## 📋 Pré-requisitos

### Servidor
- Ubuntu 22.04 ou 24.04 LTS
- 4GB RAM mínimo (recomendado: 8GB)
- 2 vCPUs mínimo
- 40GB espaço em disco
- Acesso root ou sudo

### DNS
- Domínio/subdomínio apontando para o IP do servidor
- Exemplo:
  - `api.seudominio.com.br` → Backend
  - `app.seudominio.com.br` → Frontend

### GitHub (Opcional)
- Token pessoal apenas para repositórios privados
- Criar em: https://github.com/settings/tokens
- Permissões necessárias: `repo` (acesso completo)

## 🛠️ Scripts Disponíveis

### instalador_single.sh
Instalação completa do zero:
- Configura sistema operacional
- Instala todas as dependências
- Clona código do repositório
- Configura bancos de dados
- Compila backend e frontend
- Configura Nginx e SSL
- Inicia serviços com PM2

```bash
sudo ./instalador_single.sh
```

### atualizador_remoto.sh
Atualiza sistema já instalado:
- Faz backup do banco de dados
- Atualiza código (git pull)
- Reinstala dependências npm
- Recompila backend e frontend
- Executa migrations
- Reinicia serviços

```bash
sudo ./atualizador_remoto.sh
```

### instalador_apioficial.sh
Instala/atualiza apenas API Oficial:
- Cria banco separado
- Instala dependências
- Configura Prisma
- Configura Nginx para API
- Emite certificado SSL

```bash
sudo ./instalador_apioficial.sh
```

## 📝 Durante a Instalação

O instalador solicitará:

### 1. Repositório
```
>> Usar repositório padrão (ai9tec/crm)? (S/N):
```
- **S** = Usa https://github.com/ai9tec/crm.git
- **N** = Permite informar outro repositório

### 2. URLs dos Subdomínios
```
>> Insira a URL do Backend:
> https://api.seudominio.com.br

>> Insira a URL do Frontend:
> https://app.seudominio.com.br
```

### 3. Informações da Empresa
```
>> Digite o seu melhor email:
> seu@email.com

>> Digite o nome da sua empresa (minúsculas, sem espaço):
> minhaempresa

>> Insira a senha para Deploy/Redis/Banco (sem caracteres especiais):
> SuaSenhaSegura123

>> Insira a senha para o MASTER:
> SenhaMaster123
```

### 4. Configurações da Aplicação
```
>> Insira o Título da Aplicação:
> Meu CRM

>> Digite o número de telefone para suporte:
> 5511999999999
```

### 5. Integrações (Opcional)
```
>> Digite o FACEBOOK_APP_ID caso tenha:
> (deixe vazio se não tiver)

>> Digite o FACEBOOK_APP_SECRET caso tenha:
> (deixe vazio se não tiver)
```

### 6. Proxy e Portas
```
>> Instalar usando Nginx ou Traefik?
> nginx (recomendado)

>> Usar portas padrão (8080/3000)? (S/N):
> S (recomendado)
```

## ⚙️ Após a Instalação

### Acessar o Sistema
- **Frontend:** https://app.seudominio.com.br
- **Usuário padrão:** admin@multi100.com.br
- **Senha padrão:** adminpro

⚠️ **IMPORTANTE:** Altere as credenciais padrão após primeiro acesso!

### Gerenciar Serviços

```bash
# Ver status
pm2 status

# Ver logs
pm2 logs
pm2 logs backend
pm2 logs frontend

# Reiniciar
pm2 restart all
pm2 restart backend
pm2 restart frontend
```

### Backup Manual

```bash
# Backend
PGPASSWORD=sua_senha pg_dump -U empresa -h localhost empresa > backup.sql

# API Oficial
PGPASSWORD=sua_senha pg_dump -U empresa -h localhost oficialseparado > backup_api.sql
```

## 🔧 Troubleshooting

### Erro ao clonar repositório
```
>> ERRO: Falha ao clonar repositório!
```
**Solução:**
- Verificar URL correta
- Para repos privados: verificar token válido
- Testar conexão: `ping github.com`

### DNS não resolve
```
>> ATENÇÃO: Subdomínio não aponta para o IP atual
```
**Solução:**
- Aguardar propagação DNS (até 48h)
- Pode continuar instalação ignorando aviso
- Configurar DNS antes de emitir SSL

### Erro de build
```
>> Erro ao compilar backend/frontend
```
**Solução:**
```bash
cd /home/deploy/empresa/backend
rm -rf node_modules package-lock.json
npm install
npm run build
```

### PM2 não inicia
```bash
# Verificar logs
pm2 logs

# Limpar processos
pm2 delete all
pm2 save --force

# Reexecutar instalador
sudo ./instalador_single.sh
```

## 📚 Documentação Adicional

- **[CHANGELOG.md](CHANGELOG.md)** - Histórico de mudanças
- **[Repositório CRM](https://github.com/ai9tec/crm)** - Código-fonte
- **[README do CRM](https://github.com/ai9tec/crm/blob/main/README.md)** - Documentação completa

## 🔒 Segurança

### Token GitHub
- Nunca compartilhe seu token
- Use tokens com escopo mínimo necessário
- Revogue tokens não utilizados

### Senhas
- Use senhas fortes (mínimo 12 caracteres)
- Não use caracteres especiais em senha_deploy
- Altere credenciais padrão após instalação

### SSL/TLS
- Certificados são renovados automaticamente
- Certbot configurado com cron job
- Validade: 90 dias (renovação automática aos 60)

## 🤝 Suporte

### Issues
https://github.com/ai9tec/crm/issues

### Repositórios
- **Scripts:** https://github.com/ai9tec/crm-setup
- **Código:** https://github.com/ai9tec/crm

## 📄 Licença

Proprietário - Todos os direitos reservados

---

**Versão:** 2.0.0  
**Última atualização:** 31/01/2026  
**Compatibilidade:** Ubuntu 22.04, 24.04 LTS
