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

# ---------- 状态记录 ----------
INSTALLED=(); SKIPPED=(); FAILED=()

# ---------- 检测清单 ----------
detect(){
  hr; say "${BOLD}先看看你这台电脑现在的安装情况${RST}"; hr
  has_cmd claude   && ok "Claude Code —— $(claude --version 2>/dev/null | head -1)"   || err "Claude Code —— 未安装"
  has_cmd codex    && ok "Codex —— $(codex --version 2>/dev/null | head -1)"          || err "Codex —— 未安装"
  has_cmd hermes   && ok "Hermes —— $(hermes --version 2>/dev/null | head -1)"        || err "Hermes —— 未安装"
  has_cmd lark-cli && ok "飞书 CLI —— $(lark-cli --version 2>/dev/null | head -1)"    || err "飞书 CLI —— 未安装"
  [ -d /Applications/Obsidian.app ] && ok "Obsidian —— 已安装"                        || err "Obsidian —— 未安装"
  say "${DIM}  ── 下面是依赖，不用单独管 ──${RST}"
  has_cmd node && ok "Node.js —— $(node -v)" || warn "Node.js —— 没有（装飞书 CLI 时自动处理）"
  has_cmd git  && ok "Git —— 已就绪"         || warn "Git —— 没有（装 Hermes 时会提示安装）"
}

# ---------- 各工具安装 ----------
do_claude(){
  step "Claude Code —— 大课主力 AI 助手"
  if has_cmd claude; then ok "已安装：$(claude --version 2>/dev/null | head -1)"; SKIPPED+=("Claude Code"); return; fi
  say "将运行官方安装脚本（native 二进制，不需要 Node）："
  say "  ${DIM}curl -fsSL https://claude.ai/install.sh | bash${RST}"
  ask_continue "现在安装 Claude Code？" || { SKIPPED+=("Claude Code"); return; }
  if curl -fsSL https://claude.ai/install.sh | bash; then
    ensure_local_bin
    if has_cmd claude; then ok "Claude Code 安装成功：$(claude --version 2>/dev/null | head -1)"; INSTALLED+=("Claude Code")
    else warn "装好了，但当前窗口还没刷新命令（结束后重开终端即可）"; INSTALLED+=("Claude Code（需重开终端）"); fi
  else err "Claude Code 安装失败（多半是网络）。稍后重试，或把这段截图发小组长。"; FAILED+=("Claude Code"); fi
}

do_codex(){
  step "Codex —— OpenAI 的 AI 终端"
  if has_cmd codex; then ok "已安装：$(codex --version 2>/dev/null | head -1)"; SKIPPED+=("Codex"); return; fi
  say "将运行官方安装脚本（不需要 Node）："
  say "  ${DIM}curl -fsSL https://chatgpt.com/codex/install.sh | sh${RST}"
  ask_continue "现在安装 Codex？" || { SKIPPED+=("Codex"); return; }
  if curl -fsSL https://chatgpt.com/codex/install.sh | sh; then
    ensure_local_bin
    if has_cmd codex; then ok "Codex 安装成功：$(codex --version 2>/dev/null | head -1)"; INSTALLED+=("Codex")
    else warn "装好了，但当前窗口还没刷新命令（结束后重开终端即可）"; INSTALLED+=("Codex（需重开终端）"); fi
  else err "Codex 安装失败（多半是网络）。稍后重试，或截图发小组长。"; FAILED+=("Codex"); fi
}

do_hermes(){
  step "Hermes Agent —— 能成长的 AI 助手"
  if has_cmd hermes; then ok "已安装：$(hermes --version 2>/dev/null | head -1)"; SKIPPED+=("Hermes"); return; fi
  if ! has_cmd git; then
    warn "Hermes 需要 Git。macOS 会弹窗让你装「命令行开发者工具」，点【安装】，装完再重跑本脚本。"
    xcode-select --install 2>/dev/null || true
    FAILED+=("Hermes（缺 Git，装完命令行工具后重跑）"); return
  fi
  say "将运行官方安装脚本（仅需 Git，会自动装 Python / Node 等依赖，耗时几分钟）："
  say "  ${DIM}curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash${RST}"
  ask_continue "现在安装 Hermes？" || { SKIPPED+=("Hermes"); return; }
  if curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash; then
    ensure_local_bin
    if has_cmd hermes; then ok "Hermes 安装成功：$(hermes --version 2>/dev/null | head -1)"; INSTALLED+=("Hermes")
    else warn "装好了，但当前窗口还没刷新命令（结束后重开终端即可）"; INSTALLED+=("Hermes（需重开终端）"); fi
  else err "Hermes 安装失败。稍后重试，或截图发小组长。"; FAILED+=("Hermes"); fi
}

