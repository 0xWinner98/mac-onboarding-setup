#!/bin/bash
# ============================================================
#   航海家 · AI 工具一键部署助手 (macOS)
#   检测 → 安装 → 授权，全程中文引导，给零基础新手用
#
#   工具：Claude Code / Codex / Hermes / 飞书CLI / Obsidian
#   安装方式：一律各家官方脚本，零 Homebrew 依赖，脚本内不含任何密钥
#
#   用法（任选其一）：
#     一键运行：  curl -fsSL <你的链接>/install.sh | bash
#     只检测：    curl -fsSL <你的链接>/install.sh | bash -s -- --check
#     本地运行：  bash install.sh   /   bash install.sh --check
# ============================================================

# 失败不中断：不开 set -e；不开 set -u（新手环境变量可能未定义）

# ---------- 颜色与输出 ----------
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YLW=$'\033[33m'; BLU=$'\033[34m'; CYN=$'\033[36m'; RST=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; CYN=""; RST=""
fi
hr(){ printf '%s\n' "────────────────────────────────────────────"; }
say(){ printf '%s\n' "$*"; }
ok(){ printf "${GRN}✅ %s${RST}\n" "$*"; }
warn(){ printf "${YLW}⚠️  %s${RST}\n" "$*"; }
err(){ printf "${RED}❌ %s${RST}\n" "$*"; }
step(){ printf "\n${BOLD}${BLU}▶ %s${RST}\n" "$*"; }

# ---------- 工具函数 ----------
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

# 检测 Xcode 命令行工具(CLT)是否真装好。macOS 的 git 是 CLT 的占位命令——
# 没装 CLT 时 command -v git 也成功，但真跑 git 会报 xcrun error。必须实跑校验。
clt_ok(){ xcode-select -p >/dev/null 2>&1 && git --version >/dev/null 2>&1; }

# Node 是否真可用：node 和 npm 都得能跑（飞书 CLI 要 npm，光有 node 不够）
node_ok(){ node -v >/dev/null 2>&1 && npm -v >/dev/null 2>&1; }

# 是否所有必备工具都已装齐（全装齐就恭喜跳过，不再走安装流程）
all_installed(){ { claude --version >/dev/null 2>&1 || [ -d "/Applications/Claude.app" ]; } && codex --version >/dev/null 2>&1 && hermes --version >/dev/null 2>&1 && lark-cli --version >/dev/null 2>&1 && node_ok && [ -d /Applications/Obsidian.app ]; }

# 把 ~/.local/bin 加入当前会话 PATH（官方脚本多装到这里）
ensure_local_bin(){
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
}

# 询问：回车=继续 / s=跳过(返回1) / q=退出整个脚本
# 通过 curl | bash 运行时，stdin 是脚本本身，这里显式从 /dev/tty 读键盘
ask_continue(){
  local prompt="$1" ans
  printf "${CYN}%s${RST} ${DIM}[回车=继续 / s=跳过 / q=退出]${RST}: " "$prompt"
  IFS= read -r ans </dev/tty || ans=""
  case "$ans" in
    s|S) return 1 ;;
    q|Q) say ""; say "已退出。随时可以重新运行，已装好的会自动跳过。"; exit 0 ;;
    *) return 0 ;;
  esac
}

# ---------- 环境检测（芯片 / macOS 版本）----------
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then CHIP="Apple 芯片（M 系列）"; else CHIP="Intel 芯片"; fi
MACOS_VER=$(sw_vers -productVersion 2>/dev/null)
MACOS_MAJOR=$(printf '%s' "$MACOS_VER" | cut -d. -f1)

# ---------- 状态记录 ----------
INSTALLED=(); SKIPPED=(); FAILED=()

# ---------- 网络检测（这些工具的源都在国外，得先能连上）----------
check_network(){
  hr; say "${BOLD}先检查网络${RST}（AI 工具的源大多在国外，连不上就装不了）"; hr
  local gh="" gg=""
  curl -fsS -m 8 -o /dev/null "https://github.com" 2>/dev/null && gh=1
  curl -fsS -m 8 -o /dev/null "https://www.google.com" 2>/dev/null && gg=1
  [ -n "$gh" ] && ok "GitHub 可访问" || err "GitHub 连不上"
  [ -n "$gg" ] && ok "Google 可访问" || err "Google 连不上"
  if [ -z "$gh" ] || [ -z "$gg" ]; then
    warn "你的网络连不上 GitHub / Google——这台电脑当前装不了这些工具（不是脚本的问题，是网络）。"
    say "  ${DIM}请先科学上网（确认浏览器能打开 github.com 和 google.com）再回来跑本脚本。${RST}"
    ask_continue "知道了，仍要继续试？（多半会失败）" || { say "好的，弄通网络再来。"; exit 0; }
  fi
}

