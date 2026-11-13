#!/system/bin/sh
# DSH Guard 守护循环：进程掉了 / 端口不通 → 按冷却时间拉起
self_dir=$(cd "$(dirname "$0")" && pwd)
MODDIR="$self_dir"
. "$self_dir/common/config.sh"
load_conf

trap 'log "收到停止信号，守护退出"; rm -f "$PIDF"; exit 0' TERM INT

echo $$ > "$PIDF"
log "守护启动 pid=$$ 间隔=${interval}s 冷却=${cooldown}s"

[ "${boot_delay:-0}" -gt 0 ] 2>/dev/null && sleep "$boot_delay"

last_launch=0
fails=0

while :; do
  load_conf
  if [ "${enabled:-1}" != "1" ]; then
    sleep 3
    continue
  fi

  now=$(date +%s)
  alive=0
  dsh_alive && alive=1

  need=0
  reason=""
  if [ "$alive" = "0" ]; then
    need=1; reason="进程不存在"
  elif ! port_ok; then
    need=1; reason="端口 ${port} 不通"
  fi

  if [ "$need" = "1" ]; then
    fails=$((fails + 1))
    if [ $((now - last_launch)) -ge "${cooldown:-45}" ]; then
      last_launch=$now
      log "需要拉起（$reason，连续 ${fails} 次），执行 launch_dsh"
      if launch_dsh; then
        sleep 3
        if dsh_alive; then log "拉起成功"; fails=0; else log "拉起命令已执行但进程仍未出现"; fi
      else
        log "拉起失败（am/monkey 都返回非 0）"
      fi
    else
      log "需要拉起（$reason），冷却中 $((cooldown - (now - last_launch)))s"
    fi
  else
    [ "$fails" -gt 0 ] && log "已恢复，进程在跑"; fails=0
  fi

  printf 'ts=%s\nalive=%s\nfails=%s\nlast=%s\nreason=%s\n' "$now" "$alive" "$fails" "$last_launch" "$reason" > "$STATEF" 2>/dev/null

  # 分片 sleep，方便及时响应停止
  i=0
  while [ "$i" -lt "${interval:-8}" ]; do
    sleep 1
    i=$((i + 1))
    [ -f "$PIDF" ] || exit 0
  done
done
