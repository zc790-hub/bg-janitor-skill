---
name: bg-janitor
description: 后台清道夫：盘点并清理"GUI 已关、后台进程却一直在跑"的孤儿/僵尸进程（WorkBuddy、Codex、TRAE、Cursor 等 AI 工具最爱堆这种），以及会自动复活的开机自启代理。触发词：清进程、清后台、后台清理、杀僵尸、清僵尸进程、清孤儿进程、后台还有啥在跑、有什么没用还在跑的、关不掉的进程、电脑卡查后台、bg-janitor、process cleanup。用户说"后台是不是有一堆没用的""帮我清一下进程""怎么关不干净"时也应触发。
---

# 后台清道夫（bg-janitor）

## 这个 skill 解决什么

很多 AI 工具（WorkBuddy / Codex / TRAE / Cursor 这类 Electron + 沙箱架构）有个通病：**关掉窗口后，它后台拉起的子进程不被回收**，被过继给 launchd（PPID=1）一直空转，越积越多，几天就能攒出几十个、几百 MB。用户感觉"关不掉、越来越卡"。本 skill 负责定期盘点并安全清掉它们。

## 执行流程

### 1. 扫描（只读）
```bash
bash ~/.claude/skills/bg-janitor/scan.sh
```
输出三块：①已知工具的孤儿进程（GUI 已关但后台还在）②会自动复活的自启代理 ③内存 Top 12。

### 2. 给用户一张分档报告
按"该不该清"分三档呈现，**不要直接全杀**：
- 🔴 **孤儿，建议清**：GUI 已关闭 + 后台还有进程 = 纯僵尸，清掉无副作用（下次正常打开 App 会重新拉起）。
- 🟡 **会自动复活的自启代理**：杀进程没用，会被 launchd 立刻拉回来。要真停得 `launchctl unload -w`。**先问用户还用不用那个工具**，再决定停不停。
- 🟢 **留着别动**：在用的 App（看 GUI 是否运行 + CPU 是否活跃）、系统/大厂更新器（Google keystone、Edge updater、Steam）、当前这个 Claude 会话本身。

> 🔴 **CHECKPOINT · 🛑 STOP**：报告给完，**必须等用户点头**再杀。用户没确认要清哪些档之前，不准执行任何 kill / unload。停自启代理（🟡）前还要单独确认"这个工具你还用吗"。

### 3. 确认后再清。三个失败模式 fallback 表（实战踩出来的，对照执行）：

| 症状（触发条件） | 一线修复 | 仍失败兜底 |
|---|---|---|
| `kill -9` 发了进程数纹丝不动（`sandbox-cli` 等受 macOS 沙箱保护，沙箱内 Bash 信号到不了）| **Bash 工具 `dangerouslyDisableSandbox=true` 重发** | 仍在 → 该进程可能被 SIP/系统保护，报告用户手动在活动监视器强制退出 |
| zsh 报 `illegal pid: 90687\n86550...`（多行 PID 被当字面量 `\n`）| **改用 `xargs` 传 PID**，别用 `kill -9 $PIDS` | 见下方命令模板 |
| 进程杀完几秒又复活（`~/Library/LaunchAgents/*.plist` 里 KeepAlive 的自启代理，如 `com.workbuddy.gemini-proxy`、`ai.openclaw.gateway`）| **先 `launchctl unload -w` 再 kill**，`-w` 写 disabled 重启也不自启 | unload 报 "Could not find specified service" → 该代理已不在，忽略；恢复用 `launchctl load -w <同一路径>` |

xargs 正确写法（zsh 下唯一安全姿势）：
```bash
ps aux | grep -E "<匹配串>" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
```

### 4. 清理参考命令（确认后，Bash 带 dangerouslyDisableSandbox=true 执行）
```bash
# Codex 孤儿
ps aux | grep -iE "Codex.app|\.codex/computer-use|\.local/bin/codex" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
# TRAE 孤儿
ps aux | grep "TRAE SOLO" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
# WorkBuddy 全家（sandbox-cli/网关/代理/browser）
ps aux | grep -E "WorkBuddy.app|sandbox-cli|openclaw.*gateway|gemini_proxy.py|\.workbuddy/binaries.*agent-browser" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
```

### 5. 复核 + 汇报
重新数一遍残留、确认自启代理几秒后没复活、报清掉的进程数和省下的内存。

## 已知会堆僵尸的工具（scan.sh 里维护这张表）
- **WorkBuddy**：`sandbox-cli`（每 session 一个，最爱堆）、`openclaw gateway`(占 18789 端口)、`gemini_proxy.py`、`agent-browser`。后两个有自启代理会复活。
- **Codex**：`~/.local/bin/codex` 根进程下挂一堆 `node_repl` + `codex` + `.codex/computer-use` 的 SkyComputerUseClient。
- **TRAE SOLO CN**：ai-agent helper + crashpad 残留。
- **Cursor**：Helper 残留（占位，按需扩展）。
新发现别的工具堆僵尸，往 `scan.sh` 的 `known()` 表里加一行 `名字|GUI主进程特征|后台匹配串1|匹配串2`。

## 边界（别做的事）
- 不碰系统进程、系统/大厂更新器、输入法。
- 不碰 GUI 正在运行或 CPU 活跃的 App（那是在用）。
- 不碰当前 Claude / claude-code 会话进程。
- 浏览器（Chrome/Edge）是否关由用户定，只提示不自动杀。
- 停自启代理前先问用户还用不用那个工具。
