# Runbook DR — Failover e Failback (Oracle)

Documento operacional para a VPS de contenção (Oracle).  
Execute com calma; marque cada checkbox. **Um único primário de escrita por slug** — nunca App/Magistral/Beauty prod + Oracle escrevendo o mesmo tenant ao mesmo tempo.

## Mapa rápido


| Slug Oracle | Produção (origem)   | IP prod           | Pasta Oracle             | DB CRM      | DB oficial                  | Portas B/F/O   | Redis | PM2           |
| ----------- | ------------------- | ----------------- | ------------------------ | ----------- | --------------------------- | -------------- | ----- | ------------- |
| `app`       | `/home/deploy/chat` | `193.203.182.172` | `/home/deploy/app`       | `app`       | `oficialseparado_app`       | 8081/3001/6001 | `/1`  | `app-*`       |
| `magistral` | `/home/deploy/ai9`  | `72.62.14.177`    | `/home/deploy/magistral` | `magistral` | `oficialseparado_magistral` | 8082/3002/6002 | `/2`  | `magistral-*` |
| `beauty`    | `/home/deploy/ai9`  | `72.61.39.125`    | `/home/deploy/beauty`    | `beauty`    | `oficialseparado_beauty`    | 8083/3003/6003 | `/3`  | `beauty-*`    |



| Slug        | DNS produção (Cloudflare)                       | Subscriptions na Oracle                      |
| ----------- | ----------------------------------------------- | -------------------------------------------- |
| `app`       | `app` / `api` / `apiof` (+ `appsec` se houver)  | `sub_app_chat`, `sub_app_oficial`            |
| `magistral` | `magistral` / `apimagistral` / `apiofmagistral` | `sub_magistral_ai9`, `sub_magistral_oficial` |
| `beauty`    | `crm` / `apicrm` / `apiofcrm`                   | `sub_beauty_ai9`, `sub_beauty_oficial`       |


DEV permanente na Oracle: pasta `ai9`, portas 8080/3000/6000, DNS `*2` — **não misturar** com promote.

Transcrição: standbys usam `http://127.0.0.1:4002` (`ai9-api_transcricao`).

---



## Estado normal (sem crash)

- Produção: apps + Postgres primário + publication.
- Oracle: réplica lógica (subscriptions ativas) + rsync cron das pastas + PM2 dos standbys **stopped**.
- DNS de produção → IPs das VPS de produção.

Não execute as seções de promote/failback “por teste” sem janela planejada e sem avisar o time.

---



# Parte A — Crash (failover para a Oracle)

**Objetivo:** o slug X passa a atender na Oracle, com DNS de produção apontando para `163.176.26.255` (IP público da Oracle).

Substitua `SLUG` por `app` | `magistral` | `beauty`.

### A0 — Decisão e anti split-brain

- [ ] Confirmar que a VPS de produção do slug está inacessível ou será isolada.
- [ ] **Não** tentar “consertar e escrever” na prod e na Oracle ao mesmo tempo.
- [ ] Se a prod ainda responde parcialmente: parar PM2 / firewall / DNS o mais rápido possível **depois** de subir a Oracle (ou antes, se ainda tiver acesso).



### A1 — Congelar sync de pasta (produção → Oracle)

Na **produção** (se ainda houver SSH):

```bash
sudo mv /etc/cron.d/crm-sync-standby /etc/cron.d/crm-sync-standby.disabled 2>/dev/null || true
sudo -u deploy killall -q rsync || true
```

Se não houver SSH na prod: ignore; o rsync falhará sozinho. O importante é **não** deixar um sync antigo sobrescrever `.env` “errado” depois do overlay de promote (reaplique overlay na A3 se necessário).

### A2 — Parar a subscription (Oracle vira primário de escrita)

Na **Oracle**, como root/ubuntu:

```bash
# SLUG=magistral  →  sub_magistral_ai9 + sub_magistral_oficial
# SLUG=app        →  sub_app_chat + sub_app_oficial
# SLUG=beauty     →  sub_beauty_ai9 + sub_beauty_oficial

sudo -u postgres psql -d magistral <<'SQL'
-- Exemplo Magistral CRM; repetir no DB oficial com o outro nome de subscription
ALTER SUBSCRIPTION sub_magistral_ai9 DISABLE;
ALTER SUBSCRIPTION sub_magistral_ai9 SET (slot_name = NONE);
DROP SUBSCRIPTION sub_magistral_ai9;
SQL

sudo -u postgres psql -d oficialseparado_magistral <<'SQL'
ALTER SUBSCRIPTION sub_magistral_oficial DISABLE;
ALTER SUBSCRIPTION sub_magistral_oficial SET (slot_name = NONE);
DROP SUBSCRIPTION sub_magistral_oficial;
SQL
```

