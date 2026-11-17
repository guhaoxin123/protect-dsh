#!/system/bin/sh
# AxManager 动作入口
# 用法: sh action.sh {start|stop|restart|status|launch|optimize|selftest|log [n]|clear|set k v|reset}
here=$(cd "$(dirname "$0")" && pwd)
moddir=$(cd "$here/.." && pwd)
MODDIR="$moddir"
. "$moddir/common/config.sh"
load_conf

running() {
  [ -f "$PIDF" ] || return 1
  p=$(cat "$PIDF" 2>/dev/null)
  [ -n "$p" ] || return 1
  kill -0 "$p" 2>/dev/null
}

start() {
  if running; then echo "已在运行 pid=$(cat "$PIDF")"; return 0; fi
  rm -f "$PIDF"
  setsid sh "$moddir/watchdog.sh" >>"$DATADIR/daemon.out" 2>&1 &
  sleep 1
  if running; then echo "守护已启动 pid=$(cat "$PIDF")"; else echo "守护启动失败，见 $DATADIR/daemon.out"; fi
}

stop() {
  if running; then
    p=$(cat "$PIDF")
    kill "$p" 2>/dev/null
    sleep 1
    kill -9 "$p" 2>/dev/null
    rm -f "$PIDF"
    echo "已停止守护"
  else
    rm -f "$PIDF"
    echo "守护未在运行"
  fi
  for pid in $(ps -A -o PID,NAME 2>/dev/null | grep -w "watchdog.sh" | awk '{print $1}'); do
    [ "$pid" != "$$" ] && kill -9 "$pid" 2>/dev/null
  done
}

status() {
  if running; then echo "guard=running"; else echo "guard=stopped"; fi
  echo "guard_pid=$(cat "$PIDF" 2>/dev/null)"
  echo "enabled=$enabled"
  echo "interval=$interval"
  echo "cooldown=$cooldown"
  echo "port_check=$port_check"
  echo "port=$port"
  echo "launch_mode=$launch_mode"
  echo "moddir=$MODDIR"
  echo "datadir=$DATADIR"
  if dsh_alive; then echo "dsh=alive"; else echo "dsh=dead"; fi
  echo "dsh_pid=$(pidof "$PKG" 2>/dev/null | tr ' ' ',')"
  if [ -f "$STATEF" ]; then
    echo "last_check=$(grep '^ts=' "$STATEF" 2>/dev/null | cut -d= -f2)"
    echo "fails=$(grep '^fails=' "$STATEF" 2>/dev/null | cut -d= -f2)"
  fi
}

optimize() {
  echo "—— 申请系统放行（需 shell 身份，被拒也无副作用）——"
  dumpsys deviceidle whitelist +"$PKG" 2>&1 | head -2
  cmd deviceidle whitelist +"$PKG" 2>&1 | head -2
  cmd appops set "$PKG" RUN_IN_BACKGROUND allow 2>&1 | head -2
  cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow 2>&1 | head -2
  am set-standby-bucket "$PKG" active 2>&1 | head -2
  am set-inactive "$PKG" false 2>&1 | head -2
  echo "—— 完成；出现 Permission Denial 说明当前不是 shell 身份 ——"
}

selftest() {
  echo "== 身份 =="
  echo "uid=$(id -u) user=$(id -un 2>/dev/null)"
  echo "== 能力 =="
  if p=$(pidof "$PKG" 2>/dev/null); then echo "pidof: ok ($(echo $p | tr ' ' ','))"; else echo "pidof: 未找到 DSH 进程"; fi
  if dumpsys activity processes >/dev/null 2>&1; then echo "dumpsys: ok"; else echo "dumpsys: 被拒"; fi
  if a=$(cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -n1); then echo "resolve-activity: $a"; else echo "resolve-activity: 被拒"; fi
  if dumpsys deviceidle whitelist >/dev/null 2>&1; then echo "deviceidle: ok"; else echo "deviceidle: 被拒"; fi
  if cmd appops get "$PKG" RUN_IN_BACKGROUND >/dev/null 2>&1; then echo "appops: ok"; else echo "appops: 被拒"; fi
  echo "== 判断 =="
  if dsh_alive; then echo "DSH 进程: 存活"; else echo "DSH 进程: 未存活（或不可见）"; fi
  if dsh_stopped; then echo "DSH 状态: 被强行停止(stopped=true)"; else echo "DSH 状态: 正常"; fi
  echo "== 目录 =="
  echo "MODDIR=$MODDIR"
  echo "DATADIR=$DATADIR"
}

case "${1:-status}" in
  start)    start ;;
  stop)     stop ;;
  restart)  stop; start ;;
  status)   status ;;
  launch)   if launch_dsh; then echo "已发起拉起"; else echo "拉起失败"; fi ;;
  optimize) optimize ;;
  selftest) selftest ;;
  log)      tail -n "${2:-60}" "$LOG" 2>/dev/null || echo "暂无日志" ;;
  clear)    : > "$LOG" 2>/dev/null; echo "日志已清空" ;;
  set)
    k="$2"; v="$3"
    case "$k" in
      enabled|interval|boot_delay|cooldown|port_check|port|quiet)
        case "$v" in ''|*[!0-9]*) echo "值必须是数字"; exit 1 ;; esac
        eval "$k=\$v" ;;
      launch_mode)
        case "$v" in am|monkey|auto) launch_mode="$v" ;; *) echo "launch_mode 只能是 am/monkey/auto"; exit 1 ;; esac ;;
      *) echo "未知配置项: $k"; exit 1 ;;
    esac
    save_conf
    echo "已设置 $k=$v"
    ;;
  reset)
    rm -f "$CONF"
    load_conf
    save_conf
    echo "配置已重置为默认"
    ;;
  *)
    echo "用法: sh action.sh {start|stop|restart|status|launch|optimize|selftest|log [n]|clear|set k v|reset}"
    ;;
esac