do_larkcli(){
  step "飞书 CLI —— 让 AI 直接读写你的飞书表格 / 文档"
  if has_cmd lark-cli; then ok "已安装：$(lark-cli --version 2>/dev/null | head -1)"; SKIPPED+=("飞书 CLI"); return; fi
  if ! has_cmd node; then
    warn "飞书 CLI 需要 Node.js，但没检测到。"
    if has_cmd brew; then
      if ask_continue "检测到 Homebrew，用它安装 Node.js？"; then
        if brew install node; then ok "Node 安装成功：$(node -v)"
        else err "Node 安装失败。"; FAILED+=("飞书 CLI（Node 装失败）"); return; fi
      else SKIPPED+=("飞书 CLI（缺 Node）"); return; fi
    else
      warn "没有 Homebrew。请到 Node.js 官网下载 LTS 版双击安装，装完重跑本脚本："
      say "  ${CYN}https://nodejs.org/zh-cn/download${RST}"
      has_cmd open && { ask_continue "现在打开 Node.js 下载页？" && open "https://nodejs.org/zh-cn/download" || true; }
      SKIPPED+=("飞书 CLI（缺 Node，装完重跑）"); return
    fi
  fi
  say "将通过 npm 安装：${DIM}npm install -g @larksuite/cli${RST}"
  ask_continue "现在安装飞书 CLI？" || { SKIPPED+=("飞书 CLI"); return; }
  if npm install -g @larksuite/cli; then
    if has_cmd lark-cli; then ok "飞书 CLI 安装成功：$(lark-cli --version 2>/dev/null | head -1)"; INSTALLED+=("飞书 CLI")
    else warn "装好了，但当前窗口还没刷新命令（结束后重开终端即可）"; INSTALLED+=("飞书 CLI（需重开终端）"); fi
  else err "飞书 CLI 安装失败（可能是 npm 权限）。截图发小组长。"; FAILED+=("飞书 CLI"); fi
}

do_obsidian(){
  step "Obsidian —— 你的 AI 第二大脑 / 知识库（核心）"
  if [ -d "/Applications/Obsidian.app" ]; then ok "已安装 /Applications/Obsidian.app"; SKIPPED+=("Obsidian"); return; fi
  ask_continue "现在安装 Obsidian（核心知识库）？" || { SKIPPED+=("Obsidian"); return; }
  # 优先 Homebrew cask（最简单）
  if has_cmd brew && brew install --cask obsidian 2>/dev/null; then
    ok "Obsidian 安装成功（Homebrew）"; INSTALLED+=("Obsidian"); return
  fi
  # 无 brew 或失败：下载官方 universal dmg 自动安装
  say "下载 Obsidian 安装包（约几十 MB，稍等）..."
  local url tmp vol
  url=$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest 2>/dev/null | grep -o 'https://[^"]*universal\.dmg' | head -1)
  tmp="/tmp/Obsidian-installer.dmg"
  if [ -n "$url" ] && curl -fsSL "$url" -o "$tmp" 2>/dev/null; then
    vol=$(hdiutil attach "$tmp" -nobrowse 2>/dev/null | grep -o '/Volumes/[^ ]*' | head -1)
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

