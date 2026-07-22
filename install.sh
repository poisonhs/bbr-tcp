#!/usr/bin/env sh
# BBR + TCP tuning installer for Linux VPS
# Usage: sudo sh install.sh [--apply|--remove|--dry-run]
set -eu

CONF_FILE=/etc/sysctl.conf
MODE=apply

usage() {
  printf '%s\n' \
    '用法：sudo sh install.sh [选项]' \
    '' \
    '  --apply      写入并立即应用 BBR/TCP 配置（默认）' \
    '  --remove     备份后清空 /etc/sysctl.conf' \
    '  --dry-run    仅显示将尝试应用的配置，不修改系统' \
    '  -h, --help   显示此帮助'
}

[ "${1:-}" = "--remove" ] && MODE=remove
[ "${1:-}" = "--dry-run" ] && MODE=dry-run
case "${1:-}" in ""|--apply|--remove|--dry-run) ;; -h|--help) usage; exit 0 ;; *) usage >&2; exit 2 ;; esac

if [ "$(id -u)" -ne 0 ]; then
  echo "错误：请使用 root 权限运行，例如：sudo sh install.sh" >&2
  exit 1
fi

if [ "$MODE" = remove ]; then
  if [ -f "$CONF_FILE" ]; then
    BACKUP="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONF_FILE" "$BACKUP"
    : > "$CONF_FILE"
    echo "已清空配置文件：$CONF_FILE"
    echo "备份文件：$BACKUP"
    echo "部分内核参数仍可能保留在内存中；如需完全恢复，请重启系统。"
  else
    echo "无需清空：$CONF_FILE 不存在。"
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
  echo "错误：系统中未找到 sysctl 命令。" >&2
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
    echo "错误：当前 VPS 内核不支持 BBR。" >&2
    echo "可用拥塞控制算法：${AVAILABLE:-未知}" >&2
    echo "请使用支持 BBR 的 Linux 内核（通常为 4.9+），或联系 VPS 服务商。" >&2
    exit 1
    ;;
esac

if [ ! -f "$CONF_FILE" ]; then
  : > "$CONF_FILE"
fi

BACKUP="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONF_FILE" "$BACKUP"
echo "已备份原配置到：$BACKUP"

# 逐项尝试应用；只有 VPS 接受的参数才会写入配置文件。
TMP_FILE="${CONF_FILE}.tmp.$$"
: > "$TMP_FILE"
printf '%s\n' "$TUNING" | while IFS= read -r LINE || [ -n "$LINE" ]; do
  [ -n "$LINE" ] || continue
  KEY=${LINE%% =*}
  VALUE=${LINE#*= }
  if sysctl -w "$KEY=$VALUE" >/dev/null 2>&1; then
    printf '%s\n' "$LINE" >> "$TMP_FILE"
    echo "已应用：$KEY = $VALUE"
  else
    echo "已跳过（参数不存在或 VPS 限制）：$KEY"
  fi
done

mv "$TMP_FILE" "$CONF_FILE"

echo
echo "BBR/TCP 调优已完成。"
printf '当前拥塞控制算法：'; sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '未知'
printf '默认队列规则：    '; sysctl -n net.core.default_qdisc 2>/dev/null || echo '不支持'
printf '配置文件：        %s\n' "$CONF_FILE"
echo "只有成功应用的参数已写入配置文件，重启后会自动加载。"
