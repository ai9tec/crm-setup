# Scripts de Instalação - CRM

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

## ✨ Novidades v3.0

### 🔐 Deploy Keys SSH (Maior Segurança)

Substituição de Personal Access Tokens por **Deploy Keys SSH específicas** de repositório:

**Vantagens:**
- ✅ Deploy Key tem acesso **apenas ao repositório específico**
- ✅ Não expõe credenciais em variáveis de ambiente
- ✅ Cada servidor tem sua própria chave SSH única
- ✅ Fácil revogação sem afetar outros repositórios
- ✅ GitHub registra qual Deploy Key foi usada (auditoria)

### 🔓 Suporte a Repositórios Públicos e Privados

**Repositórios Públicos (HTTPS):**
- Autenticação via HTTPS
- Não requer configuração adicional
- Ideal para projetos open source

**Repositórios Privados (SSH):**
- Deploy Keys geradas automaticamente
- Chave RSA 4096 bits
- Instruções interativas para adicionar no GitHub
- Maior segurança e controle de acesso

### 🎯 Script Totalmente Independente

O instalador não está vinculado a nenhum repositório específico, permitindo:
- ✅ Usar qualquer repositório GitHub (público ou privado)
- ✅ Flexibilidade total para diferentes projetos
- ✅ Reutilização do script em diversos cenários

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

### GitHub
- **Repositórios Públicos:** Não requer autenticação
- **Repositórios Privados:** Deploy Key SSH (gerada automaticamente pelo script)
- Deploy Keys devem ser adicionadas em: Settings > Deploy keys > Add deploy key

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

### 1. Tipo de Autenticação do Repositório
```
>> Escolha o tipo de autenticação do repositório:
>> 1 - Repositório Público (HTTPS sem autenticação)
>> 2 - Repositório Privado (SSH com Deploy Key)
```

**Opção 1 - Repositório Público:**
```
>> Digite a URL HTTPS do repositório no GitHub:
> https://github.com/usuario/repositorio.git
```

**Opção 2 - Repositório Privado:**
```
>> Digite a URL SSH do repositório no GitHub:
> git@github.com:usuario/repositorio.git

>> Configuração da Deploy Key SSH
[Script gera chave SSH RSA 4096 bits]
[Exibe chave pública para copiar]
>> Adicione a chave como Deploy Key no GitHub:
   Settings > Deploy keys > Add deploy key
```

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

## 🔒 Segurança

### Deploy Keys SSH
- Cada servidor deve ter sua própria chave SSH única
- Nunca compartilhe chaves privadas SSH
- Deploy Keys podem ser revogadas a qualquer momento no GitHub
- Chave privada tem permissões 600 (somente proprietário lê/escreve)
- Para revogar: GitHub > Settings > Deploy keys > Delete

### Senhas
- Use senhas fortes (mínimo 12 caracteres)
- Não use caracteres especiais em senha_deploy
- Altere credenciais padrão após instalação

### SSL/TLS
- Certificados são renovados automaticamente
- Certbot configurado com cron job
- Validade: 90 dias (renovação automática aos 60)

## 💡 Exemplos de Uso

### Exemplo 1: Instalação com Repositório Público

```bash
sudo ./instalador_single.sh

# Quando solicitado:
>> Escolha o tipo de autenticação: 1
>> Digite a URL HTTPS: https://github.com/ai9tec/crm.git

# Continue com as demais configurações...
```

### Exemplo 2: Instalação com Repositório Privado

```bash
sudo ./instalador_single.sh

# Quando solicitado:
>> Escolha o tipo de autenticação: 2
>> Digite a URL SSH: git@github.com:meuusuario/meu-crm-privado.git

# Script gera a chave SSH e exibe:
[Chave pública SSH aparece na tela]

# Passos:
1. Copiar a chave pública exibida
2. Ir até GitHub > Repositório > Settings > Deploy keys
3. Clicar em "Add deploy key"
4. Colar a chave e dar um nome (ex: "Servidor Produção")
5. Marcar "Allow write access" se necessário
6. Pressionar Enter no terminal para continuar

# Continue com as demais configurações...
```

### Exemplo 3: Migração de Instalação Existente

Se você já tem uma instalação usando token e quer migrar para Deploy Key:

```bash
# 1. Gerar Deploy Key
sudo su - deploy
ssh-keygen -t rsa -b 4096 -C "deploy@servidor" -f ~/.ssh/id_rsa -N ""
cat ~/.ssh/id_rsa.pub

# 2. Adicionar chave no GitHub (copiar output acima)

# 3. Reconfigurar remote do Git
cd /home/deploy/empresa/
git remote set-url origin git@github.com:usuario/repositorio.git

# 4. Testar
git fetch origin
```

## 🤝 Suporte

### Issues
https://github.com/ai9tec/crm/issues

### Repositórios
- **Scripts:** https://github.com/ai9tec/crm-setup
- **Código:** https://github.com/ai9tec/crm

## 📄 Licença

Proprietário - Todos os direitos reservados

---

**Versão:** 3.0.0  
**Última atualização:** 31/01/2026  
**Compatibilidade:** Ubuntu 22.04, 24.04 LTS  
**Principais mudanças v3.0:** Deploy Keys SSH substituem tokens, script totalmente independente de repositórios específicos
