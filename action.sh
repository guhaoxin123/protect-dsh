#!/system/bin/sh
# AxManager 会在模块根目录执行本文件：转发到真正的实现
here=$(cd "$(dirname "$0")" && pwd)
exec sh "$here/run/action.sh" "$@"