# ---------- 检测清单 ----------
detect(){
  hr; say "${BOLD}先看看你这台电脑现在的安装情况${RST}"; hr
  say "  ${DIM}本机：$CHIP / macOS $MACOS_VER${RST}"
  say "${DIM}  命令行工具(CLI)=终端里用、功能最全；桌面 App=图形界面、更直观。两者不冲突、可以都装。${RST}"
  say "${BOLD}  ▸ 命令行工具（CLI）${RST}"
  has_cmd claude   && ok "Claude Code (CLI) —— $(claude --version 2>/dev/null | head -1)"   || err "Claude Code (CLI) —— 未装"
  has_cmd codex    && ok "Codex (CLI) —— $(codex --version 2>/dev/null | head -1)"          || err "Codex (CLI) —— 未装"
  has_cmd hermes   && ok "Hermes (CLI) —— $(hermes --version 2>/dev/null | head -1)"        || err "Hermes (CLI) —— 未装"
  has_cmd lark-cli && ok "飞书 CLI —— $(lark-cli --version 2>/dev/null | head -1)"          || err "飞书 CLI —— 未装"
  say "${BOLD}  ▸ 桌面 App / 知识库${RST}"
  [ -d /Applications/Obsidian.app ] && ok "Obsidian —— 已装" || err "Obsidian —— 未装"
  [ -d "/Applications/Claude.app" ] && ok "Claude 桌面 App —— 已装" || say "  ◦ Claude 桌面 App —— 未装（可选，图形界面）"
  ls -d /Applications/Codex*.app >/dev/null 2>&1 && ok "Codex 桌面 App —— 已装" || say "  ◦ Codex 桌面 App —— 未装（可选，Apple 芯片 / Intel 都有官方版本）"
  if [ -n "$MACOS_MAJOR" ] && [ "$MACOS_MAJOR" -lt 13 ]; then
    warn "你的 macOS 偏旧（<13）：命令行 Claude Code 装不了，会引导你改用 Claude 桌面 App。"
  fi
  if [ -n "$MACOS_MAJOR" ] && [ "$MACOS_MAJOR" -lt 12 ]; then
    warn "你的 macOS <12：命令行 Codex 可能装不了（官方要 12+）——可改用 Codex 桌面 App（Apple / Intel 都有版本）或 Obsidian 的 Claudian 插件。"
  fi
  say "${DIM}  ── 下面是依赖，不用单独管 ──${RST}"
  node_ok && ok "Node.js / npm —— $(node -v)" || warn "Node.js / npm —— 没装好（装飞书 CLI 时自动装）"
  clt_ok && ok "开发者命令行工具 / Git —— 已就绪" || warn "开发者命令行工具(CLT) —— 没装好（git 跑不起来；装 Hermes 前会引导 xcode-select --install）"
}

# ---------- 工作区（知识库文件夹）----------
setup_workspace(){
  step "先建一个工作区（你的知识库文件夹）"
  say "给一个${BOLD}固定的文件夹${RST}放知识库 + AI 工作区，以后 Obsidian 和 AI 都在这里干活——选个你以后不会乱动的位置。"
  local default="$HOME/Documents/Workspace"
  say "  ${DIM}直接回车用默认：$default${RST}"
  say "  ${DIM}或粘贴你想要的完整路径（绝对路径，例如 $HOME/AI工作区）：${RST}"
  printf "${CYN}工作区路径：${RST} "
  local inp; IFS= read -r inp </dev/tty || inp=""
  [ -z "$inp" ] && WORKSPACE="$default" || WORKSPACE="$inp"
  mkdir -p "$WORKSPACE" 2>/dev/null && cd "$WORKSPACE" 2>/dev/null
  ok "工作区：$WORKSPACE（已进入，后面装的工具都以这里为工作目录）"
}

