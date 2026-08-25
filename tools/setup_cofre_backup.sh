#!/usr/bin/env bash
# Configura o cofre de backups offsite na VPS de contenção.
# Uso (como root): sudo ./tools/setup_cofre_backup.sh
set -euo pipefail

OFFSITE_ROOT="/home/deploy/backups/offsite"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
AUTHORIZED_KEYS_FILE="/home/deploy/.ssh/authorized_keys"
BACKUP_PUBKEY_FILE="/home/deploy/.ssh/backup_offsite.pub"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Execute como root: sudo $0"
  exit 1
fi

if ! id deploy &>/dev/null; then
  echo "Usuário deploy não existe. Rode o instalador do CRM antes."
  exit 1
fi

install -d -o deploy -g deploy -m 755 /home/deploy/backups
install -d -o deploy -g deploy -m 750 "${OFFSITE_ROOT}"
install -d -o deploy -g deploy -m 700 /home/deploy/.ssh

if [[ ! -f "${AUTHORIZED_KEYS_FILE}" ]]; then
  install -o deploy -g deploy -m 600 /dev/null "${AUTHORIZED_KEYS_FILE}"
fi

cat >/usr/local/bin/crm-backup-retain <<EOF
#!/usr/bin/env bash
# Remove pastas de backup offsite com mais de ${RETENTION_DAYS} dias.
set -euo pipefail
ROOT="${OFFSITE_ROOT}"
DAYS=${RETENTION_DAYS}
[[ -d "\$ROOT" ]] || exit 0
find "\$ROOT" -mindepth 2 -maxdepth 2 -type d -mtime +"\$DAYS" -print -exec rm -rf {} +
# limpa symlinks latest quebrados
find "\$ROOT" -mindepth 2 -maxdepth 2 -type l ! -exec test -e {} \\; -delete 2>/dev/null || true
EOF
chmod 755 /usr/local/bin/crm-backup-retain

CRON_LINE="15 4 * * * root /usr/local/bin/crm-backup-retain >>/var/log/crm-backup-retain.log 2>&1"
if ! grep -qF "crm-backup-retain" /etc/crontab 2>/dev/null; then
  echo "${CRON_LINE}" >>/etc/crontab
  echo "Cron de retenção (${RETENTION_DAYS} dias) adicionado em /etc/crontab"
fi

echo
echo "=== Cofre pronto ==="
echo "Diretório: ${OFFSITE_ROOT}"
echo "Retenção:  ${RETENTION_DAYS} dias (cron 04:15)"
echo
echo "Próximo passo — chave SSH das produções:"
echo "1) Em CADA VPS de produção, gere a chave (se ainda não tiver):"
echo "   sudo -u deploy ssh-keygen -t ed25519 -f /home/deploy/.ssh/id_ed25519_offsite -N '' -C 'backup-offsite'"
echo "2) Copie a chave PÚBLICA para esta contenção:"
echo "   sudo -u deploy cat /home/deploy/.ssh/id_ed25519_offsite.pub"
echo "3) Nesta contenção, acrescente a pública em ${AUTHORIZED_KEYS_FILE}:"
echo "   echo 'CHAVE_PUBLICA' | tee -a ${AUTHORIZED_KEYS_FILE}"
echo "   chown deploy:deploy ${AUTHORIZED_KEYS_FILE} && chmod 600 ${AUTHORIZED_KEYS_FILE}"
echo "4) Abra SSH (22) na Security List da Oracle para os IPs das 3 produções (ou 0.0.0.0/0 se aceitável)."
echo "5) Na produção, configure tools/backup_offsite.conf e o cron (ver README)."
echo
if [[ -f "${BACKUP_PUBKEY_FILE}" ]]; then
  echo "Chave pública já presente em ${BACKUP_PUBKEY_FILE}"
fi