Adapte nomes/DBs conforme a tabela do mapa.  
`SET (slot_name = NONE)` evita a Oracle tentar limpar o slot numa prod **morta**.

Conferir:

```bash
sudo -u postgres psql -c "SELECT subname FROM pg_subscription ORDER BY 1;"
```

O slug promovido **não** deve mais aparecer.

### A3 — Overlay + sequences (Oracle)

```bash
sudo -u deploy bash /home/deploy/crm-setup/tools/apply_standby_overlay.sh SLUG
# Confirme TRANSCRIBE_URL=http://127.0.0.1:4002 no backend/.env do slug
```

Ajustar sequences (evita conflito de PK após réplica lógica):

```bash
# Exemplo no DB do slug (magistral / app / beauty)
sudo -u postgres psql -d magistral <<'SQL'
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname, c.relname, a.attname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
    WHERE n.nspname = 'public'
      AND pg_get_expr(d.adbin, d.adrelid) LIKE 'nextval%'
  LOOP
    EXECUTE format(
      'SELECT setval(pg_get_serial_sequence(%L, %L), COALESCE((SELECT MAX(%I) FROM %I.%I), 1))',
      r.nspname || '.' || r.relname, r.attname, r.attname, r.nspname, r.relname
    );
  END LOOP;
END $$;
SQL
```

Repita no DB `oficialseparado_*` do slug se houver serials.

### A4 — Nginx + TLS na Oracle

- [ ] Server blocks com os **hostnames de produção** do slug apontando para as portas do mapa (ex. Magistral → 8082/3002/6002).
- [ ] Certbot/TLS válido nesses hostnames **ou** certificado já preparado.
- [ ] `nginx -t && systemctl reload nginx`

DEV (`app2`/`api2`/`apiof2`) permanece intacto.

### A5 — Subir PM2 do slug

```bash
sudo -iu deploy
# Exemplo Magistral:
pm2 start /home/deploy/magistral/backend/dist/server.js --name magistral-backend
pm2 start /home/deploy/magistral/frontend/server.js --name magistral-frontend
pm2 start /home/deploy/magistral/api_oficial/dist/main.js --name magistral-api_oficial
pm2 save
pm2 list
```

Smoke local:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8082/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3002/
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:6002/
```



### A6 — DNS (Cloudflare)

- [ ] Registros A (e AAAA se houver) dos hostnames de **produção** do slug → `163.176.26.255`
- [ ] TTL baixo ajuda; aguardar propagação
- [ ] Testar HTTPS externo e login
- [ ] Validar WhatsApp/WABA / webhooks (URL pública deve bater com o DNS novo)



### A7 — Isolar a VPS que crashou (quando voltar sozinha)

Assim que a prod antiga responder de novo, **antes** de qualquer failback:

- [ ] Manter DNS na Oracle
- [ ] Na prod antiga: `pm2 stop all` (ou stop só do stack) e/ou bloquear 80/443 no firewall
- [ ] **Não** reativar o cron `crm-sync-standby` ainda
- [ ] Anotar horário do promote e do retorno da VPS

A Oracle continua como **único** escritor até o failback planejado.

---



# Parte B — Failback planejado (Oracle → produção restaurada)

**Quando:** VPS antiga estável, horário calmo, time disponível.  
**Objetivo:** produção volta a ser primário; Oracle volta a ser standby (subscription + PM2 cold).

Exemplo abaixo: **Magistral**. Adapte nomes para `app` / `beauty`.

### B0 — Preparação

- [ ] Comunicar janela (ex. 30–60 min)
- [ ] Backup lógico opcional na Oracle antes do cutover:
  ```bash
  sudo -u postgres pg_dump -Fc -d magistral -f /tmp/magistral_pre_failback.dump
  sudo -u postgres pg_dump -Fc -d oficialseparado_magistral -f /tmp/magistral_oficial_pre_failback.dump
  ```
- [ ] Confirmar que a VPS Magistral antiga **não** recebe tráfego de produção (DNS ainda na Oracle)



### B1 — Na VPS Magistral: preparar Postgres para receber dados da Oracle

1. `wal_level = logical`, `listen_addresses = '*'`, `pg_hba` liberando **só** `163.176.26.255` para o user de réplica (como no setup inicial).
2. Firewall Hostinger: TCP 5432 só da Oracle.
3. Role `repl_oracle` (ou equivalente) com `REPLICATION` + `SELECT`.
4. **Parar o app** na Magistral (`pm2 stop ...`) — ela ainda não é primário de escrita de produção.



### B2 — Publicação na Oracle (fonte atual)

Na Oracle, nos DBs que estão como primário:

```bash
sudo -u postgres psql -d magistral <<'SQL'
DROP PUBLICATION IF EXISTS pub_failback_magistral_ai9;
CREATE PUBLICATION pub_failback_magistral_ai9 FOR ALL TABLES;
SQL

