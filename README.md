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
sudo chmod +x instalador_single.sh atualizador_remoto.sh atualizador_remoto_FAST.sh instalador_apioficial.sh
sudo ./instalador_single.sh
```

### Reexecutar Instalação (do zero)

```bash
cd /root/crm-setup
git reset --hard
git pull
sudo chmod +x instalador_single.sh
sudo ./instalador_single.sh
```

> **Atualizar código (backend/frontend) sem reinstalar:** veja a seção [Atualização da Instalação](#-atualização-da-instalação).

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

### 2. Branch do Repositório
```
>> Digite o nome da branch a ser usada:
>> (ex: main, master, develop)

> main
```
A branch informada será usada no clone e em todas as atualizações. Se deixar em branco, será usada a branch **main**.

### 3. URLs dos Subdomínios
```
>> Insira a URL do Backend:
> https://api.seudominio.com.br

>> Insira a URL do Frontend:
> https://app.seudominio.com.br
```

### 4. Informações da Empresa
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

### 5. Configurações da Aplicação
```
>> Insira o Título da Aplicação:
> Meu CRM

>> Digite o número de telefone para suporte:
> 5511999999999
```

### 6. Integrações (Opcional)
```
>> Digite o FACEBOOK_APP_ID caso tenha:
> (deixe vazio se não tiver)

>> Digite o FACEBOOK_APP_SECRET caso tenha:
> (deixe vazio se não tiver)
```

### 7. Proxy e Portas
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

## 💡 Exemplos de Uso

### Exemplo 1: Instalação com Repositório Público

```bash
sudo ./instalador_single.sh

# Quando solicitado:
>> Escolha o tipo de autenticação: 1
>> Digite a URL HTTPS: https://github.com/ai9tec/crm.git
>> Digite a branch: main

# Continue com as demais configurações...
```

### Exemplo 2: Instalação com Repositório Privado

```bash
sudo ./instalador_single.sh

# Quando solicitado:
>> Escolha o tipo de autenticação: 2
>> Digite a URL SSH: git@github.com:meuusuario/meu-crm-privado.git
>> Digite a branch: main

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

## 🔄 Atualização da Instalação

Use a atualização quando houver **mudanças no código** do frontend ou do backend (novas versões, correções ou funcionalidades publicadas no repositório). A atualização não altera configurações de DNS, Nginx ou SSL; apenas atualiza o código, dependências e banco de dados.

### Quando fazer atualização

- Saiu nova versão do CRM no repositório
- Foram publicadas correções ou melhorias no backend ou frontend
- Você fez alterações no repositório e quer aplicar no servidor

### O que a atualização faz

1. **Backup** (opcional) – Faz backup do banco de dados PostgreSQL antes de alterar nada
2. **Código** – Atualiza o código na **mesma branch** escolhida na instalação (`git fetch` + `git reset --hard origin/<branch>`), usando o valor salvo em `VARIAVEIS_INSTALACAO` (`repo_branch`)
3. **Backend** – Reinstala dependências npm, recompila (build) e executa migrations
4. **Frontend** – Reinstala dependências npm e gera novo build
5. **Serviços** – Reinicia os processos no PM2 (backend e frontend)

Configurações de ambiente (`.env`), Nginx, SSL e usuários **não são alteradas**.

### Opção 1: Pelo menu do instalador

Se os scripts estão em `/root/crm-setup` (ou no diretório onde você rodou a primeira instalação):

```bash
cd /root/crm-setup
sudo ./instalador_single.sh
```

No menu, escolha:

```
>> [2] Atualizar nome_do_titulo
```

O script vai pedir se deseja fazer backup do banco, em seguida atualizar backend, frontend e reiniciar o PM2.

### Opção 2: Script de atualização direta

Para rodar só a atualização, sem abrir o menu:

```bash
cd /root/crm-setup
git pull
sudo chmod +x atualizador_remoto.sh
sudo ./atualizador_remoto.sh
```

