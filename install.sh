#!/usr/bin/env sh
# BBR + TCP tuning installer for Linux VPS
# Usage: sudo sh install.sh [--apply|--remove|--dry-run]
set -eu

CONF_FILE=/etc/sysctl.conf
MODE=apply

usage() {
  printf '%s\n' \
    'Usage: sudo sh install.sh [OPTION]' \
    '' \
    '  --apply      Write and load BBR/TCP tuning configuration (default)' \
    '  --remove     Remove this script'\''s configuration and reload sysctl settings' \
    '  --dry-run    Show the configuration without changing the system' \
    '  -h, --help   Show this help'
}

[ "${1:-}" = "--remove" ] && MODE=remove
[ "${1:-}" = "--dry-run" ] && MODE=dry-run
case "${1:-}" in ""|--apply|--remove|--dry-run) ;; -h|--help) usage; exit 0 ;; *) usage >&2; exit 2 ;; esac

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: please run as root, for example: sudo sh install.sh" >&2
  exit 1
fi

if [ "$MODE" = remove ]; then
  if [ -f "$CONF_FILE" ]; then
    BACKUP="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONF_FILE" "$BACKUP"
    : > "$CONF_FILE"
    echo "Cleared: $CONF_FILE"
    echo "Backup saved to: $BACKUP"
    echo "Reboot to clear values that remain only in memory."
  else
    echo "Nothing to remove: $CONF_FILE does not exist."
  fi
  exit 0
fi

TUNING='net.core.default_qdisc = fq
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864

net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 131072'

if [ "$MODE" = dry-run ]; then
  echo "$TUNING"
  exit 0
fi

if ! command -v sysctl >/dev/null 2>&1; then
  echo "Error: sysctl was not found." >&2
  exit 1
fi

# BBR is built into most modern kernels; try loading it when supplied as a module.
if command -v modprobe >/dev/null 2>&1; then
  modprobe tcp_bbr 2>/dev/null || true
fi

AVAILABLE="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
case " $AVAILABLE " in
  *" bbr "*) ;;
  *)
    echo "Error: this VPS kernel does not expose BBR." >&2
    echo "Available algorithms: ${AVAILABLE:-unknown}" >&2
    echo "Use a Linux kernel with BBR support (normally 4.9+) or ask your VPS provider." >&2
    exit 1
    ;;
esac

if [ ! -f "$CONF_FILE" ]; then
  : > "$CONF_FILE"
fi

BACKUP="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONF_FILE" "$BACKUP"
echo "Backed up existing file to: $BACKUP"

# Replace the full sysctl.conf after creating a backup.
TMP_FILE="${CONF_FILE}.tmp.$$"
printf '%s\n' "$TUNING" > "$TMP_FILE"
mv "$TMP_FILE" "$CONF_FILE"

if ! sysctl -p "$CONF_FILE"; then
  echo "Error: the configuration was saved but could not be fully applied." >&2
  echo "Your VPS may restrict sysctl changes (common with some containers)." >&2
  exit 1
fi

echo
echo "BBR/TCP tuning applied successfully."
printf 'Congestion control: '; sysctl -n net.ipv4.tcp_congestion_control
printf 'Default qdisc:      '; sysctl -n net.core.default_qdisc
printf 'Config file:        %s\n' "$CONF_FILE"
echo "The configuration persists after reboot."
