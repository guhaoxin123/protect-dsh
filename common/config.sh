# DSH Guard 公共函数与默认配置
PKG="${PKG:-io.github.jackwener.dsh}"
MODDIR="${MODDIR:-/sdcard/dsh-guard}"   # 由调用脚本传入（模块根目录）

# 可写数据目录：优先模块目录，其次 /data/local/tmp，最后 /sdcard
pick_datadir() {
  for d in "$MODDIR/data" /data/local/tmp/dsh-guard /sdcard/.dsh-guard; do
    mkdir -p "$d" 2>/dev/null || continue
    if ( : > "$d/.wtest" ) 2>/dev/null; then rm -f "$d/.wtest"; echo "$d"; return 0; fi
  done
  echo "/data/local/tmp"
}
DATADIR="$(pick_datadir)"
CONF="$DATADIR/config"
LOG="$DATADIR/guard.log"
PIDF="$DATADIR/watchdog.pid"
STATEF="$DATADIR/state"

# 默认值
enabled=1
interval=8
boot_delay=15
cooldown=45
port_check=0
port=0
launch_mode=auto
quiet=1

load_conf() {
  enabled=1; interval=8; boot_delay=15; cooldown=45
  port_check=0; port=0; launch_mode=auto; quiet=1
  [ -f "$CONF" ] || return 0
  while IFS='=' read -r k v; do
    case "$k" in
      ''|\#*) continue ;;
      enabled|interval|boot_delay|cooldown|port_check|port|launch_mode|quiet)
        # 只接受安全字符，避免配置注入
        case "$v" in *[!A-Za-z0-9]*) continue ;; esac
        eval "$k=\$v" ;;
    esac
  done < "$CONF"
}
save_conf() {
  mkdir -p "$DATADIR" 2>/dev/null
  {
    echo "enabled=$enabled"
    echo "interval=$interval"
    echo "boot_delay=$boot_delay"
    echo "cooldown=$cooldown"
    echo "port_check=$port_check"
    echo "port=$port"
    echo "launch_mode=$launch_mode"
    echo "quiet=$quiet"
  } > "$CONF"
}

log() {
  mkdir -p "$DATADIR" 2>/dev/null
  printf '[%s] %s\n' "$(date '+%m-%d %H:%M:%S')" "$*" >> "$LOG" 2>/dev/null
  # 超过 200KB 截断
  sz=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  if [ "${sz:-0}" -gt 204800 ]; then
    tail -c 102400 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG" 2>/dev/null
  fi
}

# 进程是否存活（多路兜底；shell 身份下 pidof / dumpsys 可用）
dsh_alive() {
  pidof "$PKG" >/dev/null 2>&1 && return 0
  ps -A -o PID,NAME 2>/dev/null | grep -qw "$PKG" && return 0
  for p in /proc/[0-9]*; do
    case "$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)" in
      "$PKG"*|*/"$PKG"*) return 0 ;;
    esac
  done 2>/dev/null
  dumpsys activity processes 2>/dev/null | grep -q "ProcessRecord.*$PKG" && return 0
  return 1
}

# 是否被"强行停止"（stopped=true 会拦掉隐式启动）
dsh_stopped() {
  dumpsys package "$PKG" 2>/dev/null | grep -m1 -q "stopped=true"
}
# 端口健康检查（0 表示关闭）
port_ok() {
  [ "${port_check:-0}" = "1" ] || return 0
  [ "${port:-0}" -gt 0 ] 2>/dev/null || return 0
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 3 127.0.0.1 "$port" >/dev/null 2>&1 && return 0
  fi
  # 没有 nc 时用 /dev/tcp 思路不可用于 mksh，退化为 /proc 判断
  grep -q ":$(printf '%04X' "$port") " /proc/net/tcp 2>/dev/null && return 0
  return 1
}

# 屏幕是否亮着
screen_on() {
  st=$(dumpsys power 2>/dev/null | grep -m1 -E 'mWakefulness=|Display Power')
  case "$st" in
    *Awake*|*ON*) return 0 ;;
  esac
  return 1
}

# 拉起 DSH
launch_dsh() {
  case "${launch_mode:-auto}" in
    monkey) do_monkey; return $? ;;
    am)     do_am; return $? ;;
    *)
      do_am && return 0
      do_monkey
      return $?
      ;;
  esac
}

do_am() {
  act=$(cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -n1)
  case "$act" in
    */*) : ;;
    *) act="$PKG/.MainActivity" ;;
  esac
  am start -n "$act" >/dev/null 2>&1 && return 0
  am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$act" >/dev/null 2>&1
}

do_monkey() {
  monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

# 把模块位置写到固定路径，方便 WebUI 反查（模块目录可能各不相同）
mark_location() {
  mkdir -p /sdcard/.dsh-guard 2>/dev/null && printf '%s\n' "$MODDIR" > /sdcard/.dsh-guard/where 2>/dev/null
}
mark_location