O `atualizador_remoto.sh` usa o arquivo `VARIAVEIS_INSTALACAO` (gerado na primeira instalação) para saber empresa, diretórios, branch e portas. Execute-o **no mesmo diretório** onde está o instalador e onde foi feita a instalação. Opcionalmente, pode-se informar a branch na linha de comando: `sudo ./atualizador_remoto.sh nome_da_branch`; se não for informada, será usada a branch definida no `VARIAVEIS_INSTALACAO` (`repo_branch`).

### Opção 3: Atualização rápida (atualizador_remoto_FAST.sh)

Para atualizar **mais rápido** quando **não houve mudança em dependências** (`package.json`): só puxa o código, faz build e reinicia. Não reinstala `node_modules` nem faz backup do banco.

```bash
cd /root/crm-setup
sudo chmod +x atualizador_remoto_FAST.sh
sudo ./atualizador_remoto_FAST.sh
```

**Use o FAST quando:** apenas o código do backend/frontend mudou (correções, textos, configs).  
**Use o atualizador_remoto.sh quando:** houve alteração em `package.json`, nova versão do Node ou quiser backup do banco antes de atualizar.

O FAST também usa a **branch** definida na instalação (`repo_branch` em `VARIAVEIS_INSTALACAO`). Opcionalmente: `sudo ./atualizador_remoto_FAST.sh nome_da_branch` para atualizar em outra branch.

### Pré-requisitos para atualizar

- Instalação feita anteriormente com `instalador_single.sh`
- Arquivo `VARIAVEIS_INSTALACAO` presente no diretório dos scripts (ex.: `/root/crm-setup`)
- Acesso ao repositório (HTTPS ou SSH/Deploy Key) já configurado na primeira instalação
- Servidor com acesso à internet para `git fetch` e `npm install`

A **branch** usada na atualização é a que foi informada na instalação (salva como `repo_branch` em `VARIAVEIS_INSTALACAO`). Para mudar de branch, edite esse arquivo ou reinstale.

### Após a atualização

- Conferir se os serviços subiram: `pm2 status`
- Ver logs em caso de erro: `pm2 logs`
- Testar frontend e backend nas URLs configuradas (ex.: https://app.seudominio.com.br e https://api.seudominio.com.br)

Se algo falhar, o backup do banco (se tiver sido feito) estará em `/home/deploy/backups/`.

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
- Pergunta a **branch** do repositório (ex: main, master, develop)
- Clona código do repositório na branch informada
- Configura bancos de dados
- Compila backend e frontend
- Configura Nginx e SSL
- Inicia serviços com PM2

```bash
sudo ./instalador_single.sh
```

### atualizador_remoto.sh
Atualização completa do sistema já instalado:
- Faz backup do banco de dados
- Atualiza código na **branch definida na instalação** (git fetch + reset)
- Reinstala dependências npm (backend e frontend)
- Recompila backend e frontend
- Executa migrations
- Reinicia serviços

```bash
sudo ./atualizador_remoto.sh
# ou com branch específica:
sudo ./atualizador_remoto.sh nome_da_branch
```

### atualizador_remoto_FAST.sh
Atualização **rápida** (sem reinstalar dependências):
- Atualiza código na **branch definida na instalação** (git fetch + reset)
- Otimiza banco (vacuum, reindex)
- Apenas **build** do backend e frontend (não reinstala `node_modules`)
- Executa migrations
- Reinicia PM2 e Nginx

Use quando não houver mudança em `package.json`. Mais rápido; em caso de dúvida, use `atualizador_remoto.sh`.

```bash
sudo ./atualizador_remoto_FAST.sh
# ou com branch específica:
sudo ./atualizador_remoto_FAST.sh nome_da_branch
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

---

## 📄 Licença

Proprietário - Todos os direitos reservados

**Versão:** 3.0.0  
**Última atualização:** 31/01/2026  
**Compatibilidade:** Ubuntu 22.04, 24.04 LTS  
**Principais mudanças v3.0:** Deploy Keys SSH substituem tokens; script independente de repositório; escolha de branch na instalação; atualizadores (remoto, FAST, PRO e opção 2 do instalador) usam a branch salva em VARIAVEIS_INSTALACAO
