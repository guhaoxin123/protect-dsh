# DSH 守护 (dsh-guard)

AxManager 插件（plugin）：给 `io.github.jackwener.dsh` 做**后台保活 / 掉线自愈**。
进程被杀 → 按冷却时间自动拉起；可选端口探活判断"掉线"。

## 装法
1. AxManager → 安装模块 → 选 `dsh-guard-1.1.0.zip`
   - 必须走 AxManager 的插件安装器：`module.prop` 里 `axeronPlugin=1` 就是它认的标志位
2. 打开插件界面 → 点「系统放行」 → 点「启动守护」
3. 验证：最近任务划掉 DSH，等一个间隔（默认 8s），它会自己回来

## 装到哪
AxManager 把插件解到 `/data/adb/axeron/plugins/dsh-guard`，
并在点击动作时于模块根目录执行 `sh ./action.sh`。

## 目录
```
module.prop        插件信息（含 axeronPlugin=1）
action.sh          根级入口，转发给 run/action.sh（AxManager 点的就是它）
run/action.sh      全部动作实现，也是 WebUI 后端
watchdog.sh        守护主循环
common/config.sh   公共函数 + 默认配置
webroot/index.html 控制台
service.sh         开机钩子（AxManager 无此钩子时不会自动跑，需手点一次）
uninstall.sh       卸载清理
```

## 配置（<模块>/data/config 或 /data/local/tmp/dsh-guard/config）
| 键 | 默认 | 说明 |
|---|---|---|
| enabled | 1 | 1 开 / 0 暂停 |
| interval | 8 | 检查间隔秒 |
| cooldown | 45 | 两次拉起最小间隔秒 |
| boot_delay | 15 | 启动后延迟开始检查 |
| port_check | 0 | 1 = 同时做端口探活 |
| port | 0 | 探活端口 |
| launch_mode | auto | auto / am / monkey |

## 命令行
```sh
sh action.sh status
sh action.sh selftest
sh action.sh start | stop | restart
sh action.sh launch        # 立即拉起一次
sh action.sh optimize      # 电池白名单 / appops / standby
sh action.sh set interval 10
sh action.sh log 80
```