# ---------- 基础底座前置安装（CLT / Node，后面各工具都依赖）----------
ensure_base_deps(){
  hr; say "${BOLD}先把基础底座装好${RST}（git / Node 这些是后面工具的地基，缺了会装不上）"; hr
  # 1) Xcode 命令行工具：提供 git + 编译环境（Hermes 等必需）
  if clt_ok; then
    ok "开发者命令行工具 / git —— 已就绪"
  else
    warn "缺「Xcode 命令行工具」（git / Hermes 都要用）。马上弹一个系统窗口，请点【安装】。"
    say "  ${DIM}它要联网下载、约几分钟。点了【安装】就别关窗口，脚本会等它装完自动继续。${RST}"
    xcode-select --install 2>/dev/null || true
    local waited=0
    printf "  ${DIM}等待安装中"
    while ! clt_ok; do
      sleep 8; waited=$((waited+8)); printf "."
      if [ "$waited" -ge 600 ]; then
        printf "${RST}\n"; err "等了 10 分钟还没装好（可能没点【安装】或网络慢）。"
        say "  ${DIM}装完 CLT 后重跑本脚本即可；或现在先跳过（Hermes 这步会失败）。${RST}"
        FAILED+=("Xcode 命令行工具（装完后重跑脚本）")
        warn "先跳过 Xcode 工具，继续装其它（只有 Hermes 受影响；装完 CLT 重跑即可）。"
        return
      fi
    done
    printf "${RST}\n"; ok "Xcode 命令行工具已就绪，git 可用了"; INSTALLED+=("Xcode 命令行工具")
  fi
  # 2) Node.js：提供 npm（飞书 CLI 必需）
  if node_ok; then
    ok "Node.js / npm —— 已就绪（$(node -v)）"
  else
    say "${DIM}装 Node.js（官方包，免 brew、免密码）……${RST}"
    if install_node && node_ok; then INSTALLED+=("Node.js"); else warn "Node 没装好（多半网络）；飞书 CLI 那步会再试，仍不行就装完 Node 重跑。"; FAILED+=("Node.js（飞书 CLI 依赖）"); fi
  fi
  # Python 不用单独装——Hermes 官方脚本会用 uv 自动装 Python 3.11
}

