# 修复 VPN —— macOS mihomo 代理方案

2026-11-21 建立。起因是 VPN Super（iPad 版跑在 Mac 上）连不上，改用 mihomo 内核 + 免费节点。

## 结论先行

**VPN Super 在 Mac 上用不了，不是账号问题。**

- 它是 iOS/iPad 版套壳（`DTPlatformName = iphoneos`），不是原生 macOS 客户端
- 免费版只提供 OpenVPN 一种协议，没有任何混淆
- 日志证据：13 次连接尝试，`ConnectedCount: 0`，每次都是 `Send hard reset` 后 `No packets`
- 外部对照：Google STUN 的 UDP 高端口有回包，VPN Super 服务器端口全部无回应 → 协议被拦，不是本地网络问题

## 现在的方案

mihomo 内核（Clash Meta 兼容）+ 48 个实测可用的免费节点，内核内部按域名/IP 自动分流。

### 分流逻辑

| 目标 | 处理 |
|---|---|
| 局域网 `127.0.0.0/8` `192.168.0.0/16` `10.0.0.0/8` `172.16.0.0/12` | DIRECT |
| `GEOSITE,cn` + `GEOIP,CN` | DIRECT |
| google / youtube / github / twitter / openai / telegram / netflix / facebook / instagram / cloudflare / reddit / stackexchange / medium / notion / spotify / apple | 走代理 |
| 其余 | 走代理 |

分流在**内核里**做，不依赖外部 PAC 文件（PAC 方案已废弃：`~/.config` 是 `drwx------`，浏览器沙盒进程读不到，实测 Chrome 零连接）。

## 命令

```
proxy-on        开启（同时也是开机自启的入口）
proxy-off       关闭（停服务 + 关系统代理，但下次开机仍会自启）
proxy-disable   彻底禁用（移除开机自启）
proxy-check     检查 48 个节点还剩几个活着
```

## 文件位置

```
~/.local/bin/mihomo              内核（54M，不在本仓库，见下文下载）
~/.local/bin/mihomo-boot         开机自启入口（等网络就绪 → 起内核 → 等端口 → 设代理）
~/.local/bin/proxy-on            开
~/.local/bin/proxy-off           关
~/.local/bin/proxy-disable       彻底禁用
~/.local/bin/proxy-check         节点健康检查
~/.config/mihomo/config.yaml     48 节点 + 25 条规则
~/Library/LaunchAgents/com.user.mihomo.plist   开机自启
```

## 内核下载

仓库里没放内核二进制（54M）。重新获取：

```bash
# 从 GitHub 拿，国内直连下不动，用 ghfast.top 镜像（实测 641KB/s，比 gh-proxy 快 7 倍）
curl -L -o /tmp/mihomo.gz \
  "https://ghfast.top/https://github.com/MetaCubeX/mihomo/releases/download/v1.19.34/mihomo-darwin-arm64-v1.19.34.gz"
gunzip -f /tmp/mihomo.gz
chmod +x /tmp/mihomo
mv /tmp/mihomo ~/.local/bin/mihomo
```

## 开机自启的工作方式

launchd 调用 `mihomo-boot`，它按顺序做四件事：

1. 等网络就绪（最多 30 秒，轮询 `scutil --nwi`）
2. 起内核
3. 等 7890 端口监听（最多 20 秒，`nc -z`）
4. **端口通了才设置系统代理**

第 4 步的顺序很关键：如果先设代理再起内核，开机瞬间所有流量会指向一个没监听的空端口，表现为断网。

`KeepAlive = {SuccessfulExit: false}`，内核崩溃会被自动拉起（实测 kill -9 后约 15 秒恢复）。

## 卸载残留清理

卸载 VPN Super / ProtonVPN / Hiddify 后，用户级数据已清，系统级三项受权限限制：

```bash
sudo bash cleanup/remove-system-residue.sh   # 只能处理第 1 项
```

| 项目 | 能否脚本处理 | 说明 |
|---|---|---|
| VPN Super.app | ✅ 需 sudo | 归 root:wheel |
| 系统 VPN 配置 | ❌ 只能 GUI | `networksetup` 无法删 VPN 类型服务 |
| ProtonVPN 系统扩展 | ❌ 只能 GUI | SIP 开启时 `systemextensionsctl uninstall` 不可用 |

GUI 位置：

```
系统设置 → 网络 → 选中「VPN Super - OpenVPN」→ 点「−」
系统设置 → 通用 → 登录项与扩展 → 网络扩展 → 移除 Proton VPN 两项
```

## 注意事项

**节点是消耗品。** 48 个节点来自公开聚合源（yoyapai.com 等），我实测筛过：从 10048 个节点 → 7187 去重 → 2109 TCP 可达 → 79 通过内核测速 → 48 真实流量验证。

它们随时会失效。`proxy-check` 显示大量死亡时，需要重新抓节点。

**不要提交凭证。** `config.yaml` 里每个节点都带 `password`/`uuid`。这是公开免费节点，但仍属于凭证。

**Hiddify 装了但没用。** `/Applications/Hiddify.app` v5.5.5，原生 macOS 版（`DTPlatformName = macosx`），能启动、端口能监听，但订阅导入一直报"意外连接错误"。试过 URL scheme、最简配置、文件导入三种方式都失败。留作备选。

## 排查记录

`docs/` 下是当时的诊断证据。
