# 诊断记录（2026-11-21）

## 一、VPN Super 为什么用不了

### 1. 应用类型判定

```
路径       : /Applications/VPN Super.app/Wrapper/vpn.app/vpn
DTPlatformName : iphoneos          ← iOS 应用
DTSDKName      : iphoneos27.2
MinimumOSVersion: 18.0
iTunesMetadata : is-purchased-redownload = true, storefront = us
```

对照 ProtonVPN（原生）：`DTPlatformName = macosx`。

### 2. 失败的两种形态

**形态 A：写配置被系统拒绝**（14:06:55）

```
[ERROR] [VPN] [Auto Connect] Error while connecting using: openvpn | Error: permission denied
[ERROR] [ConnectivityKit] connection attempt failed:
        NEVPNErrorDomain Code=5 "permission denied"
```

`NEVPNErrorDomain Code=5` = ConfigurationReadWriteFailed，是写 VPN 配置被拒，不是密码错。

系统侧对应：

```
scutil --nc list → (Invalid) 07004419-... "VPN Super - OpenVPN"
networksetup      → *VPN Super - OpenVPN    ← 星号 = 服务被禁用
```

已用 `networksetup -setnetworkserviceenabled on` 解除禁用，但没用（见形态 B）。

**形态 B：隧道起来了，服务器零回包**（主要问题）

```
ConnectCount: 13   ConnectedCount: 0
OpenVPN 扩展日志: "Send hard reset" 12 次
                  "No packets"     12 次
                  收到任何包        0 次
```

### 3. 排除本地网络问题

| 目标 | 结果 |
|---|---|
| Google STUN 74.125.250.129:19302（境外 UDP 高端口） | ✅ 有回包 32B |
| 167.88.61.163:800 / :110 | ❌ 无回包 |
| 23.162.152.101:800 | ❌ 无回包 |
| 62.93.166.180:110 | ❌ 无回包 |
| 92.223.65.44:110 | ❌ 无回包 |

UDP 出网正常，VPN 服务器端口全不应答。TCP traceroute 能到（17 跳，153ms），说明 IP 通、端口协议被拦。

### 4. 协议单一

```
available modes: [ConnectionModeDisplayModel(title: "OpenVPN", ...)]
协议统计: openvpn_v1_udp ×47, openvpn_v1_tcp ×37
```

免费版只有 OpenVPN，无混淆、无 Stealth。OpenVPN 明文特征在中国大陆是重点打击对象。

## 二、节点筛选过程

```
10048 个节点（sanfen 4489 + openprox 4789 + erna o 361 + fcn 196 + v2cross 201 + ripao 12）
  ↓ 按 server:port:type 去重
7187 个
  ↓ TCP 2.5s 超时探测
2109 个可达
  ↓ 逐源内核测速（分源测，避免大池并发饱和导致误判）
79 个通过
  ↓ 真实流量验证（curl 走代理访问 gstatic 204 + google 200，双确认）
48 个真正可用
```

**踩过的坑**：一次性测 2108 个节点时，mihomo 的 `/group/<name>/delay` 批量 API 返回只有 12-14 个可用，但分源测 125 个能测出 57 个。原因是批量测速时 host 并发饱和，大量节点被误判为死。后续改为分组小批量。

## 三、PAC 方案的废弃

最初用 `/Library/Preferences/SystemConfiguration` 级别的 PAC 文件分流，实测失败：

```
PAC 文件: ~/.config/mihomo/proxy.pac
目录权限: drwx------ __HOME__/.config
现象:    Chrome 到 7890 的连接数 = 0
```

浏览器沙盒进程读不到 `drwx------` 目录里的 PAC 文件，代理配置形同虚设。

**改为内核内分流**：mihomo 用 GEOSITE/GEOIP 规则自己判断，系统代理只需指向 127.0.0.1:7890。

验证（内核日志原文）：

```
www.baidu.com:443   match GeoSite(cn)     using DIRECT
m.google.com:443    match GeoSite(google) using 🚀 节点选择[🇮🇹 意大利]
```

## 四、脚本幂等性 bug

`fixrules.py` 第一版把 `stackexchange` 写成了 `stackoverflow`：

```
Parse config error: rules[17] [GEOSITE,stackoverflow,...] error:
list stackoverflow not found in geosite.dat
```

手动改了配置但没改脚本，导致**重复运行脚本会重新写回错误规则、配置直接失效**。

这个 bug 是跑幂等性测试（连跑两次 + 每次 `mihomo -t` 校验）才暴露的。只看第一次运行结果发现不了。

修复：脚本里统一用 `PROXY_SITES` 常量，名称改为 geosite 中真实存在的 `stackexchange`。

## 五、Hiddify 失败记录

```
版本: 5.5.5
类型: 原生 macOS（Mach-O universal x86_64+arm64, DTPlatformName=macosx）
签名: adhoc, spctl rejected（未公证，首次打开需右键）
启动: 正常，端口 127.0.0.1:17080 LISTEN
```

订阅导入三种方式全失败：

1. `hiddify://import/<base64(整份yaml)>` → "意外连接错误"
2. `hiddify://import/<base64(订阅URL)>` → HTTP 服务器日志显示 `GET /sub.yaml 200`（确实拉到了），但界面报"添加配置文件失败：意外连接错误"
3. 文件选择器导入 → 同上报错

另有持续报错：

```
[ERROR] [infra.HiddifyCoreService] FormatException:
        Unexpected extension byte (at offset 0)
[ERROR] [boot.bootstrap] [system tray] error initializing
```

推测是 5.5.5 在 macOS 26 上的兼容问题。未继续深挖，因为 mihomo 已验证可用。