# ---------- 各工具安装 ----------
do_claude(){
  step "Claude Code —— 大课主力 AI 助手（命令行）"
  if has_cmd claude; then ok "已安装：$(claude --version 2>/dev/null | head -1)"; SKIPPED+=("Claude Code"); return; fi
  if [ -n "$MACOS_MAJOR" ] && [ "$MACOS_MAJOR" -lt 13 ]; then
    warn "你的 macOS 是 $MACOS_VER（偏旧）。命令行 Claude Code 需要 macOS 13+，你的系统装不上（会崩 _ubrk_clone）。"
    say "  ${DIM}两条路：1) 能更新系统就升到 macOS 13+，命令行用最新版（也能体验最新 AI 功能）；2) 不想更新，用 Claude 桌面客户端（后面会引导，M 芯片功能最全）。${RST}"
    SKIPPED+=("Claude Code 命令行（macOS 旧 → 用客户端 / 或升级系统）"); return
  fi
  ask_continue "现在安装 Claude Code（命令行）？" || { SKIPPED+=("Claude Code"); return; }
  say "${DIM}正在下载安装，可能 1-2 分钟，请耐心等、别关窗口……${RST}"
  local cc_script; cc_script=$(curl -fsSL https://claude.ai/install.sh 2>/dev/null)
  if printf '%s' "$cc_script" | grep -qiE 'just a moment|cf_chl|challenge-platform|<html'; then
    err "Claude Code 下载被 Cloudflare 拦了（返回人机验证页，不是脚本）——这不是网络不通。"
    say "  ${DIM}是 claude.ai 前面的 Cloudflare 把你这个 IP 判成可疑了（跟机房/住宅无关，是这个具体 IP 的信誉评分）。解决：换个节点/IP 再跑（换机场节点、或开手机热点；住宅 IP 通常最稳），或授权那步选「中转」走 CC Switch。${RST}"
    FAILED+=("Claude Code（被 Cloudflare 拦 → 换住宅 IP 或走中转）"); return
  fi
  printf '%s' "$cc_script" | bash 2>&1 | tee /tmp/cc_install.log
  ensure_local_bin
  if has_cmd claude; then
    ok "Claude Code 安装成功：$(claude --version 2>/dev/null | head -1)"; INSTALLED+=("Claude Code")
  elif grep -q "_ubrk_clone\|Symbol not found\|Abort trap" /tmp/cc_install.log 2>/dev/null; then
    err "Claude Code 和你的 macOS 版本不兼容（这不是网络问题）。"
    say "  ${DIM}解决：把 macOS 升到 13+ 再用命令行；或不升级、直接用后面引导的 Claude 桌面客户端（M 芯片功能最全）。${RST}"
    FAILED+=("Claude Code（macOS 旧 → 用桌面客户端 / 或升级到 13+）")
  else
    warn "装完了但暂时没认到命令（结束后重开终端再试 claude --version）。"; INSTALLED+=("Claude Code（需重开终端确认）")
  fi
}

do_codex(){
  step "Codex —— OpenAI 的 AI 终端（命令行）"
  if has_cmd codex; then ok "已安装：$(codex --version 2>/dev/null | head -1)"; SKIPPED+=("Codex"); return; fi
  if [ -n "$MACOS_MAJOR" ] && [ "$MACOS_MAJOR" -lt 12 ]; then
    warn "你的 macOS 是 $MACOS_VER（<12）。命令行 Codex 官方要求 macOS 12+，装不了。"
    say "  ${DIM}两条路：1) 升级 macOS 到 12+；2) 用 Codex 桌面 App（有 Apple / Intel 版，后面会引导）。${RST}"
    SKIPPED+=("Codex 命令行（macOS <12 → 用 Codex App / 或升级）"); return
  fi
  say "将运行官方安装脚本（不需要 Node）："
  say "  ${DIM}curl -fsSL https://chatgpt.com/codex/install.sh | sh${RST}"
  ask_continue "现在安装 Codex？" || { SKIPPED+=("Codex"); return; }
  say "${DIM}正在下载安装，可能 1-2 分钟，请耐心等、别关窗口……${RST}"
  if curl -fsSL https://chatgpt.com/codex/install.sh | sh; then
    ensure_local_bin
    if has_cmd codex; then ok "Codex 安装成功：$(codex --version 2>/dev/null | head -1)"; INSTALLED+=("Codex")
    else warn "装好了，但当前窗口还没刷新命令（结束后重开终端即可）"; INSTALLED+=("Codex（需重开终端）"); fi
  else err "Codex 安装失败（多半是网络）。稍后重试，或截图发到群里。"; FAILED+=("Codex"); fi
}

do_hermes(){
  step "Hermes Agent —— 能成长的 AI 助手"
  if has_cmd hermes; then ok "已安装：$(hermes --version 2>/dev/null | head -1)"; SKIPPED+=("Hermes"); return; fi
  if ! clt_ok; then
    warn "命令行 Hermes 需要 Xcode 命令行工具，你这台还没装好。"
    say "  ${DIM}更省事：直接装 Hermes 桌面 App（自带运行环境、不用 CLT），后面「图形界面」步骤会引导你装；想用命令行版就先把 Xcode 工具装好再重跑脚本。${RST}"
    SKIPPED+=("Hermes 命令行（缺 CLT → 改用桌面 App / 或装 CLT 重跑）"); return
  fi
  say "将运行官方安装脚本（仅需 Git，会自动装 Python / Node 等依赖，耗时几分钟）："
  say "  ${DIM}curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash${RST}"
  ask_continue "现在安装 Hermes？" || { SKIPPED+=("Hermes"); return; }
  say "${DIM}正在装 Hermes：会下 uv / Python / Node 等依赖（连 astral.sh / GitHub / PyPI 等国外源），正常首次 5-15 分钟。${RST}"
  say "${DIM}中途看到「Trying tier: all」「Resolved N packages」「uv.lock sync failed」都正常，别关窗口。${RST}"
  say "${YLW}但卡在某一步（如 Installing managed uv）超过 10 分钟完全不动 = 网络/Cloudflare 拦了下载：按 Ctrl+C 中断，先跳过 Hermes（Claude Code/Codex 是主力、够用），换干净网络/IP 再单独装。${RST}"
  if curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash; then
    ensure_local_bin
    if has_cmd hermes; then ok "Hermes 安装成功：$(hermes --version 2>/dev/null | head -1)"; INSTALLED+=("Hermes")
    else warn "装好了，但当前窗口还没刷新命令（结束后重开终端即可）"; INSTALLED+=("Hermes（需重开终端）"); fi
  else err "Hermes 安装失败。稍后重试，或截图发到群里。"; FAILED+=("Hermes"); fi
}

# ---------- Node.js 自动安装（官方包，免 brew/密码/浏览器）----------
install_node(){
  node_ok && return 0
  local a ver url dir
  [ "$ARCH" = "arm64" ] && a="darwin-arm64" || a="darwin-x64"
  ver=$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null | grep -o '"version":"v[0-9.]*"' | head -1 | grep -o 'v[0-9.]*')
  [ -z "$ver" ] && ver="v22.11.0"
  url="https://nodejs.org/dist/$ver/node-$ver-$a.tar.gz"
  say "${DIM}下载 Node $ver（官方包，免 brew、免密码）……${RST}"
  curl -fsSL "$url" -o /tmp/node.tar.gz 2>/dev/null && [ -s /tmp/node.tar.gz ] || return 1
  mkdir -p "$HOME/.local"
  tar -xzf /tmp/node.tar.gz -C "$HOME/.local" 2>/dev/null || { rm -f /tmp/node.tar.gz; return 1; }
  rm -f /tmp/node.tar.gz
  dir="$HOME/.local/node-$ver-$a/bin"
  export PATH="$dir:$PATH"
  local rc="$HOME/.zshrc"; [ "$(basename "${SHELL:-/bin/zsh}")" = "bash" ] && rc="$HOME/.bash_profile"
  grep -q "node-$ver-$a/bin" "$rc" 2>/dev/null || printf '\nexport PATH="%s:$PATH"  # 航海家脚本：Node\n' "$dir" >> "$rc"
  has_cmd node && { ok "Node 安装成功：$(node -v)"; return 0; }
  return 1
}

