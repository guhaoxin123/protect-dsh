#!/system/bin/sh
# 卸载清理：停守护、删数据
MODDIR=$(cd "$(dirname "$0")" && pwd)
sh "$MODDIR/run/action.sh" stop >/dev/null 2>&1
rm -rf "$MODDIR/data" 2>/dev/null
rm -f /sdcard/.dsh-guard/where 2>/dev/null
rmdir /sdcard/.dsh-guard 2>/dev/null
echo "已清理 dsh-guard"
