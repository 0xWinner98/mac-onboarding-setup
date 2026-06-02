---
created: 2026-06-02 17:01:09 +0800
summary: 航海家 6/6 大课 AI 工具一键部署脚本说明 | 学员下载运行、排错、授权指引
last_change: 2026-06-03 00:51:00 +0800 — 加 Codex 审查的远程执行风险提示（给分发者）
---

# 航海家 · AI 工具一键部署助手

给 6/6 大课的零基础新手用：一个脚本，自动检测 / 安装 / 带你登录大课要用的工具。

## 一句话用法（Mac）

1. 打开「终端」App（按 `⌘ + 空格`，输入「终端」回车）
2. 粘贴下面这行命令，回车：
   ```
   curl -fsSL https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/install.sh | bash
   ```
3. 跟着中文提示走：回车=继续，`s`=跳过某个，`q`=退出
4. 结束后**重开一个终端窗口**，验证是否都能用

> 只想先看自己缺哪些、不装任何东西：命令末尾加 `| bash -s -- --check`

## 一句话用法（Windows）

1. 在开始菜单搜「PowerShell」打开（建议用 **Windows PowerShell** 或 **终端**）
2. 粘贴下面这行，回车（这个写法确保中文不乱码）：
   ```
   irm https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/go.ps1 | iex
   ```
3. 跟着中文提示走：回车=继续，`s`=跳过，`q`=退出
4. 结束后**重开一个 PowerShell 窗口**验证

> 只想先检测不安装：先跑 `$env:CHECK_ONLY=1`，再跑上面那行
> Windows 几乎所有工具都能自动装（winget + 官方安装器，且都不需要 WSL）；唯一 Mac 独有的「Claude Cowork（让 Claude 操作电脑）」Windows 暂时没有，不影响大课。

## 它会装什么

| 工具 | 作用 | 安装方式（全官方） |
|---|---|---|
| Claude Code | 大课主力 AI 编程助手 | 官方脚本，native 二进制，无需 Node |
| Codex | OpenAI 的 AI 编程终端 | 官方脚本，无需 Node |
| Hermes | 能成长的 AI 助手 | 官方脚本，仅需 Git，自动装其余依赖 |
| 飞书 CLI | 让 AI 读写飞书表格 / 文档 | npm（需要 Node，脚本会帮你处理） |
| Obsidian | AI 第二大脑 / 知识库 | 图形软件，脚本打开官网带你下载 |

**不需要先装 Homebrew。** 三个命令行工具都是各家官方独立脚本，依赖最少。

## 授权 / 登录

脚本第二步会一个个带你登录。**脚本不碰你的任何密码**，全部由你在官方页面自己完成：

- Codex → 用 ChatGPT 账号登录
- 飞书 CLI → 扫码 / 浏览器授权
- Hermes → 跟着 `hermes setup` 向导走
- Claude Code → **官方订阅**直接登录；**怕封号 / 没订阅 / 网络进不去**就选「中转」，脚本带你装 CC Switch（中转地址和密钥找小组长拿）

## 常见问题

**Q：粘贴命令后没反应 / 报错？**
确认在「终端」里粘贴了完整一行（`curl` 开头）。网络不好多试一次。某个工具安装时若弹"无法验证开发者"，到「系统设置 → 隐私与安全性」点「仍要打开」。

**Q：装完输 `claude` / `codex` 提示 command not found？**
关掉当前终端，**重新开一个窗口**再试（新装的命令要新窗口才生效）。

**Q：某个工具安装失败？**
多半是网络。把那几行红色 ❌ 截图发小组长。可以重跑脚本，已装好的会自动跳过。

**Q：飞书 CLI 说缺 Node？**
脚本会引导：有 Homebrew 就自动装；没有就带你去 nodejs.org 下载 LTS 版双击装，装完重跑脚本。

## 文件清单

- `install.sh` —— Mac 主脚本（学员用 curl 运行）
- `install.ps1` —— Windows 主脚本（学员用 PowerShell 运行）
- `README.md` —— 本说明
- `组长速查.md` —— 给小组长：盯人、发中转、验证
- `直播大纲.md` —— 分享直播的逐段大纲

## 给分发者 / 维护者

- **学员命令（Mac）**：`curl -fsSL https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/install.sh | bash`
- **学员命令（Windows）**：见上方「一句话用法（Windows）」的 PowerShell 一行命令（PowerShell 跑 `install.ps1`）
- **发布仓库**：https://github.com/0xWinner98/mac-onboarding-setup （公开）。发布副本在 `/Users/kk/mac-onboarding-release/`，改 install.sh 后在该目录 `git commit -am '...' && git push` 更新，raw 链接不变（约 5 分钟 CDN 缓存）。
- 脚本一律从各工具**官方源**安装，**不预置任何中转地址 / 密钥**（避免泄露和封号）。
- **远程执行风险（Codex 审查提示）**：`go.ps1` / `install.sh` 从 GitHub main 拉取并执行，未做 tag pin / hash 校验——课程期快速迭代可接受；若要加固，改指向固定 release tag + SHA256 校验，并确保仓库写权限受控（防分支被污染）。
- 中转走 CC Switch（学员自己装 + 组长私发中转配置），脚本只负责"带你装上 CC Switch"。
- 各工具自带自动更新；本脚本如需改安装命令，直接编辑对应 `do_xxx` 函数即可。
- 安装命令出处见下方来源，升级前可比对官方是否变更。

### 安装命令来源

- Claude Code：`https://code.claude.com/docs/en/setup`（native：`curl -fsSL https://claude.ai/install.sh | bash`）
- Codex：`https://github.com/openai/codex`（`curl -fsSL https://chatgpt.com/codex/install.sh | sh`）
- Hermes：`https://hermes-agent.nousresearch.com/docs/getting-started/installation`
- 飞书 CLI：`npm install -g @larksuite/cli`
- CC Switch：`https://github.com/farion1231/cc-switch`
