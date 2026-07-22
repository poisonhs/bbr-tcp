# BBR TCP Tune

用于 Linux VPS 的 BBR 与 TCP 参数一键配置脚本。脚本会在备份后清空并完全重写 `/etc/sysctl.conf`，只保留本项目提供的配置。

## 安装

以 root 身份运行脚本：

```sh
sudo sh install.sh
```

或者克隆仓库后执行：

```sh
git clone https://github.com/poisonhs/bbr-tcp.git
cd bbr-tcp
sudo sh install.sh
```

一键安装：

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/poisonhs/bbr-tcp/main/install.sh)
```

如果系统没有安装 `bash`，可以使用：

```sh
curl -fsSL https://raw.githubusercontent.com/poisonhs/bbr-tcp/main/install.sh -o install.sh
sudo sh install.sh
```

## 命令

```sh
sudo sh install.sh --dry-run  # 仅查看将写入的 sysctl 配置
sudo sh install.sh --apply    # 写入并立即加载配置（默认）
sudo sh install.sh --remove   # 备份后清空 /etc/sysctl.conf
```

## 写入的配置

```conf
net.core.default_qdisc = fq
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 131072
```

## 注意事项

- 需要 root 权限，并且 VPS 内核必须在 `net.ipv4.tcp_available_congestion_control` 中提供 `bbr`。
- 大多数 Linux 4.9 及以上内核支持 BBR；部分 OpenVZ/LXC 容器可能限制 `sysctl` 参数写入。
- 每次执行安装或卸载前，脚本都会创建带时间戳的 `/etc/sysctl.conf` 备份。
- 执行安装会**清空并覆盖** `/etc/sysctl.conf`，文件中原有的所有 sysctl 配置都会被删除。
- 部分 OpenVZ/LXC 容器可能不支持或禁止修改某些参数。脚本会自动跳过这些参数，继续应用其余参数，并且只将成功应用的参数写入 `/etc/sysctl.conf`。
- `--remove` 同样会备份后清空整个 `/etc/sysctl.conf`；需要恢复旧配置时，请从自动生成的备份文件手动恢复。
- 公开网络脚本执行前请先审查内容。生产环境建议克隆固定的 tag 或 commit，而不是长期直接执行 `main` 分支。

## 验证是否生效

```sh
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

预期输出分别为：

```text
bbr
fq
```