do_larkcli(){
  step "飞书 CLI —— 让 AI 直接读写你的飞书表格 / 文档"
  if has_cmd lark-cli; then ok "已安装：$(lark-cli --version 2>/dev/null | head -1)"; SKIPPED+=("飞书 CLI"); return; fi
  if ! node_ok; then
    warn "飞书 CLI 需要 Node.js，没检测到，正在自动装（免 brew、免密码）……"
    if ! install_node; then
      err "Node 自动安装失败——多半是网络连不上 nodejs.org（前面连 chatgpt / astral 也失败，就是网络不通）。"
      say "  ${DIM}先把网络弄通（科学上网）再重跑；或到 ${RST}${CYN}https://nodejs.org/zh-cn/download${RST}${DIM} 手动下 LTS 双击装。${RST}"
      SKIPPED+=("飞书 CLI（缺 Node，自动装失败/网络）"); return
    fi
  fi
  say "将通过 npm 安装：${DIM}npm install -g @larksuite/cli${RST}"
  ask_continue "现在安装飞书 CLI？" || { SKIPPED+=("飞书 CLI"); return; }
  if npm install -g @larksuite/cli; then
    if has_cmd lark-cli; then ok "飞书 CLI 安装成功：$(lark-cli --version 2>/dev/null | head -1)"; INSTALLED+=("飞书 CLI")
    else warn "装好了，但当前窗口还没刷新命令（结束后重开终端即可）"; INSTALLED+=("飞书 CLI（需重开终端）"); fi
  else err "飞书 CLI 安装失败（可能是 npm 权限）。截图发到群里。"; FAILED+=("飞书 CLI"); fi
}

do_obsidian(){
  step "Obsidian —— 你的 AI 第二大脑 / 知识库（核心）"
  if [ -d "/Applications/Obsidian.app" ]; then ok "已安装 /Applications/Obsidian.app"; SKIPPED+=("Obsidian"); return; fi
  ask_continue "现在安装 Obsidian（核心知识库）？" || { SKIPPED+=("Obsidian"); return; }
  # 下载官方 universal dmg 自动安装
  say "下载 Obsidian 安装包（约几十 MB，稍等）..."
  local url tmp vol
  url=$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null | grep -o 'https://[^"]*universal\.dmg' | head -1)
  tmp="/tmp/Obsidian-installer.dmg"
  if [ -n "$url" ] && curl -fsSL "$url" -o "$tmp" 2>/dev/null; then
    vol=$(hdiutil attach "$tmp" -nobrowse 2>/dev/null | grep -o '/Volumes/.*' | head -1)
    if [ -n "$vol" ] && [ -d "$vol/Obsidian.app" ]; then
      cp -R "$vol/Obsidian.app" /Applications/ 2>/dev/null && { ok "Obsidian 安装成功"; INSTALLED+=("Obsidian"); }
      hdiutil detach "$vol" >/dev/null 2>&1; rm -f "$tmp"
      [ -d /Applications/Obsidian.app ] && return
    fi
    [ -n "$vol" ] && hdiutil detach "$vol" >/dev/null 2>&1; rm -f "$tmp"
  fi
  # 兜底：手动下载页
  warn "自动安装没成功（多半网络），请手动下载：双击 .dmg 把图标拖进 Applications"
  say "  ${CYN}https://obsidian.md/download${RST}"
  has_cmd open && open "https://obsidian.md/download" 2>/dev/null
  FAILED+=("Obsidian（请手动装）")
}

