#!/bin/bash
# 把本目录的文件安装到位（换机器或重装时用）
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
PLIST_DST="$HOME/Library/LaunchAgents/com.user.mihomo.plist"

echo "== 1. 安装脚本到 ~/.local/bin =="
mkdir -p "$HOME/.local/bin"
for f in proxy-on proxy-off proxy-disable proxy-check proxy-fast mihomo-boot; do
    cp "$SRC/scripts/$f" "$HOME/.local/bin/$f"
    chmod 755 "$HOME/.local/bin/$f"
    echo "   $f"
done

echo "== 2. 安装内核配置 =="
mkdir -p "$HOME/.config/mihomo"
if [ ! -f "$HOME/.config/mihomo/config.yaml" ]; then
    cp "$SRC/config.example.yaml" "$HOME/.config/mihomo/config.yaml"
    echo "   config.example.yaml → config.yaml（含示例节点，需替换成真实节点才会通）"
else
    echo "   config.yaml 已存在，跳过（如需覆盖请手动 cp）"
fi

echo "== 3. 安装开机自启 =="
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__HOME__|$HOME|g" "$SRC/launchagents/com.user.mihomo.plist.template" > "$PLIST_DST"
plutil -lint "$PLIST_DST"

# launchctl 按 Label 注册，不受 HOME 隔离。
# 若在隔离 HOME 里跑（测试场景），装载会污染真实用户的同名服务，必须跳过。
if ! grep -q "$HOME/.local/bin/mihomo-boot" "$PLIST_DST"; then
    echo "   ⚠️  plist 里的路径与当前 HOME 不符，跳过 launchctl（避免污染真实服务）"
elif [ "$(launchctl print "gui/$(id -u)/com.user.mihomo" 2>/dev/null | grep -c 'path =' || true)" != "0" ] \
     && ! launchctl print "gui/$(id -u)/com.user.mihomo" 2>/dev/null | grep -q "path = $PLIST_DST"; then
    echo "   ⚠️  已有同名服务登记在其它路径，跳过（先 launchctl unload 再重装）"
else
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    launchctl load -w "$PLIST_DST"
    echo "   已装载"
fi

echo
echo "完成。检查状态：proxy-on"
echo "注意：内核 $HOME/.local/bin/mihomo 不在此目录，需单独下载（见 README）"
