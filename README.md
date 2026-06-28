# 后台清道夫 (bg-janitor-skill)

**中文** | [English](#english)

一个 [Claude Code](https://claude.com/claude-code) / Agent Skill。盘点并清理那些 **GUI 已经关掉、后台进程却一直在跑** 的孤儿 / 僵尸进程：WorkBuddy、Codex、TRAE、Cursor 这类 Electron + 沙箱架构的 AI 工具最爱堆这种，以及会"杀了又自动复活"的开机自启代理。

它不是一个无脑 `killall` 脚本。它先只读盘点、把进程分成「该清 / 要确认 / 别动」三档给你看，**确认后才动手**，并把几个实战踩过的坑（沙箱进程杀不动、zsh 杀多进程语法、自启代理复活）编码进了流程。

> ⚠️ **免责声明 / Disclaimer**
> 本工具只清理"主程序已退出后残留的后台进程"，不碰系统进程、更新器、输入法，也不碰正在运行中的应用。清进程前请确认对应 App 确实不在用。脚本默认面向 macOS（`launchctl` / `ps` / `pgrep`）。

## 它怎么干活

1. **只读盘点**：跑 `scan.sh`，列出已知工具的孤儿进程（GUI 关了但后台还在）、会自动复活的自启代理、内存占用 Top 12。
2. **分档报告**：🔴 孤儿建议清 / 🟡 自启代理要确认 / 🟢 在用或系统的别动。
3. **确认后清理**：用户点头才执行，自启代理单独再确认一次。
4. **复核**：重新数残留、确认自启代理没复活、报清掉多少进程和内存。

## 核心设计（三个实战坑）

- **沙箱进程要绕沙箱杀**：`sandbox-cli` 这类受 macOS 沙箱保护的进程，普通 `kill -9` 信号到不了，必须在不受沙箱限制的环境下重发。
- **zsh 杀多进程用 `xargs`**：`kill -9 $PIDS` 在 zsh 下会把多行 PID 当字面量报 `illegal pid`，一律 `... | awk '{print $2}' | xargs kill -9`。
- **自启代理要 `unload` 不是 `kill`**：`~/Library/LaunchAgents` 里 KeepAlive 的代理杀完秒复活，要 `launchctl unload -w` 才真停，恢复用 `launchctl load -w`。

## 一段真实示例

> 下面是这个 skill 第一次实跑的节录（也是它的诞生场景）。

```
用户：怎么感觉我后台关闭不了 workbuddy，你看看呢

清道夫：WorkBuddy 的 App 主进程其实已经退出了，但走的时候没回收子进程，
留下一堆孤儿：
  · sandbox-cli      35 个（每开一个 session 拉一个，最老的跑了 10 天）
  · openclaw gateway  1 个（还占着 18789 端口）
  · gemini_proxy      1 个
合计约 50 个进程、270MB，几乎全是 0% CPU 空转。

第一遍 kill -9 杀不动：这些是沙箱保护进程，普通 Bash 的信号到不了它们。
换不受沙箱限制的方式重发 + 用 xargs 传 PID，全部归零。
gateway / gemini_proxy 杀完会被开机自启代理拉回来，已 launchctl unload -w 永久停。
```

后续同一台机器还揪出 Codex（38 进程、22 天没退、GUI 没开）和一个累计吃了 **50 小时 CPU** 的无头自动化 Chrome，一并清掉，共省约 500MB。

## 适合谁

- 装了多个 AI 编程 / Agent 工具（WorkBuddy、Codex、Cursor、TRAE…）、感觉"关了 App 还是越来越卡"的人
- 想知道"后台到底有什么没用还在跑、是不是它们在耗电"的人

## 怎么用

把整个 `bg-janitor/` 目录放进你的 skills 目录，然后直接说：

- "清一下后台进程"
- "后台是不是有一堆没用的还在跑"
- "怎么关不干净"

## 目录结构

```
bg-janitor/
├── SKILL.md      # 流程：盘点 → 分档 → 确认 → 清理 → 复核
├── scan.sh       # 只读盘点脚本（不杀任何东西）
├── LICENSE
└── README.md
```

## 诚实与边界

- 默认面向 macOS；`scan.sh` 的已知工具表（WorkBuddy / Codex / TRAE / Cursor）是按作者本机环境维护的，换台机器可能要往 `known()` 表加几行。
- "孤儿进程"的判断是启发式的（GUI 主进程不在 + 后台进程还在），不保证 100% 准确，所以流程坚持"先盘点、后确认、再清"。
- 它解决的是工具自己不回收子进程的副作用，不是替代你正常退出应用。

## 致谢（Acknowledgments）

由 zc790-hub 与 [Claude Code](https://claude.com/claude-code) 在一次真实的"关不掉 WorkBuddy"排查中协作做出，并用 [darwin-skill](https://github.com/alchaincyf/darwin-skill) 做过一轮质量进化。

## License

[MIT](./LICENSE) · Copyright (c) 2026 zc790-hub

---

## English

[↑ 中文](#后台清道夫-bg-janitor-skill)

A [Claude Code](https://claude.com/claude-code) / Agent Skill. It inventories and cleans up **orphaned / zombie background processes that keep running after the GUI is already closed**: the kind that Electron + sandbox AI tools (WorkBuddy, Codex, TRAE, Cursor) love to pile up, plus login agents that respawn the moment you kill them.

It is not a blind `killall` script. It scans read-only first, sorts processes into three buckets (clean / confirm / leave alone) for you to review, **acts only after you say go**, and encodes a few battle-tested gotchas (sandbox-protected processes can't be killed normally, zsh multi-PID kill syntax, respawning login agents) into the workflow.

> ⚠️ **Disclaimer**
> This tool only cleans up background processes left over after a main app has quit. It never touches system processes, updaters, or input methods, nor any running app. Confirm the app is actually unused before cleaning. Scripts target macOS (`launchctl` / `ps` / `pgrep`).

### How it works

1. **Read-only scan**: `scan.sh` lists orphaned processes of known tools (GUI closed but background still alive), respawning login agents, and top-12 memory hogs.
2. **Bucketed report**: 🔴 orphans to clean / 🟡 login agents to confirm / 🟢 in-use or system, leave alone.
3. **Clean after confirmation**: only on your go-ahead; login agents get a separate confirmation.
4. **Re-check**: recount leftovers, confirm agents didn't respawn, report how many processes and how much memory were freed.

### Core design (three real-world gotchas)

- **Sandbox processes need a non-sandboxed kill**: `sandbox-cli`-type processes are sandbox-protected; a normal `kill -9` signal can't reach them and must be re-sent from an unsandboxed context.
- **Use `xargs` to kill many PIDs in zsh**: `kill -9 $PIDS` throws `illegal pid` in zsh because multi-line PIDs are taken literally; always `... | awk '{print $2}' | xargs kill -9`.
- **Login agents need `unload`, not `kill`**: KeepAlive agents in `~/Library/LaunchAgents` respawn instantly after a kill; `launchctl unload -w` truly stops them, `launchctl load -w` restores them.

### A real example

> An excerpt from this skill's very first run, the scenario that created it.

```
User: I feel like I can't actually close WorkBuddy in the background, take a look?

Janitor: WorkBuddy's main app process had already quit, but it left its child
processes unreaped on the way out:
  · sandbox-cli      35 (one per session; the oldest had run for 10 days)
  · openclaw gateway  1 (still holding port 18789)
  · gemini_proxy      1
~50 processes, 270MB, nearly all idle at 0% CPU.

The first kill -9 did nothing: these are sandbox-protected; a normal Bash
signal couldn't reach them. Re-sent from an unsandboxed context + piped PIDs
through xargs → all gone. The gateway / gemini_proxy get respawned by login
agents, so launchctl unload -w stopped them for good.
```

On the same machine it later caught Codex (38 processes, 22 days, no GUI) and a headless automation Chrome that had burned **50 hours of CPU**, cleaned together, ~500MB freed.

### Who it's for

- Anyone running several AI coding / agent tools (WorkBuddy, Codex, Cursor, TRAE…) who feels the machine keeps slowing down even after closing the apps
- Anyone wondering "what useless stuff is actually running in the background, and is it draining my battery?"

### How to use

Drop the whole `bg-janitor/` folder into your skills directory, then say:

- "clean up my background processes"
- "is there a bunch of useless stuff still running in the background?"
- "why can't I close this cleanly?"

### Directory structure

```
bg-janitor/
├── SKILL.md      # workflow: scan → bucket → confirm → clean → re-check
├── scan.sh       # read-only inventory script (kills nothing)
├── LICENSE
└── README.md
```

### Honesty

- Targets macOS by default; the known-tools table in `scan.sh` (WorkBuddy / Codex / TRAE / Cursor) is maintained against the author's own machine, so other setups may need a few more rows in `known()`.
- "Orphan" detection is heuristic (main GUI absent + background processes alive), not 100% accurate, which is why the flow insists on scan-then-confirm-then-clean.
- It addresses the side effect of tools not reaping their own children; it is not a replacement for quitting apps properly.

### Acknowledgments

Built by zc790-hub together with [Claude Code](https://claude.com/claude-code) during a real "can't close WorkBuddy" debugging session, and put through one round of quality evolution with [darwin-skill](https://github.com/alchaincyf/darwin-skill).

### License

[MIT](./LICENSE) · Copyright (c) 2026 zc790-hub
