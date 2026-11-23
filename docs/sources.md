# 免费节点源清单

实测于 2026-11-23。节点源随时失效，用前先跑一次验证。

## 一、推荐源（按实用性排序）

### 1. freeclashnode —— 首选，每天更新

```
https://freeclashnode.com/uploads/YYYY/MM/YYYYMMDD.yaml
```

- 约 200 个节点：`vless` `ss` `trojan` `vmess`
- 地区偏向：香港、意大利、美国
- **每天一个文件，URL 里的日期要替换成当天**
- 实测今天 / 昨天 / 前天都可下载
- 质量相对整齐，高带宽节点多出自这里

### 2. sanfen —— 数量最大

```
https://ghfast.top/https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/sub_merge_yaml.yml
```

- 约 4600 个节点：`ss` 1917 / `vmess` 1798 / `trojan` 741
- 地区：美国 1455、新加坡 211、英国 199
- **必须走 `ghfast.top` 镜像**，GitHub 直连超时
- TCP 存活率约 27%（4257 去重后 1166 可达）
- 基数大但质量参差，适合大量筛选

### 3. ripao —— 亚洲节点最密集

```
https://ghfast.top/https://raw.githubusercontent.com/ripaojiedian/freenode/main/clash
```

- 只有约 24 个节点，但地区精准：新加坡 6、日本 5、香港 4、台湾 3
- 要低延迟（视频会议、游戏）优先试这个

### 4. v2cross —— 稳定小源

```
https://ghfast.top/https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/Eternity.yml
```

- 约 200 个：`ss` 168 / `vmess` 21 / `trojan` 12
- 地区：美国 47、英国 47、意大利 11
- 质量比 sanfen 整齐

### 5. ermao —— 协议最全

```
https://ghfast.top/https://raw.githubusercontent.com/ermaozi/get_subscribe/main/subscribe/clash.yml
```

- 约 426 个：`vless` 121 / `http` 87 / `ss` 82 / `hysteria2` 66
- 唯一含 `hysteria2` 的源，抗封锁能力较强
- ⚠️ 其中 87 个 `http` 类型需要认证，实测带宽全部为 0，**用前要剔除**

## 二、不可用（别浪费时间）

| 源 | 状态 |
|---|---|
| `raw.githubusercontent.com` 直连 | 全部超时（DNS 污染） |
| `aiboboxx/v2rayfree` | 404 |
| `Pawdroid/Free-servers` | 403 |
| `Barabama/FreeNodes` | 404 |
| `oneclickvirt/poornode` | 404 |
| `mfuu/v2ray` | 404 |
| `vpei/free-node` | 404 |
| `Flik6/getNode` | 空文件 |

## 三、GitHub 镜像可用性

```
ghfast.top          641 KB/s   ← 推荐
gh-proxy.com         96 KB/s
ghproxy.net          13 KB/s   太慢
github 直连          超时
ghfile.geekit.top    不通
gitdl.cn             不通
ghproxy.cc           不通
```

## 四、测速踩过的两个坑

### 坑 1：测速源本身会骗人

用 `https://speed.cloudflare.com/__down?bytes=10000000` 测速时，该 URL 后来稳定只返回 **1 字节**的假响应，导致所有节点都被判成 0 带宽。

**可用的测速源：**

```
http://cachefly.cachefly.net/10mb.test     ← 实测稳定 14.69 Mbps
```

其他测过但不稳定的：

| 源 | 实测 |
|---|---|
| `speed.cloudflare.com/__down` | 只回 1 字节 |
| `proof.ovh.net/files/10Mb.dat` | 0.41 Mbps（源本身慢） |
| `speed.hetzner.de/10MB.bin` | 0 字节 |
| `ipv4.download.thinkbroadband.com/10MB.zip` | 0.43 Mbps（源本身慢） |

### 坑 2：mihomo 的 url-test 不测带宽

`url-test` 组即使配置了 10MB 的文件 URL，也**只测首字节延迟就返回**，不会下载完整文件。

证据：history 里记录的延迟是 400-700ms。如果真下载 10MB 只用 0.5 秒，那是 160 Mbps，免费节点做不到。

后果：会出现「延迟 497ms 被选中，实际带宽 0.04 Mbps」的情况，差距 136 倍。

**想按带宽选，只能自己写脚本测**（见 `scripts/`）。

## 五、免费节点的本质限制

同一节点连续测得：

```
第1次:  8.38 Mbps
第2次:  1.95 Mbps
第3次:  0.44 Mbps
```

**波动 20 倍**。这是免费节点按需分配带宽的结果，任何配置策略都无法消除。

实用建议：

- 网页浏览、文档查阅：够用
- YouTube 720p：勉强可用
- 大文件下载、4K 视频：不建议
- 需要稳定带宽：只能付费订阅
