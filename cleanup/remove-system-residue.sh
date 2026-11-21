#!/bin/bash
# 清理 VPN Super 与 ProtonVPN 的系统级残留（需 sudo）
# 2026-11-21
set -u

echo "== 1. 删除 VPN Super 应用（root 拥有）=="
APP="/Applications/VPN Super.app"
if [ -d "$APP" ]; then
    echo "   目标: $APP"
    rm -rf "$APP"
    if [ -d "$APP" ]; then
        echo "   ❌ 仍存在"
    else
        echo "   ✅ 已删除"
    fi
else
    echo "   已不存在"
fi

echo
echo "== 2. 系统 VPN 配置 =="
SVC_NAME="VPN Super - OpenVPN"
echo "   当前网络服务："
networksetup -listallnetworkservices 2>/dev/null | sed 's/^/     /'
echo
# macOS 不允许命令行删除 VPN 类型网络服务，这里尝试并如实报告
if networksetup -removenetworkservice "$SVC_NAME" 2>/dev/null; then
    echo "   ✅ 已移除"
else
    echo "   ⚠️  命令行无法移除（macOS 限制），请手动操作："
    echo "      系统设置 → 网络 → 选中「${SVC_NAME}」→ 点列表下方「−」"
fi
echo
echo "   结果："
scutil --nc list 2>/dev/null | sed 's/^/     /'

echo
echo "== 3. ProtonVPN 系统扩展 =="
EXTS="ch.protonvpn.mac.WireGuard-Extension ch.protonvpn.mac.Transparent-Proxy"
SIP_ON=0
csrutil status 2>/dev/null | grep -q "status: enabled" && SIP_ON=1

if [ "$SIP_ON" = "1" ]; then
    echo "   ⚠️  SIP 已开启，systemextensionsctl uninstall 不可用，请手动操作："
    echo "      系统设置 → 通用 → 登录项与扩展 → 网络扩展"
    echo "      关闭或移除 Proton VPN WireGuard / Proton VPN Split Tunneling"
else
    for ext in $EXTS; do
        echo "   卸载 $ext"
        systemextensionsctl uninstall J6S6Q257EK "$ext" 2>&1 | sed 's/^/     /'
    done
fi

echo
echo "   当前 ProtonVPN 扩展："
systemextensionsctl list 2>/dev/null | grep -i proton | sed 's/^/     /' || echo "     ✅ 已无"

echo
echo "== 完成 =="
