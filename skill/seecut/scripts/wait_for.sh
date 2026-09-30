#!/bin/zsh
# 标准等待：等某个后台任务的日志里出现完成标记。执行窗的一切等待都用它，禁止手写 until/while 循环。
# 用法: zsh wait_for.sh <日志文件> <完成标记(ASCII)> <超时秒> [失败标记(ASCII，可选)]
# 退出码: 0=等到完成标记  1=超时  2=参数错误  3=等到失败标记
# 为什么要它（2026-10-01 Round2-4.4 实测）：执行窗手写 `until grep -q "锚5" 输出; do sleep 20; done`，
#   输出里中文被显示成 ???、永远匹配不上，又没设超时，空转约 10 小时；同会话还读到过上一轮的旧日志误以为出结果。
LOG="$1"; DONE="$2"; T="$3"; FAIL="$4"
[ -z "$LOG" -o -z "$DONE" -o -z "$T" ] && { print "用法: wait_for.sh <日志> <完成标记> <超时秒> [失败标记]"; exit 2; }
print -r -- "$DONE$FAIL" | LC_ALL=C grep -q '[^ -~]' && { print "❌ 标记只能用 ASCII（中文在日志里可能被显示成 ???，永远匹配不上）"; exit 2; }
[[ "$T" == <-> ]] || { print "❌ 超时必须是正整数秒"; exit 2; }
# 只认启动之后新写的内容：记下起始字节数，旧日志里的标记不算（防读到上一轮结果）
START=$([ -f "$LOG" ] && wc -c < "$LOG" | tr -d ' ' || echo 0)
t0=$SECONDS
while (( SECONDS - t0 < T )); do
  if [ -f "$LOG" ]; then
    NEW=$(tail -c +$((START + 1)) "$LOG" 2>/dev/null)
    [ -n "$FAIL" ] && print -r -- "$NEW" | grep -qF -- "$FAIL" && { print "⛔ 等到失败标记「$FAIL」（$((SECONDS - t0))s）：$LOG"; exit 3; }
    print -r -- "$NEW" | grep -qF -- "$DONE" && { print "✓ 等到「$DONE」（$((SECONDS - t0))s）：$LOG"; exit 0; }
  fi
  sleep 5
done
print "⏰ 超时 ${T}s 没等到「$DONE」：$LOG（去看日志末尾，别再手写循环接着等）"; exit 1