sudo -u postgres psql -d oficialseparado_magistral <<'SQL'
DROP PUBLICATION IF EXISTS pub_failback_magistral_oficial;
CREATE PUBLICATION pub_failback_magistral_oficial FOR ALL TABLES;
SQL
```

Garantir `REPLICA IDENTITY FULL` nas tabelas sem PK (`ContactTags`, `Settings`, `TicketTags`) se ainda não houver PK.

### B3 — Schema limpo + subscription na VPS Magistral

Na Magistral (destino do failback):

1. Dump schema **da Oracle** (CRM + oficial), com `--no-publications`.
2. `DROP SCHEMA public CASCADE` + recreate nos DBs locais (`ai9`, `oficialseparado`).
3. Aplicar schema.
4. `CREATE SUBSCRIPTION` apontando para a Oracle (`163.176.26.255`), publications `pub_failback_*`.
5. Esperar `srsubstate = r` em todas as tabelas e `COUNT` crítico igual (ex. `"Tickets"`).

Na Oracle, abrir `pg_hba` + firewall **só** para o IP público da Magistral (`72.62.14.177`) durante essa fase (user de réplica).

### B4 — Cutover (janela curta)

Ordem sugerida:

1. **Manutenção / freeze** breve (opcional): avisar usuários.
2. Na Oracle: `pm2 stop magistral-backend magistral-frontend magistral-api_oficial`
3. Na Oracle: aguardar subscriptions na Magistral pegarem o último LSN (segundos/minutos).
4. Na Magistral: dropar subscriptions (com `slot_name = NONE` se necessário), ajustar sequences (mesmo bloco da A3).
5. Na Magistral: conferir `.env` de **produção** (URLs/DNS/portas 8080/3000/6000), `pm2 start` do stack.
6. **DNS** Cloudflare: A records de volta para `72.62.14.177`.
7. Validar HTTPS, login, WABA.



### B5 — Oracle volta ao papel de standby

1. Remover publications `pub_failback_*` na Oracle (opcional/limpo).
2. Recriar schema/subscription **Oracle ← Magistral** como no setup original (`pub_magistral_`* / `sub_magistral_*`), **ou** dropar DBs standby e refazer o fluxo de schema+subscription a partir da prod.
3. `apply_standby_overlay.sh magistral`
4. `pm2 stop` dos `magistral-*` + `pm2 save`
5. Reativar cron rsync **na produção** Magistral:
  ```bash
   sudo mv /etc/cron.d/crm-sync-standby.disabled /etc/cron.d/crm-sync-standby
  ```
6. Fechar regras de firewall extras que só serviam ao failback.



### B6 — Pós-checagem

- [ ] `pm2 list` Oracle: só DEV (+ outros standbys cold) online; slug failback stopped
- [ ] `pg_stat_subscription` na Oracle: `sub_magistral_*` com `pid` e LSN andando
- [ ] DNS e app estáveis por algumas horas
- [ ] Registrar no histórico: horário crash, promote, failback

---



## Checagens úteis (Oracle)

```bash
# Subscriptions
sudo -u postgres psql -c "SELECT subname, pid, last_msg_receipt_time FROM pg_stat_subscription ORDER BY 1;"

# Tamanhos
sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datname ~ 'app|magistral|beauty|oficial' ORDER BY 1;"

# PM2
sudo -iu deploy pm2 list
```



## Armadilhas


| Problema                           | Evitar                                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------ |
| Split-brain                        | Um DNS + um PM2 escrevendo por slug                                            |
| `DROP SUBSCRIPTION` com prod morta | Sempre `DISABLE` + `SET (slot_name = NONE)` antes                              |
| rsync após promote                 | Desligar cron na prod; reaplicar overlay se necessário                         |
| Sequences                          | Rodar `setval` no promote e no failback                                        |
| Workers Oracle                     | `max_logical_replication_workers` / `max_worker_processes` já elevados (16/24) |
| WABA/webhooks                      | Conferir URL pública após DNS                                                  |
| DEV `ai9`                          | Não reutilizar portas/DBs do DEV no promote                                    |




## Histórico de incidentes (preencher)


| Data | Slug | Início crash | Promote OK | Failback OK | Notas |
| ---- | ---- | ------------ | ---------- | ----------- | ----- |
|      |      |              |            |             |       |


