#!/bin/bash
# 把本目录的文件安装到位（换机器或重装时用）
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"

echo "== 1. 安装脚本到 ~/.local/bin =="
mkdir -p "$HOME/.local/bin"
for f in proxy-on proxy-off proxy-disable proxy-check mihomo-boot; do
    cp "$SRC/scripts/$f" "$HOME/.local/bin/$f"
    chmod +x "$HOME/.local/bin/$f"
    echo "   $f"
done

echo "== 2. 安装内核配置 =="
mkdir -p "$HOME/.config/mihomo"
if [ ! -f "$HOME/.config/mihomo/config.yaml" ]; then
    cp "$SRC/config.yaml" "$HOME/.config/mihomo/config.yaml"
    echo "   config.yaml 已写入"
else
    echo "   config.yaml 已存在，跳过（如需覆盖请手动 cp）"
fi

echo "== 3. 安装开机自启 =="
mkdir -p "$HOME/Library/LaunchAgents"
cp "$SRC/launchagents/com.user.mihomo.plist" "$HOME/Library/LaunchAgents/"
plutil -lint "$HOME/Library/LaunchAgents/com.user.mihomo.plist"
launchctl unload "$HOME/Library/LaunchAgents/com.user.mihomo.plist" 2>/dev/null || true
launchctl load -w "$HOME/Library/LaunchAgents/com.user.mihomo.plist"
echo "   已装载"

echo
echo "完成。检查状态：proxy-on"
echo "注意：内核 $HOME/.local/bin/mihomo 不在此目录，需单独下载（见 README）"