# ---------- CC Switch（中转管理，仅在用户选「中转」时调用）----------
install_ccswitch(){
  if [ -d "/Applications/CC Switch.app" ] || [ -d "/Applications/cc-switch.app" ]; then
    ok "CC Switch 已安装"; open -a "CC Switch" 2>/dev/null || open -a "cc-switch" 2>/dev/null; return
  fi
  say "${BOLD}帮你自动下载安装 CC Switch${RST}（一键管理中转，Claude Code / Codex / Hermes 的中转都在它里面配）"
  local api url tmp vol app
  api=$(curl -fsSL https://api.github.com/repos/farion1231/cc-switch/releases/latest 2>/dev/null)
  if [ "$ARCH" = "arm64" ]; then
    url=$(printf '%s' "$api" | grep -o 'https://[^"]*\.dmg' | grep -iE 'aarch64|arm64' | head -1)
  else
    url=$(printf '%s' "$api" | grep -o 'https://[^"]*\.dmg' | grep -iE 'x64|x86_64|intel' | head -1)
  fi
  [ -z "$url" ] && url=$(printf '%s' "$api" | grep -o 'https://[^"]*\.dmg' | head -1)
  tmp="/tmp/CCSwitch-installer.dmg"
  if [ -n "$url" ]; then
    say "${DIM}正在下载 CC Switch（官方 GitHub 版，几十 MB）……${RST}"
    if curl -fsSL "$url" -o "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      vol=$(hdiutil attach "$tmp" -nobrowse 2>/dev/null | grep -o '/Volumes/.*' | head -1)
      app=$(ls -d "$vol"/*.app 2>/dev/null | head -1)
      [ -n "$app" ] && cp -R "$app" /Applications/ 2>/dev/null && ok "CC Switch 安装成功"
      [ -n "$vol" ] && hdiutil detach "$vol" >/dev/null 2>&1
      rm -f "$tmp"
    fi
  fi
  if [ -d "/Applications/CC Switch.app" ] || [ -d "/Applications/cc-switch.app" ]; then
    # 清隔离属性，尽量让首次打开不被拦
    xattr -dr com.apple.quarantine "/Applications/CC Switch.app" 2>/dev/null
    xattr -dr com.apple.quarantine "/Applications/cc-switch.app" 2>/dev/null
    say "  ${YLW}重要 —— 第一次打开如果弹「无法验证开发者」别慌${RST}：这是 macOS 对所有网上下载软件的默认拦截，不是病毒。"
    say "  ${BOLD}解决（点一下就行）${RST}：到「${BOLD}系统设置 → 隐私与安全性${RST}」，往下翻到「已阻止 CC Switch」那行，点右边「${BOLD}仍要打开${RST}」→ 再确认一次「打开」即可。"
    say "  ${DIM}正在帮你打开 CC Switch……${RST}"
    open -a "CC Switch" 2>/dev/null || open -a "cc-switch" 2>/dev/null
  else
    warn "自动安装没成功（多半网络），帮你打开下载页手动装（下载 .dmg → 双击 → 把图标拖进 Applications）："
    say "  ${CYN}https://github.com/farion1231/cc-switch/releases/latest${RST}"
    has_cmd open && open "https://github.com/farion1231/cc-switch/releases/latest" 2>/dev/null
  fi
}

# ---------- 授权 / 登录 ----------
auth_phase(){
  hr; say "${BOLD}第二步：一个个带你登录 / 授权${RST}"; hr
  say "每个工具会打开浏览器或问你几个问题，跟着走就行。"
  say "${DIM}脚本不碰你的任何密码，所有登录都是你在官方页面自己完成。${RST}"

  if has_cmd codex; then
    step "1) 登录 Codex（用你的 ChatGPT 账号）"
    say "即将运行 ${DIM}codex login${RST}，会打开浏览器。"
    ask_continue "现在登录 Codex？" && { codex login </dev/tty || warn "登录没完成，稍后可手动运行 codex login"; }
  fi

  if has_cmd lark-cli; then
    step "2) 配置并授权 飞书 CLI"
    say "先初始化，再扫码 / 浏览器授权。"
    ask_continue "现在配置飞书 CLI？" && { lark-cli config init </dev/tty; lark-cli auth login </dev/tty || warn "授权没完成，稍后可手动运行 lark-cli auth login"; }
  fi

  if has_cmd hermes; then
    step "3) Hermes —— 装好就行，先不用配"
    ok "Hermes 命令行已就绪（hermes --version 能看到版本就成）。"
    say "  ${DIM}今晚不用急着选模型 / 订阅——那一步等你了解后再弄，免得不懂时误操作。${RST}"
    say "  要用中转的话：和 Claude Code / Codex 一样，在 ${BOLD}CC Switch${RST} 里点右上角「新建」，新建一个 provider 填中转地址和密钥即可（不想敲命令行也能配 Hermes）。"
  fi

  if has_cmd claude; then
    step "4) Claude Code 登录（重点）"
    say "Claude Code 登录是最容易卡住的一步。先问你三个问题，帮你选对路、少走弯路。"
    echo
    say "${BOLD}问题 1：你有官方付费账号吗？${RST}（Claude Pro / Max；ChatGPT 账号用来登 Codex）"
    say "  ${DIM}为什么问：没有官方账号就没法走官方登录，只能用第三方中转。${RST}"
    say "    1 = 有        2 = 没有"
    printf "${CYN}输入 1 或 2：${RST} "; local q1; IFS= read -r q1 </dev/tty || q1="1"
    echo
    say "${BOLD}问题 2：这个账号被封过、或你担心被封吗？${RST}"
    say "  ${DIM}为什么问：账号被封过的话，再用官方登录很容易又被封；很多同学会改用中转更稳妥。${RST}"
    say "    1 = 没事 / 不担心      2 = 被封过 / 担心"
    printf "${CYN}输入 1 或 2：${RST} "; local q2; IFS= read -r q2 </dev/tty || q2="1"
    echo
    local suggest="官方账号登录"
    if [ "$q1" = "2" ] || [ "$q2" = "2" ]; then suggest="第三方中转"; fi
    say "  ${DIM}根据你的回答，建议你用：${RST}${BOLD}$suggest${RST}"
    [ "$q1" = "2" ] && say "  ${DIM}（你没有官方账号，官方登录走不通，所以建议中转）${RST}"
    [ "$q1" != "2" ] && [ "$q2" = "2" ] && say "  ${DIM}（账号被封过 / 担心被封，用中转不拿正式账号冒险）${RST}"
    echo
    say "${BOLD}问题 3：那这次你用哪种？${RST}"
    say "    1 = 官方账号直接登录"
    say "    2 = 用第三方中转（${BOLD}CC Switch 一键配置${RST}，不怕封）"
    printf "${CYN}输入 1 或 2：${RST} "; local q3; IFS= read -r q3 </dev/tty || q3="1"
    echo
    if [ "$q3" = "2" ]; then
      say "好的，用${BOLD}第三方中转${RST} —— ${BOLD}CC Switch 一键配置${RST}。下面帮你自动下载官方版本并安装："
      install_ccswitch
      say "  ${BOLD}配置（在打开的 CC Switch 里）${RST}：点右上角「${BOLD}新建${RST}」→ 填中转地址和密钥 → 选中 → 应用。"
      say "  ${DIM}中转地址和密钥自己去这两个靠谱的中转站注册、充值一些先试用（充一两百够用很久）：${RST}"
      say "    ${CYN}https://aigocode.com/invite/ATR5EXTD${RST}"
      say "    ${CYN}https://apikey.fun/register?aff=S46XYZ9AKRFM${RST}"
      say "  ${DIM}配好后 Claude Code / Codex / Hermes 都走这个中转。脚本不预置密钥（避免泄露和封号）。${RST}"
    else
      say "即将运行 ${DIM}claude${RST}，会打开浏览器走官方登录；登录后在里面输入 /exit 退出。"
      ask_continue "现在登录 Claude Code 官方？" && { claude </dev/tty || warn "登录没完成，稍后可手动运行 claude"; }
    fi
  fi
}

# ---------- 图形界面：Claudian 插件 + 桌面客户端 ----------
do_clients(){
  step "图形界面：Claudian 插件 + 桌面客户端（按你的芯片）"

  # 1) Claudian 插件——所有芯片都能用：在 Obsidian 里图形化用 Codex / Claude Code
  say "${BOLD}1) 在 Obsidian 里装 Claudian 插件${RST}（强烈推荐，所有芯片 / 系统都能用）"
  say "  它让你在 Obsidian 界面里直接用 Claude Code / Codex（侧边栏聊天、选中改写），${BOLD}体验很接近 Codex 桌面 app${RST}。"
  say "  装法：打开 Obsidian → 设置 → 第三方插件（社区插件）→ 搜 ${BOLD}Claudian${RST} → 安装并启用 → 插件里选 Claude 或 Codex。"
  has_cmd open && { ask_continue "现在打开 Obsidian 去装 Claudian？" && open -a Obsidian 2>/dev/null || true; }

  # 2) Claude 桌面客户端——官方只在网页下载（Intel / Apple 芯片都能装，macOS 11+）
  echo
  if [ -d "/Applications/Claude.app" ]; then
    ok "Claude 桌面客户端已安装"
  else
    say "${BOLD}2) Claude 桌面客户端${RST}（图形界面，Intel / Apple 芯片都能装）——官方只在网页下载"
    if ask_continue "打开 Claude 客户端下载页？（下载后把图标拖进 Applications）"; then
      has_cmd open && open "https://claude.com/download" 2>/dev/null
      say "  在打开的页面下载 macOS 版 → 双击 .dmg → 拖进 Applications。"
    fi
  fi

  # 3) Codex 桌面 App——Apple Silicon 和 Intel 都有官方版本
  echo
  if ls -d /Applications/Codex*.app >/dev/null 2>&1; then
    ok "Codex 桌面 App 已安装"
  else
    local cxbuild="Apple Silicon 版"; [ "$ARCH" != "arm64" ] && cxbuild="Intel 版"
    say "${BOLD}3) Codex 桌面 App${RST}（图形界面，Apple 芯片和 Intel 都有官方版本）"
    say "  你的电脑是 $CHIP，到下载页选 ${BOLD}$cxbuild${RST}，下载后拖进 Applications。"
    ask_continue "打开 Codex App 下载页？（需 ChatGPT 账号）" && { has_cmd open && open "https://developers.openai.com/codex/app" 2>/dev/null; }
    say "  ${DIM}（不想装 App 也行：命令行 Codex 或 Obsidian 的 Claudian 插件一样能用 Codex）${RST}"
  fi

  # 4) Hermes 桌面 App —— CLI 的图形外壳，比命令行友好
  echo
  say "${BOLD}4) Hermes 桌面 App${RST}（图形界面，比命令行友好；和命令行 Hermes 共享同一份配置）"
  if [ -d "/Applications/Hermes.app" ]; then
    ok "Hermes 桌面 App 已安装"
  elif has_cmd hermes; then
    say "  你已装命令行 Hermes，${BOLD}最省事${RST}：用官方命令 ${BOLD}hermes desktop${RST} 自动构建并打开桌面 App（首次几分钟）。"
    if ask_continue "现在后台构建并打开 Hermes 桌面 App？（后台跑、不打断后面流程，几分钟后 App 自动打开）"; then
      nohup hermes desktop >/tmp/hermes-desktop-build.log 2>&1 &
      ok "已在后台开始构建 Hermes 桌面 App（几分钟后自动打开；日志 /tmp/hermes-desktop-build.log，没反应可去 https://hermes-agent.nousresearch.com/desktop 下安装包）。"
    fi
  else
    if ask_continue "下载并打开 Hermes 桌面 App 安装包？"; then
      local dmg="/tmp/Hermes-Setup.dmg"
      say "${DIM}正在下载（官方源，约 7MB）……${RST}"
      if curl -fSL -o "$dmg" "https://hermes-assets.nousresearch.com/Hermes-Setup.dmg" 2>/dev/null && [ -s "$dmg" ]; then
        open "$dmg" 2>/dev/null
        say "  ${DIM}在弹出的窗口里，把 Hermes 图标拖进「应用程序」就装好了。${RST}"
      else
        warn "下载没成功（多半网络），可手动下载：https://hermes-agent.nousresearch.com/desktop"
      fi
    fi
  fi
}

# ---------- 小结 ----------
summary(){
  hr; say "${BOLD}安装小结${RST}"; hr
  if [ ${#INSTALLED[@]} -gt 0 ]; then ok "本次新装好："; for x in "${INSTALLED[@]}"; do say "    • $x"; done; fi
  if [ ${#SKIPPED[@]}  -gt 0 ]; then say "${DIM}⏭  跳过 / 本来就有：${RST}"; for x in "${SKIPPED[@]}"; do say "    • $x"; done; fi
  if [ ${#FAILED[@]}   -gt 0 ]; then err "还没搞定（需处理）："; for x in "${FAILED[@]}"; do say "    • $x"; done
    say "  ${YLW}把上面这几行截图发到群里，会帮你看。${RST}"; fi
}

# ---------- 主流程 ----------
banner(){
  say "${BOLD}════════════════════════════════════════════${RST}"
  say "${BOLD}   航海家 · AI 工具一键部署助手${RST}"
  say "${BOLD}════════════════════════════════════════════${RST}"
}

main(){
  ensure_local_bin
  if [ "${1:-}" = "--check" ]; then banner; check_network; detect; echo; say "（这是只检测模式，没有安装任何东西）"; exit 0; fi

  # curl | bash 运行时仍需交互授权，必须有可用的终端
  if [ ! -r /dev/tty ]; then
    banner
    err "需要在「终端」窗口里运行（脚本要带你登录授权）。"
    say "请打开「终端」App，把那行 curl 命令粘贴进去执行。"
    say "${DIM}只想检测不安装：在 curl 命令末尾加  ${RST}${BOLD}| bash -s -- --check${RST}"
    exit 1
  fi

  clear 2>/dev/null
  banner
  say "这个脚本帮你检测、安装、并带你登录 6/6 大课要用的工具。"
  say "工具都从${BOLD}各家官方源${RST}下载，脚本里不含任何密钥。"
  say "按提示${BOLD}回车${RST}即可；不想装某个就输 ${BOLD}s${RST} 跳过；想退出输 ${BOLD}q${RST}。"
  say "${DIM}脚本不会动你的密码，所有登录都在官方页面由你自己完成。${RST}"
  check_network
  detect
  if all_installed; then
    hr; ok "${BOLD}恭喜！大课要用的工具你已经全部装好了 🎉${RST}"
    say "  ${DIM}各工具自带自动更新（claude / codex / hermes 下次启动会自己更新；飞书 CLI 可跑 npm update -g @larksuite/cli）。${RST}"
    echo
    ask_continue "直接进入登录 / 授权？（已装好的不用重装）" && auth_phase
    hr; ok "全部就绪，祝大课顺利 🚀"; exit 0
  fi
  hr; say "${BOLD}第一步：逐个检查并安装${RST}"; hr
  ask_continue "开始安装流程？" || { say "好的，下次再来。已装好的不会重复装。"; exit 0; }

  setup_workspace
  ensure_base_deps
  do_claude
  do_codex
  do_hermes
  do_larkcli
  do_obsidian
  do_clients
  summary

  echo
  ask_continue "进入第二步：登录授权？" && auth_phase

  hr; ok "全部流程结束！"
  say "建议：${BOLD}关掉这个终端窗口，重新开一个${RST}，粘贴下面这行确认都能用："
  say "  ${DIM}claude --version; codex --version; hermes --version; lark-cli --version${RST}"
  say "任何一个报错，截图发到群里。祝大课顺利 🚀"
}

main "$@"
