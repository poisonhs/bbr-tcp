# BBR TCP Tune

A small, idempotent Linux VPS installer for enabling BBR and applying conservative TCP buffer tuning by adding a managed block to `/etc/sysctl.conf`. Existing settings outside that block are preserved.

## Install

Run the script as root:

```sh
sudo sh install.sh
```

Or execute it directly after cloning:

```sh
git clone https://github.com/poisonhs/bbr-tcp.git
cd bbr-tcp
sudo sh install.sh
```

One-line install after publishing the repository:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/poisonhs/bbr-tcp/main/install.sh)
```

## Commands

```sh
sudo sh install.sh --dry-run  # show the sysctl configuration
sudo sh install.sh --apply    # write and apply it
sudo sh install.sh --remove   # remove this script's configuration
```

## Applied settings

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

## Requirements and notes

- Requires root privileges and a Linux kernel exposing `bbr` in `net.ipv4.tcp_available_congestion_control`.
- Most Linux kernels 4.9+ provide BBR, but OpenVZ/LXC-style containers may restrict `sysctl` writes.
- The installer creates a timestamped backup of `/etc/sysctl.conf` before every apply or remove action.
- The installer manages only the block between `# >>> bbr-tcp-tune >>>` and `# <<< bbr-tcp-tune <<<`; all other `/etc/sysctl.conf` settings are preserved.
- `--remove` deletes only that managed block. It does not restore a previous backup automatically.
- Review remote scripts before running them. For production use, clone a tagged release or pin a commit hash instead of executing an unpinned branch URL.

## Verify

```sh
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

Expected values are `bbr` and `fq`.