# ---------- 授权 / 登录 ----------
auth_phase(){
  hr; say "${BOLD}第二步：一个个带你登录 / 授权${RST}"; hr
  say "每个工具会打开浏览器或问你几个问题，跟着走就行。"
  say "${DIM}脚本不碰你的任何密码，所有登录都是你在官方页面自己完成。${RST}"

  if has_cmd codex; then
    step "① 登录 Codex（用你的 ChatGPT 账号）"
    say "即将运行 ${DIM}codex login${RST}，会打开浏览器。"
    ask_continue "现在登录 Codex？" && { codex login </dev/tty || warn "登录没完成，稍后可手动运行 codex login"; }
  fi

  if has_cmd lark-cli; then
    step "② 配置并授权 飞书 CLI"
    say "先初始化，再扫码 / 浏览器授权。"
    ask_continue "现在配置飞书 CLI？" && { lark-cli config init </dev/tty; lark-cli auth login </dev/tty || warn "授权没完成，稍后可手动运行 lark-cli auth login"; }
  fi

  if has_cmd hermes; then
    step "③ 配置 Hermes（交互式向导）"
    say "即将运行 ${DIM}hermes setup${RST}，跟着向导选模型 / 登录。"
    ask_continue "现在配置 Hermes？" && { hermes setup </dev/tty || warn "配置没完成，稍后可手动运行 hermes setup"; }
  fi

  if has_cmd claude; then
    step "④ Claude Code 登录（重点）"
    say "你的 Claude Code 打算怎么用？"
    say "  ${BOLD}1${RST} = 官方订阅登录（你有 Claude Pro / Max 账号）"
    say "  ${BOLD}2${RST} = 用中转（怕封号 / 没官方订阅 / 网络进不去官方）"
    printf "${CYN}输入 1 或 2，回车确认：${RST} "
    local ccmode; IFS= read -r ccmode </dev/tty || ccmode="1"
    if [ "$ccmode" = "2" ]; then
      say ""
      warn "中转方案：装 ${BOLD}CC Switch${RST}（一个管理中转的小软件，Claude Code / Codex 的中转都能在里面切；Hermes 不走这里）"
      say "三步搞定："
      say "  ${BOLD}1)${RST} 在打开的页面下载 macOS 版 CC Switch（.dmg），拖进 Applications"
      say "  ${BOLD}2)${RST} 打开 CC Switch → 添加供应商 → 填入${BOLD}小组长发给你的中转地址和密钥${RST}"
      say "  ${BOLD}3)${RST} 选中它 → 应用，之后 Claude Code 直接可用"
      say "  下载页：${CYN}https://github.com/farion1231/cc-switch/releases/latest${RST}"
      has_cmd open && { ask_continue "现在打开 CC Switch 下载页？" && open "https://github.com/farion1231/cc-switch/releases/latest" || true; }
      say "${DIM}（中转地址和密钥找小组长拿；脚本里不预置，避免泄露和封号）${RST}"
    else
      say "即将运行 ${DIM}claude${RST}，会打开浏览器走官方登录；登录后在里面输入 /exit 退出。"
      ask_continue "现在登录 Claude Code 官方？" && { claude </dev/tty || warn "登录没完成，稍后可手动运行 claude"; }
    fi
  fi
}

# ---------- 小结 ----------
summary(){
  hr; say "${BOLD}安装小结${RST}"; hr
  if [ ${#INSTALLED[@]} -gt 0 ]; then ok "本次新装好："; for x in "${INSTALLED[@]}"; do say "    • $x"; done; fi
  if [ ${#SKIPPED[@]}  -gt 0 ]; then say "${DIM}⏭  跳过 / 本来就有：${RST}"; for x in "${SKIPPED[@]}"; do say "    • $x"; done; fi
  if [ ${#FAILED[@]}   -gt 0 ]; then err "还没搞定（需处理）："; for x in "${FAILED[@]}"; do say "    • $x"; done
    say "  ${YLW}把上面这几行截图发小组长，会帮你看。${RST}"; fi
}

# ---------- 主流程 ----------
banner(){
  say "${BOLD}════════════════════════════════════════════${RST}"
  say "${BOLD}   航海家 · AI 工具一键部署助手${RST}"
  say "${BOLD}════════════════════════════════════════════${RST}"
}

main(){
  ensure_local_bin
  if [ "${1:-}" = "--check" ]; then banner; detect; echo; say "（这是只检测模式，没有安装任何东西）"; exit 0; fi

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
  detect
  hr; say "${BOLD}第一步：逐个检查并安装${RST}"; hr
  ask_continue "开始安装流程？" || { say "好的，下次再来。已装好的不会重复装。"; exit 0; }

  do_claude
  do_codex
  do_hermes
  do_larkcli
  do_obsidian
  summary

  echo
  ask_continue "进入第二步：登录授权？" && auth_phase

  hr; ok "全部流程结束！"
  say "建议：${BOLD}关掉这个终端窗口，重新开一个${RST}，粘贴下面这行确认都能用："
  say "  ${DIM}claude --version; codex --version; hermes --version; lark-cli --version${RST}"
  say "任何一个报错，截图发小组长。祝大课顺利 🚀"
}

main "$@"
