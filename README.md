<div align="center">

# MTProxyMax

**功能完整的 Telegram MTProto 代理管理器**

基于 **telemt 3.x Rust 引擎**，提供交互式终端界面、完整命令行工具、Telegram 机器人、多用户访问控制、流量监控、代理链、自动更新和企业级运维能力。

[快速安装](#快速安装) · [功能概览](#功能概览) · [命令参考](#命令参考) · [Telegram 机器人](#telegram-机器人) · [故障排查](#故障排查)

</div>

![MTProxyMax 主菜单](main.png)

## 快速安装

### 一键安装

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/anlo7676/MTProxyMax/main/install.sh)"
```

安装向导会引导你完成端口、伪装域名、首个用户密钥以及可选 Telegram 机器人的配置。

### 手动安装

```bash
curl -fsSL https://raw.githubusercontent.com/anlo7676/MTProxyMax/main/mtproxymax.sh -o mtproxymax
chmod +x mtproxymax
sudo ./mtproxymax install
```

安装完成后运行交互式菜单或查看帮助：

```bash
sudo mtproxymax
mtproxymax help
```

## 为什么选择 MTProxyMax

普通 MTProto 工具通常只负责启动代理并生成链接。MTProxyMax 在此基础上提供完整的管理层：

- 基于 telemt 3.x 的高性能异步 Rust 引擎。
- FakeTLS 流量伪装、抗 DPI、主动探测防御和紧急锁定。
- 为每位用户创建独立密钥，可单独禁用、轮换和撤销。
- 支持连接数、唯一 IP 数、流量配额和到期时间限制。
- 实时流量统计、Prometheus 指标和用户级用量追踪。
- 通过 Telegram 机器人远程管理并提供用户自助服务。
- 支持 SOCKS5、HTTP、MTProto、WARP、V2Ray 和 Xray 等上游代理链。
- 支持地理位置屏蔽、IP 封禁、维护模式和防火墙管理。
- 支持主从复制、配置同步、备份、迁移和自动恢复。
- 同时提供交互式终端菜单和适合自动化的完整 CLI。

## 系统要求

- Linux 服务器，推荐 Ubuntu 20.04+、Debian 11+、Rocky Linux 9+ 或同类发行版。
- Bash 4.2 或更高版本。
- root 权限。
- 至少 512 MB 内存；从源码构建时建议 2 GB 以上。
- Docker，安装程序可自动安装。
- 一个可从公网访问的 TCP 端口。
- 用于 FakeTLS 的可访问 HTTPS 域名。

支持 `amd64`、`arm64` 以及 Docker 镜像覆盖的其他架构。

## 功能概览

### FakeTLS 与抗 DPI

MTProxyMax 使用以 `ee` 开头的 FakeTLS 密钥，将 MTProto 流量伪装为正常 TLS 流量。可配置域名池、TLS 记录填充轮换、TCP MSS 钳制、反向代理掩护和主动探测蜜罐。

```bash
mtproxymax status
mtproxymax domain set cloudflare.com
mtproxymax cover-test
mtproxymax dpi-scan
mtproxymax dpi-score
mtproxymax anti-dpi-shield on
mtproxymax cover-shield on
```

紧急情况下可以启用锁定模式：

```bash
mtproxymax lockdown on
mtproxymax lockdown status
mtproxymax lockdown off
```

锁定模式会启用 SYN 防护、强化连接跟踪设置、应用 MSS 钳制，并通过已配置的 Telegram 机器人发送警报。

### 多用户密钥管理

每位用户都可以拥有独立密钥和连接链接。删除、禁用或轮换某个用户不会影响其他用户。

```bash
mtproxymax secret add alice
mtproxymax secret add bob
mtproxymax secret list
mtproxymax secret link alice
mtproxymax secret info alice
mtproxymax secret disable alice
mtproxymax secret enable alice
mtproxymax secret rotate alice
mtproxymax secret remove alice
```

批量管理、搜索和软删除：

```bash
mtproxymax secret add-batch alice bob carol
mtproxymax secret remove-batch alice bob
mtproxymax secret search team
mtproxymax secret sort traffic
mtproxymax secret top 10 traffic
mtproxymax secret export > users.csv
mtproxymax secret import users.csv
mtproxymax secret archive alice
mtproxymax secret archived
mtproxymax secret unarchive alice
```

### 用户限制与配额

可以分别设置最大 TCP 连接数、唯一 IP 数、流量配额和到期日期：

```bash
mtproxymax secret setlimits alice 15 5 10G 2026-12-31
mtproxymax secret limits alice
mtproxymax secret reset-traffic alice
mtproxymax secret extend alice 30
```

每个 Telegram 客户端通常会建立约 3 个 TCP 连接。限制设备数量时应预留余量，例如 `conns 15` 大约适合 5 台设备。移动网络可能短时间切换 IP，同一 Wi-Fi 下的多台设备也可能共享同一公网 IP，因此 IP 限制更适合作为辅助措施。

配置每月自动重置配额：

```bash
mtproxymax secret quota-reset alice 1
mtproxymax secret quota-reset alice off
```

### 流量与实时监控

```bash
mtproxymax traffic
mtproxymax traffic live
mtproxymax connections
mtproxymax metrics
mtproxymax metrics live 5
mtproxymax live-diag
```

流量统计默认是累计值。用户流量重置与服务器总流量重置相互独立：

```bash
mtproxymax secret reset-traffic alice
mtproxymax traffic reset-total
```

### Telegram 机器人

通过向导启用或重新配置机器人：

```bash
mtproxymax telegram setup
mtproxymax telegram status
mtproxymax telegram test
mtproxymax telegram disable
```

配置完成后，在 Telegram 中向机器人发送 `/start` 即可打开常驻中文按钮菜单。公开用户可点击查询状态、兑换码和联系支持；管理员可通过分级菜单完成状态检查、密钥管理、流量查看、安全控制、重启和更新等操作。需要标签或参数时，机器人会逐步提示输入，无需记忆命令。原有命令仍然保留，便于自动化和高级使用。

公开自助命令：

| 命令 | 说明 |
|---|---|
| `/start` | 显示自助服务入口 |
| `/my_status <label>` | 查询账户状态、配额和到期时间 |
| `/redeem <code> [label]` | 兑换礼品码 |
| `/voucher <code> [label]` | `/redeem` 的别名 |
| `/support <message>` | 向管理员提交支持工单 |

管理员命令：

| 命令 | 说明 |
|---|---|
| `/mp_status` | 查看代理状态 |
| `/mp_secrets` | 列出密钥 |
| `/mp_link` | 获取代理链接和二维码 |
| `/mp_add <label>` | 添加密钥 |
| `/mp_remove <label>` | 移除密钥 |
| `/mp_rotate <label>` | 轮换密钥 |
| `/mp_enable <label>` | 启用密钥 |
| `/mp_disable <label>` | 禁用密钥 |
| `/mp_limits` | 查看用户限制 |
| `/mp_setlimit ...` | 设置用户限制 |
| `/mp_upstreams` | 列出上游代理 |
| `/mp_traffic` | 查看流量报告 |
| `/mp_health` | 执行健康检查 |
| `/mp_lockdown [on|off]` | 控制紧急锁定 |
| `/mp_digest` | 查看系统摘要 |
| `/mp_broadcast <msg>` | 向用户发送广播 |
| `/mp_restart` | 重启代理 |
| `/mp_update` | 检查更新 |
| `/mp_help` | 显示帮助 |

管理角色：

```bash
mtproxymax admin add <chat_id> superadmin
mtproxymax admin add <chat_id> reseller
mtproxymax admin remove <chat_id>
mtproxymax admin list
```

### 代理链与上游路由

可以将发往 Telegram 数据中心的流量转发到 SOCKS5、HTTP、MTProto 或网络接口上游，以绕过数据中心封锁或实现多出口负载分配。

```bash
mtproxymax upstream add warp socks5 127.0.0.1:40000
mtproxymax upstream add backup socks5 203.0.113.10:1080
mtproxymax upstream list
mtproxymax upstream test warp
mtproxymax upstream disable warp
mtproxymax upstream enable warp
mtproxymax upstream remove warp
```

上游地址支持主机名。使用 SOCKS5 主机名解析时，引擎会通过代理完成远程 DNS 解析。

### 地理位置屏蔽与 IP 封禁

```bash
mtproxymax geoblock add CN
mtproxymax geoblock remove CN
mtproxymax geoblock list
mtproxymax geoblock mode blacklist
mtproxymax geoblock mode whitelist
mtproxymax ban add 203.0.113.5
mtproxymax ban remove 203.0.113.5
mtproxymax ban list
```

地理位置规则依赖主机的 `iptables`、`nftables` 和 IP 集合能力。云服务器还需要在服务商安全组中放行代理端口。

### 带宽整形与速度限制

```bash
mtproxymax qos 20
mtproxymax qos status
mtproxymax qos off
mtproxymax speed-limit set alice 10mbit
mtproxymax speed-limit list
mtproxymax speed-limit remove alice
```

QoS 使用 Linux `tc` 对用户或 IP 应用带宽限制。配置优惠时段后，可以在指定时段暂停配额计费。

### 备份、恢复与迁移

```bash
mtproxymax backup
mtproxymax backup list
mtproxymax restore /opt/mtproxymax/backups/backup.tar.gz
mtproxymax backup --encrypted
mtproxymax restore --encrypted /path/to/backup.enc
```

服务器迁移：

```bash
# 在旧服务器上
mtproxymax migrate export

