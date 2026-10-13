#!/bin/bash
# Garante Go (versão do go.mod ou fallback) em /usr/local/go.
# Uso: source lib/garantir_golang.sh && garantir_golang [GO_MOD_PATH]

GO_VERSION_FALLBACK="${GO_VERSION_FALLBACK:-1.26.4}"

garantir_golang() {
  local mod_file="${1:-}"
  local go_version="${GO_VERSION_FALLBACK}"

  if [ -n "${mod_file}" ] && [ -f "${mod_file}" ]; then
    local v
    v=$(awk '/^go [0-9]+\.[0-9]+/ {print $2; exit}' "${mod_file}")
    [ -n "$v" ] && go_version="$v"
  fi

  case "$go_version" in
    *.*.*) ;;
    *.*)   go_version="${go_version}.0" ;;
  esac

  export PATH="/usr/local/go/bin:${PATH}"

  if command -v go >/dev/null 2>&1; then
    local installed
    installed=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
    # Aceita a mesma major.minor (patch pode variar)
    local want_mm="${go_version%.*}"
    local have_mm="${installed%.*}"
    if [ "$have_mm" = "$want_mm" ] || [ "$(printf '%s\n%s\n' "$want_mm" "$have_mm" | sort -V | tail -n1)" = "$have_mm" ]; then
      # installed >= required major.minor
      if [ -n "$installed" ]; then
        echo ">> Go já instalado: go${installed} (pedido: ${go_version})"
        return 0
      fi
    fi
  fi

  echo ">> Instalando Go ${go_version}..."
  local arch="amd64"
  [ "$(uname -m)" = "aarch64" ] && arch="arm64"

  local tmp_tgz
  tmp_tgz="$(mktemp /tmp/go-XXXXXX.tar.gz)"
  if ! wget -q "https://go.dev/dl/go${go_version}.linux-${arch}.tar.gz" -O "${tmp_tgz}"; then
    echo ">> Versão ${go_version} indisponível; tentando fallback ${GO_VERSION_FALLBACK}"
    go_version="${GO_VERSION_FALLBACK}"
    wget -q "https://go.dev/dl/go${go_version}.linux-${arch}.tar.gz" -O "${tmp_tgz}" || {
      rm -f "${tmp_tgz}"
      echo "ERRO: falha ao baixar Go"
      return 1
    }
  fi

  rm -rf /usr/local/go
  tar -C /usr/local -xzf "${tmp_tgz}" || {
    rm -f "${tmp_tgz}"
    echo "ERRO: falha ao extrair Go"
    return 1
  }
  rm -f "${tmp_tgz}"

  cat > /etc/profile.d/go.sh <<'EOF'
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
  chmod +x /etc/profile.d/go.sh
  export PATH="/usr/local/go/bin:${PATH}"

  go version || return 1
  echo ">> Go ${go_version} instalado."
  return 0
}
