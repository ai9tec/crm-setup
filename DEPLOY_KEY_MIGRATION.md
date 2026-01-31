# Migração de Personal Access Token para Deploy Keys

## Resumo das Mudanças

Este documento descreve as alterações realizadas no `instalador_single.sh` para substituir o uso de Personal Access Token (PAT) do GitHub por Deploy Keys SSH, aumentando a segurança do processo de instalação.

## Motivação

- **Personal Access Token (PAT)**: Dá acesso a **todos os repositórios** do usuário, o que representa um risco de segurança
- **Deploy Keys**: São específicas de **um único repositório**, limitando o escopo de acesso

## Alterações Realizadas

### 1. Variáveis de Configuração

**Removido:**
- `github_token` - Token de acesso pessoal

**Adicionado:**
- `repo_auth_type` - Define o tipo de autenticação:
  - `public`: Repositório público via HTTPS (sem autenticação)
  - `ssh`: Repositório privado via SSH (com Deploy Key)

### 2. Fluxo de Configuração (`questoes_variaveis_base`)

#### Antes:
```bash
# Solicitava um Personal Access Token
read -p "> " github_token
```

#### Depois:
```bash
# Solicita o tipo de autenticação
1 - Repositório Público (HTTPS sem autenticação)
2 - Repositório Privado (SSH com Deploy Key)
```

#### Novo Processo para Deploy Keys:

Quando o usuário seleciona opção "2 - SSH com Deploy Key":

1. **Gera chave SSH** automaticamente para o usuário `deploy`:
   ```bash
   ssh-keygen -t rsa -b 4096 -C "deploy@multiflow" -f ~/.ssh/id_rsa -N ""
   ```

2. **Exibe a chave pública** na tela para o usuário copiar

3. **Fornece instruções** de como adicionar no GitHub:
   - Settings > Deploy keys > Add deploy key
   - Colar a chave pública
   - Marcar "Allow write access" se necessário

4. **Aguarda confirmação** do usuário após adicionar a chave no GitHub

5. **Configura o SSH** para aceitar a chave do GitHub:
   ```bash
   ssh-keyscan -H github.com >> ~/.ssh/known_hosts
   ```

### 3. Função de Clone (`baixa_codigo_base`)

#### Antes:
```bash
# Usava token na URL HTTPS
github_url="https://${github_token_encoded}@${repo_clean}"
git clone ${github_url} ${dest_dir}
```

#### Depois:
```bash
# SSH com Deploy Key
if [ "${repo_auth_type}" == "ssh" ]; then
  GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no" \
    git clone ${repo_url} ${dest_dir}
  
# HTTPS público
else
  git clone ${repo_url} ${dest_dir}
fi
```

### 4. Exibição de Dados (`dados_instalacao_base`)

#### Antes:
```bash
Token GitHub: ---------->> ghp_****...
```

#### Depois:
```bash
Tipo de Autenticação: -->> SSH (Deploy Key)
# ou
Tipo de Autenticação: -->> HTTPS Público (sem autenticação)
```

## Benefícios de Segurança

1. **Escopo Limitado**: Deploy Key só tem acesso ao repositório específico
2. **Sem Credenciais em Variáveis**: Não há tokens armazenados em arquivos de configuração
3. **Chaves por Servidor**: Cada servidor tem sua própria chave SSH única
4. **Revogação Fácil**: Deploy Keys podem ser removidas sem afetar outros repositórios
5. **Auditoria**: GitHub registra qual Deploy Key foi usada em cada acesso

## Compatibilidade

### Repositórios Públicos
- Continuam funcionando via HTTPS sem autenticação
- Não requer configuração adicional

### Repositórios Privados
- Agora usam SSH com Deploy Key
- URL deve estar no formato: `git@github.com:usuario/repo.git`

### Atualizações
- A função de atualização (`baixa_codigo_atualizar`) **não precisa de mudanças**
- O Git automaticamente usa o método de autenticação configurado no clone original

## Formato de URLs

### HTTPS (Público):
```
https://github.com/usuario/repositorio.git
```

### SSH (Deploy Key):
```
git@github.com:usuario/repositorio.git
```

## Instruções para Adicionar Deploy Key no GitHub

1. Acesse o repositório no GitHub
2. Vá em **Settings** (Configurações)
3. No menu lateral, clique em **Deploy keys**
4. Clique em **Add deploy key**
5. Preencha:
   - **Title**: Nome descritivo (ex: "Servidor Produção MultiFlow")
   - **Key**: Cole a chave pública SSH exibida pelo instalador
   - **Allow write access**: Marque se precisar fazer push (opcional)
6. Clique em **Add key**

## Arquivos Modificados

- `instalador_single.sh`:
  - Função `salvar_variaveis()` - linha 55-65
  - Função `questoes_variaveis_base()` - linha 600-700
  - Função `dados_instalacao_base()` - linha 800-830
  - Função `baixa_codigo_base()` - linha 1370-1470

## Testes Recomendados

Antes de usar em produção, testar:

1. ✅ Instalação com repositório público (opção 1)
2. ✅ Instalação com repositório privado via SSH (opção 2)
3. ✅ Atualização após instalação via SSH
4. ✅ Verificar permissões da chave SSH (600 para privada, 644 para pública)
5. ✅ Validar que git fetch/pull funcionam após instalação

## Migração de Instalações Existentes

Para instalações já existentes que usam Personal Access Token:

1. Gerar Deploy Key no servidor:
   ```bash
   sudo su - deploy
   ssh-keygen -t rsa -b 4096 -C "deploy@multiflow" -f ~/.ssh/id_rsa -N ""
   cat ~/.ssh/id_rsa.pub
   ```

2. Adicionar a chave pública como Deploy Key no GitHub

3. Reconfigurar o remote do Git:
   ```bash
   cd /home/deploy/{empresa}/
   git remote set-url origin git@github.com:usuario/repo.git
   ```

4. Testar:
   ```bash
   git fetch origin
   ```

## Suporte

Para dúvidas ou problemas:
- Verificar se a Deploy Key foi adicionada corretamente no GitHub
- Confirmar permissões corretas nos arquivos SSH (600 para privada)
- Validar formato da URL SSH: `git@github.com:usuario/repo.git`
- Checar se o servidor tem acesso de rede ao GitHub (porta 22)