# 将归档复制到新服务器后执行
mtproxymax migrate import /path/to/mtproxymax-migration.tar.gz
```

异地云备份：

```bash
mtproxymax backup-cloud toggle
mtproxymax backup-cloud push
mtproxymax backup-cloud status
mtproxymax backup-cloud off
```

支持将备份发送到 Telegram 管理员聊天，也可以通过 `rclone`、AWS S3 CLI 或 `s3cmd` 上传到对象存储。

### 主从复制与高可用

```bash
mtproxymax replication setup
mtproxymax replication add <host> [port] [label]
mtproxymax replication list
mtproxymax replication test
mtproxymax replication sync
mtproxymax replication status
mtproxymax replication logs
```

主节点会通过 SSH/rsync 将设置、密钥、标签和策略同步到从节点。请先配置基于密钥的 SSH 登录，并限制同步账户的权限。

### 性能与自愈

```bash
mtproxymax tcp-boost on
mtproxymax tcp-clean on
mtproxymax socket-boost on
mtproxymax tcp-fastpath on
mtproxymax ram-tune on
mtproxymax cpu-tune on
mtproxymax auto-heal on
mtproxymax heal-now
```

这些功能可能修改内核参数、队列和网卡设置。启用后建议运行 `mtproxymax verify` 和 `mtproxymax doctor`。

### 维护模式

```bash
mtproxymax maintenance on
mtproxymax maintenance status
mtproxymax maintenance off
```

维护模式可临时阻止新连接，便于执行升级、迁移或网络调整。

## 命令参考

### 服务管理

```bash
mtproxymax install
mtproxymax start
mtproxymax stop
mtproxymax restart
mtproxymax status
mtproxymax logs
mtproxymax update
mtproxymax uninstall
```

### 密钥管理

```bash
mtproxymax secret add <label> [secret]
mtproxymax secret remove <label>
mtproxymax secret list
mtproxymax secret link <label>
mtproxymax secret rotate <label>
mtproxymax secret enable <label>
mtproxymax secret disable <label>
mtproxymax secret setlimits <label> <conns> <ips> <quota> [expires]
mtproxymax secret limits <label>
mtproxymax secret note <label> [text]
mtproxymax secret adtag <label> <tag|clear>
mtproxymax secret reset-traffic <label|all>
mtproxymax secret rename <old-label> <new-label>
mtproxymax secret clone <source-label> <new-label>
mtproxymax secret extend <label> <days>
mtproxymax secret bulk-extend <days>
mtproxymax secret disable-expired
mtproxymax secret archive <label>
mtproxymax secret unarchive <label>
mtproxymax secret archived
mtproxymax secret search <query>
mtproxymax secret top [count] [traffic|connections]
mtproxymax secret export
mtproxymax secret import <file>
```

### 网络、安全与诊断

```bash
mtproxymax doctor
mtproxymax verify
mtproxymax health
mtproxymax ping-dc
mtproxymax net-grade
mtproxymax speedtest
mtproxymax port-check
mtproxymax cover-test
mtproxymax dpi-scan
mtproxymax dpi-score
mtproxymax live-diag
mtproxymax audit
```

### 配置与资料

```bash
mtproxymax config
mtproxymax info
mtproxymax server-info
mtproxymax changelog
mtproxymax profile save <name>
mtproxymax profile load <name>
mtproxymax profile list
mtproxymax completion
```

### 自定义 Telegram 基础设施地址

在官方 Telegram 地址受限的地区，可以设置自定义镜像：

```bash
mtproxymax tg-urls get
mtproxymax tg-urls set secret https://mirror.example.com/getProxySecret
mtproxymax tg-urls set config-v4 https://mirror.example.com/getProxyConfig
mtproxymax tg-urls set config-v6 https://mirror.example.com/getProxyConfigV6
mtproxymax tg-urls clear
```

### 广告标签

从 [@MTProxyBot](https://t.me/MTProxyBot) 获取广告标签：

```bash
mtproxymax adtag set <hex_from_MTProxyBot>
mtproxymax adtag show
mtproxymax adtag clear
mtproxymax secret adtag <label> <tag>
mtproxymax secret adtag <label> clear
```

## 配置文件

默认安装目录为 `/opt/mtproxymax`：

| 路径 | 用途 |
|---|---|
| `/opt/mtproxymax/mtproxymax` | 主程序 |
| `/opt/mtproxymax/settings.conf` | 全局设置 |
| `/opt/mtproxymax/secrets.conf` | 用户密钥与限制 |
| `/opt/mtproxymax/upstreams.conf` | 上游代理 |
| `/opt/mtproxymax/config.toml` | telemt 引擎配置 |
| `/opt/mtproxymax/admins.conf` | Telegram 管理员角色 |
| `/opt/mtproxymax/backups/` | 本地备份 |
| `/etc/systemd/system/mtproxymax.service` | 代理服务 |
| `/etc/systemd/system/mtproxymax-bot.service` | Telegram 机器人服务 |

这些文件可能包含代理密钥、机器人令牌和其他敏感数据。请限制访问权限，不要提交到公开仓库或粘贴到公开问题中。

## 防火墙与端口转发

使用 UFW：

```bash
sudo ufw allow <port>/tcp
sudo ufw status
```

使用 firewalld：

```bash
sudo firewall-cmd --permanent --add-port=<port>/tcp
sudo firewall-cmd --reload
```

如果服务器位于家庭路由器之后，还需要将公网 TCP 端口转发到服务器的局域网 IP。使用 CGNAT 的网络通常无法直接配置入站端口转发，请向运营商申请公网 IP 或使用具备公网入口的服务器。

## 故障排查

首先运行综合诊断：

```bash
sudo mtproxymax doctor
sudo mtproxymax verify
sudo mtproxymax status
sudo mtproxymax logs
```

常见检查项：

- 确认 Docker 服务正在运行：`systemctl status docker`。
- 确认代理容器存在：`docker ps -a`。
- 确认端口正在监听：`ss -lntp`。
- 确认主机防火墙和云服务商安全组都已放行 TCP 端口。
- 确认 FakeTLS 域名可访问并拥有有效 TLS 证书。
- 确认系统时间准确，必要时启用 NTP。
- Telegram 机器人异常时，检查令牌、聊天 ID、网络连通性及 `mtproxymax-bot` 服务日志。

```bash
journalctl -u mtproxymax -n 100 --no-pager
journalctl -u mtproxymax-bot -n 100 --no-pager
```

## 安全建议

- 为每位用户创建独立密钥，不要多人长期共用同一密钥。
- 为用户配置合理的配额、连接数和到期时间。
- 定期轮换管理员凭据、机器人令牌和敏感密钥。
- 将备份保存在服务器之外，并验证恢复流程。
- 仅开放 SSH、代理端口以及明确需要的管理端口。
- 使用 SSH 密钥登录，禁用不必要的密码登录和 root 远程登录。
- 升级前先创建备份，并查看更新日志。

## 更新

```bash
sudo mtproxymax backup
sudo mtproxymax update
```

脚本会从当前项目仓库下载新版本，并在替换前执行 Bash 语法校验。

## 项目与相关组件

- 项目仓库：[anlo7676/MTProxyMax](https://github.com/anlo7676/MTProxyMax)
- telemt 引擎：[telemt/telemt](https://github.com/telemt/telemt)
- Telegram 官方 MTProxy：[TelegramMessenger/MTProxy](https://github.com/TelegramMessenger/MTProxy)
- 广告标签机器人：[@MTProxyBot](https://t.me/MTProxyBot)

## 许可证

MTProxyMax 管理脚本采用 [MIT 许可证](LICENSE)。

随 Docker 镜像提供的 telemt 引擎采用 [Telemt Public License 3（TPL-3）](https://github.com/telemt/telemt/blob/main/LICENSE)，使用、再分发或修改时应遵守其许可证要求。

## 致谢

感谢 telemt、Telegram MTProxy 以及相关开源项目的作者和贡献者。
