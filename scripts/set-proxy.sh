#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"

if [[ -z "$MODE" ]]; then
  echo "Usage:"
  echo "  $0 <ip:port>      # atau http(s)://host:port"
  echo "  $0 reset"
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
ETC_ENV="/etc/environment"
APT_PROXY="/etc/apt/apt.conf.d/95proxy"
VSCODE_SETTINGS="$REAL_HOME/.config/Code/User/settings.json"

TMP_DIR="$(mktemp -d)"
cleanup_tmp() { rm -rf "$TMP_DIR"; }
trap cleanup_tmp EXIT

remove_proxy_block() {
  local file="$1"
  [[ -f "$file" ]] || return
  local tmp="$TMP_DIR/clean.$(basename "$file").$$"
  sed '/# BEGIN PROXY SET/,/# END PROXY SET/d' "$file" > "$tmp"
  sudo mv "$tmp" "$file"
  sudo chmod 0644 "$file"
}

clean_environment_file() {
  [[ -f "$ETC_ENV" ]] || return
  remove_proxy_block "$ETC_ENV"
  local tmp="$TMP_DIR/env_strip.$$"
  sudo grep -Ev '^(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|no_proxy|NO_PROXY)=' "$ETC_ENV" \
    | sudo sed '/# BEGIN PROXY SET/,/# END PROXY SET/d' > "$tmp" || true
  sudo mv "$tmp" "$ETC_ENV"
  sudo chmod 0644 "$ETC_ENV"
}

clean_vscode_settings() {
  [[ -f "$VSCODE_SETTINGS" ]] || return
  sudo -u "$REAL_USER" bash -c "python3 - <<'PY'
import json,sys
p='$VSCODE_SETTINGS'
try:
    with open(p,'r') as f:
        s=json.load(f)
except:
    sys.exit(0)
for k in ['http.proxy','http.proxyStrictSSL']:
    s.pop(k,None)
with open(p,'w') as f:
    json.dump(s,f,indent=2)
PY"
  chown "$REAL_USER":"$REAL_USER" "$VSCODE_SETTINGS" || true
}

clear_snap_proxy() {
  if command -v snap >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    snap set system proxy.http=
    snap set system proxy.https=
  fi
}

reset_proxy() {
  echo "[*] Resetting proxy..."

  if [[ "$(id -u)" -eq 0 ]]; then
    clean_environment_file
    rm -f "$APT_PROXY" 2>/dev/null || true
  fi

  clear_snap_proxy
  clean_vscode_settings

  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
  echo "[✓] Proxy reset complete."
  echo "Logout/login supaya environment global kebaca."
  exit 0
}

if [[ "$MODE" == "reset" ]]; then
  reset_proxy
fi

PROXY_ARG="$MODE"

if [[ "$PROXY_ARG" =~ ^https?:// ]]; then
  PROXY_URL="$PROXY_ARG"
else
  PROXY_URL="http://$PROXY_ARG"
fi

if ! [[ "$PROXY_URL" =~ ^https?://[^:/[:space:]]+:[0-9]+$ ]]; then
  echo "[!] Format proxy salah: host:port atau http(s)://host:port"
  exit 1
fi

HTTP_PROXY="$PROXY_URL"
HTTPS_PROXY="$PROXY_URL"

echo "[*] Setting proxy = $HTTP_PROXY"

if [[ "$(id -u)" -eq 0 ]]; then
  [[ -f "$ETC_ENV" ]] || sudo touch "$ETC_ENV"
  remove_proxy_block "$ETC_ENV"

  sudo bash -c "cat >> '$ETC_ENV' <<EOF

# BEGIN PROXY SET
http_proxy=\"$HTTP_PROXY\"
https_proxy=\"$HTTPS_PROXY\"
HTTP_PROXY=\"$HTTP_PROXY\"
HTTPS_PROXY=\"$HTTPS_PROXY\"
no_proxy=\"localhost,127.0.0.1,::1\"
NO_PROXY=\"localhost,127.0.0.1,::1\"
# END PROXY SET
EOF"
fi

if [[ "$(id -u)" -eq 0 ]]; then
  cat > "$TMP_DIR/apt_proxy.$$" <<EOF
Acquire {
  HTTP::proxy "$HTTP_PROXY";
  HTTPS::proxy "$HTTPS_PROXY";
}
EOF
  sudo mv "$TMP_DIR/apt_proxy.$$" "$APT_PROXY"
  sudo chmod 0644 "$APT_PROXY"
fi

if command -v snap >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
  snap set system proxy.http="$HTTP_PROXY"
  snap set system proxy.https="$HTTP_PROXY"
fi

sudo -u "$REAL_USER" mkdir -p "$(dirname "$VSCODE_SETTINGS")"
[[ -f "$VSCODE_SETTINGS" ]] || sudo -u "$REAL_USER" bash -c "echo '{}' > '$VSCODE_SETTINGS'"

sudo -u "$REAL_USER" bash -c "python3 - <<'PY'
import json
p='$VSCODE_SETTINGS'
try:
    with open(p,'r') as f:
        s=json.load(f)
except:
    s={}
s['http.proxy'] = '$HTTP_PROXY'
s['http.proxyStrictSSL'] = False
with open(p,'w') as f:
    json.dump(s,f,indent=2)
PY"
chown "$REAL_USER":"$REAL_USER" "$VSCODE_SETTINGS" || true

export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export HTTP_PROXY="$HTTP_PROXY"
export HTTPS_PROXY="$HTTPS_PROXY"
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="localhost,127.0.0.1,::1"

echo "[✓] Proxy aktif: $HTTP_PROXY"
echo "Logout/login supaya environment global kebaca."
