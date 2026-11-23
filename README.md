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
proxy-check     检查节点还剩几个活着
proxy-fast      实测所有节点的真实下载带宽，排序后切到最快的
```

### proxy-fast

`proxy-check` 只测 TCP 可达性，`proxy-fast` 才测真实带宽。

```
proxy-fast          测速 + 显示排名 + 切到最快的
proxy-fast --auto   同上（保留参数形式）
```

输出示例：

```
   1/15    7.55 Mbps  🇮🇹IT-202.50.253.72-0256
   2/15    0.89 Mbps  🇮🇹IT-202.50.253.99-0212
   ...

  [OK ]    8.94 Mbps  IT-202.50.253.90-0199
  [slow]    2.52 Mbps  🇮🇹IT-202.50.253.90-0254
  [dead]    0.00 Mbps  🇳🇱 荷兰 | NLD

可用(>=3 Mbps): 3/15   最快: 8.94 Mbps
已切换到最快节点: IT-202.50.253.90-0199
```

需要内核开启 API（`external-controller: 127.0.0.1:9099`）。完整测 15 个节点约需 5-8 分钟。

## 文件位置

```
~/.local/bin/mihomo              内核（54M，不在本仓库，见下文下载）
~/.local/bin/mihomo-boot         开机自启入口（等网络就绪 → 起内核 → 等端口 → 设代理）
~/.local/bin/proxy-on            开
~/.local/bin/proxy-off           关
~/.local/bin/proxy-disable       彻底禁用
~/.local/bin/proxy-check         节点健康检查（TCP 层面）
~/.local/bin/proxy-fast          真实带宽测速与自动切换
~/.config/mihomo/config.yaml     节点 + 25 条规则（本仓库只带模板 config.example.yaml）
~/Library/LaunchAgents/com.user.mihomo.plist   开机自启（由 template 渲染，含本机 HOME）
```

## 配置节点

仓库里**不含真实节点**。`config.example.yaml` 是可直接使用的模板：分流规则齐全，节点是 4 个占位示例。

```bash
cp config.example.yaml ~/.config/mihomo/config.yaml
# 然后把 proxies: 下的示例节点换成你自己的可用节点（SS / VMess / VLESS / Trojan 均可）
proxy-on
```

示例节点的 `password` / `uuid` 是 `REPLACE_ME` 与全零 UUID，**原样启动是不通的**——这是刻意的，
避免仓库变成一份会跟着 star 流传的节点清单。规则段（`rules` / `geox-url` / `proxy-groups`）与节点无关，可以原样保留。

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

**节点是消耗品。** 节点来自公开聚合源，实测筛过。完整源清单见 [`docs/sources.md`](docs/sources.md)。

它们随时会失效。`proxy-check` 显示大量死亡时，需要重新抓节点。

**免费节点的带宽会剧烈波动。** 同一节点连续测得：

```
第1次:  8.38 Mbps
第2次:  1.95 Mbps
第3次:  0.44 Mbps
```

这是免费节点按需分配带宽的结果，任何配置策略都消除不了。觉得慢就跑一次 `proxy-fast` 换节点。

**mihomo 的 url-test 不测带宽。** 它只测首字节延迟，即使配 10MB 文件也不下载完整内容。所以会出现「延迟 497ms 被选中，实际带宽 0.04 Mbps」。想按带宽选只能用 `proxy-fast`。

**不要提交凭证。** 真实 `config.yaml` 里每个节点都带 `password`/`uuid`，已被 `.gitignore` 排除在本仓库之外。这是公开免费节点，但仍属于凭证。

**Hiddify 装了但没用。** `/Applications/Hiddify.app` v5.5.5，原生 macOS 版（`DTPlatformName = macosx`），能启动、端口能监听，但订阅导入一直报"意外连接错误"。试过 URL scheme、最简配置、文件导入三种方式都失败。留作备选。

## 排查记录

- [`docs/diagnosis.md`](docs/diagnosis.md) —— VPN Super 为什么在 Mac 上用不了，完整诊断过程
- [`docs/sources.md`](docs/sources.md) —— 免费节点源清单、镜像速度对比、测速踩过的坑

## 换节点时怎么操作

1. 从 `docs/sources.md` 挑一个源，下载 YAML
2. 把其中 `proxies:` 段替换到 `~/.config/mihomo/config.yaml`
3. 重启服务：

```bash
launchctl unload ~/Library/LaunchAgents/com.user.mihomo.plist
launchctl load  ~/Library/LaunchAgents/com.user.mihomo.plist
```

4. 跑 `proxy-fast` 实测挑出快的

## 觉得慢时的排查顺序

```
1. proxy-check     节点还活着吗？大量 dead 就该换源了
2. proxy-fast      活着的节点哪个带宽大？切过去
3. 换源            只有 2-3 个能用时，从 docs/sources.md 换一批
4. 还是慢          免费节点就这水平，考虑付费订阅
```
