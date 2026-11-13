#!/system/bin/sh
# 开机/服务拉起入口（AxManager 目前无此钩子，留着给其它管理器/手动调用）
MODDIR=$(cd "$(dirname "$0")" && pwd)
MODDIR="$MODDIR" sh "$MODDIR/run/action.sh" start
