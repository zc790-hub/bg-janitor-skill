#!/usr/bin/env bash
# bg-janitor 扫描脚本：盘点"GUI 已关、后台却还在跑"的孤儿/僵尸进程
# 只读，不杀任何东西。输出给 Claude 判断用。
set -u

me="$(id -un)"

# ── 已知的 AI / 重型工具：name|GUI主进程特征|属于它的后台进程匹配串 ──
# GUI 主进程不在、但后台进程还在 = 孤儿，建议清
known() {
  cat <<'EOF'
WorkBuddy|WorkBuddy.app/Contents/MacOS/WorkBuddy|WorkBuddy.app|sandbox-cli|openclaw.*gateway|gemini_proxy.py|.workbuddy/binaries.*agent-browser|.agent-browser/browsers
Codex|Codex.app/Contents/MacOS/Codex|Codex.app/Contents/Resources|.codex/computer-use|.local/bin/codex
TRAE|TRAE SOLO CN.app/Contents/MacOS|TRAE SOLO
Cursor|Cursor.app/Contents/MacOS/Cursor|Cursor.app.*Helper
EOF
}

echo "================ bg-janitor 扫描报告 ================"
echo "时间: $(date '+%F %T')"
echo ""
echo "## 一、已知工具的孤儿进程（GUI 已关 / 后台残留）"
echo ""

total_orphan=0
total_mem=0
while IFS='|' read -r name gui rest; do
  [ -z "$name" ] && continue
  # GUI 主进程在不在
  if pgrep -f "$gui" >/dev/null 2>&1; then
    gui_state="运行中（不动）"
  else
    gui_state="已关闭"
  fi
  # 收集该工具所有后台进程匹配串
  IFS='|' read -ra pats <<< "$rest"
  pids=""
  for p in "${pats[@]}"; do
    [ -z "$p" ] && continue
    got="$(pgrep -f "$p" 2>/dev/null)"
    pids="$pids $got"
  done
  pids="$(echo $pids | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -u)"
  cnt=0; mem=0
  [ -n "$pids" ] && cnt=$(echo "$pids" | wc -l | tr -d ' ')
  if [ "$cnt" -gt 0 ]; then
    mem=$(ps -o rss= -p "$(echo $pids | tr ' ' ',')" 2>/dev/null | awk '{s+=$1} END{printf "%.0f", s/1024}')
    oldest=$(ps -o etime= -p "$(echo $pids | tr ' ' ',')" 2>/dev/null | sort | tail -1 | tr -d ' ')
  else
    oldest="-"
  fi
  flag=""
  [ "$gui_state" = "已关闭" ] && [ "$cnt" -gt 0 ] && { flag="  ← 🔴孤儿,建议清"; total_orphan=$((total_orphan+cnt)); total_mem=$((total_mem+mem)); }
  printf "  %-12s GUI:%-14s 后台进程:%3d  内存:%5s MB  最老:%s%s\n" \
    "$name" "$gui_state" "$cnt" "$mem" "$oldest" "$flag"
done < <(known)

echo ""
echo "  >>> 建议清理合计: ${total_orphan} 个进程, 约 ${total_mem} MB"
echo ""

echo "## 二、会自动复活的第三方自启代理 (~/Library/LaunchAgents)"
echo "    (杀进程没用,要 launchctl unload -w 才会真停)"
echo ""
shopt -s nullglob
found=0
for f in "$HOME"/Library/LaunchAgents/*.plist; do
  base="$(basename "$f")"
  # 跳过系统/大厂更新器
  case "$base" in
    com.google.*|com.microsoft.Edge*|com.apple.*|com.valvesoftware.*) continue ;;
  esac
  echo "  - $base"
  found=1
done
[ "$found" -eq 0 ] && echo "  (无值得关注的第三方自启代理)"
echo ""

echo "## 三、当前内存占用 Top 12（供你判断有没有开着没用的大块头）"
echo ""
ps aux -U "$me" 2>/dev/null | awk 'NR>1{printf "  %6.0f MB  %4s%%  %.70s\n", $6/1024, $3, substr($0,index($0,$11))}' \
  | sort -rn | head -12
echo ""
echo "===================================================="
echo "提示: 本脚本只读不杀。确认后由 Claude 执行清理。"
