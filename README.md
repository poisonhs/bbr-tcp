# BBR TCP Tune

用于 Linux VPS 的 BBR 与 TCP 参数一键配置脚本。脚本会将配置块追加到 `/etc/sysctl.conf`，不会覆盖该文件中原有的其他设置。

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
sudo sh install.sh --remove   # 删除本脚本写入的配置块
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
- 脚本只管理 `# >>> bbr-tcp-tune >>>` 与 `# <<< bbr-tcp-tune <<<` 两个标记之间的配置，不会改动 `/etc/sysctl.conf` 中其他内容。
- `--remove` 只会删除上述脚本管理的配置块，不会自动恢复之前的备份文件。
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
