# ============================================================
#   航海家 · AI 工具一键部署助手 (Windows / PowerShell)
#   检测 -> 安装 -> 授权，全程中文引导，给零基础新手用
#
#   工具：Claude Code / Codex / Hermes / 飞书CLI / Obsidian
#   安装：CLI 走各家官方 PowerShell 安装器；依赖/桌面 App 走 winget；脚本内不含任何密钥
#
#   用法（在 PowerShell 里粘贴这一行；确保中文不乱码）：
#     irm https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/go.ps1 | iex
#   只检测不安装：先 $env:CHECK_ONLY=1; 再跑上面那行
# ============================================================

try { chcp 65001 > $null 2>&1; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$ErrorActionPreference = 'Continue'

# ---------- 输出（纯文本标记，避免乱码）----------
function Say($m){ Write-Host $m }
function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!]  $m" -ForegroundColor Yellow }
function Bad($m){ Write-Host "[X]  $m" -ForegroundColor Red }
function Step($m){ Write-Host ""; Write-Host ">> $m" -ForegroundColor Cyan }
function Hr(){ Write-Host "--------------------------------------------" }

# ---------- 状态记录 ----------
$script:INSTALLED=@(); $script:SKIPPED=@(); $script:FAILED=@()

# ---------- 工具函数 ----------
function Has($cmd){ return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Cmd-Version($cmd){
  try {
    $out = cmd /d /c "$cmd --version" 2>$null | Select-Object -First 1
    if($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$out")){ return "$out" }
  } catch {}
  return ""
}
function Cmd-Usable($cmd){ return (-not [string]::IsNullOrWhiteSpace((Cmd-Version $cmd))) }
function Lark-SkillsOk {
  if([string]::IsNullOrWhiteSpace($env:USERPROFILE)){ return $false }
  return (Test-Path (Join-Path $env:USERPROFILE ".agents\skills\lark-shared\SKILL.md"))
}
# Node 是否真可用：node 和 npm 都要在（飞书 CLI 要 npm）
function Node-Ok { return ((Has 'node') -and (Has 'npm')) }
function Path-HasEntry($pathValue, $dir){
  if([string]::IsNullOrWhiteSpace($pathValue) -or [string]::IsNullOrWhiteSpace($dir)){ return $false }
  $trim = @([char]92,[char]47)
  $needle = $dir.Trim().TrimEnd($trim)
  foreach($p in ($pathValue -split ';')){
    if($p.Trim().TrimEnd($trim) -ieq $needle){ return $true }
  }
  return $false
}
function Get-UserPathRaw {
  try {
    $v = (Get-ItemProperty -Path "HKCU:\Environment" -Name Path -ErrorAction Stop).Path
    if($null -ne $v){ return "$v" }
  } catch {}
  return [System.Environment]::GetEnvironmentVariable("Path","User")
}
function Set-UserPathRaw($value){
  try {
    if(Get-ItemProperty -Path "HKCU:\Environment" -Name Path -ErrorAction SilentlyContinue){
      Set-ItemProperty -Path "HKCU:\Environment" -Name Path -Value $value -ErrorAction Stop
    } else {
      New-ItemProperty -Path "HKCU:\Environment" -Name Path -Value $value -PropertyType ExpandString -Force -ErrorAction Stop | Out-Null
    }
  } catch {
    [System.Environment]::SetEnvironmentVariable("Path",$value,"User")
  }
}
function Add-UserPathEntry($dir){
  if([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path $dir)){ return $false }
  if(-not (Path-HasEntry $env:Path $dir)){ $env:Path = "$dir;$env:Path" }
  $u=Get-UserPathRaw
  if(-not (Path-HasEntry $u $dir)){
    if([string]::IsNullOrWhiteSpace($u)){ Set-UserPathRaw $dir }
    else { Set-UserPathRaw "$dir;$u" }
  }
  return $true
}
# Codex 官方 Windows 安装器默认放这里；有时装好了但当前 PowerShell PATH 没刷新。
function Codex-BinDir { return (Join-Path $env:LOCALAPPDATA "Programs\OpenAI\Codex\bin") }
function Ensure-CodexPath {
  $bin = Codex-BinDir
  $exe = Join-Path $bin "codex.exe"
  if(-not (Test-Path $exe)){ return $false }
  return (Add-UserPathEntry $bin)
}
function Codex-Ok { return (Cmd-Usable 'codex') }
function Codex-InstallerHasOSArchitecture {
  try {
    $t = [System.Runtime.InteropServices.RuntimeInformation]
    return ($null -ne $t.GetProperty("OSArchitecture"))
  } catch { return $false }
}
function Codex-FallbackArchitecture {
  $raw = if($env:PROCESSOR_ARCHITEW6432){ $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
  if($raw -match 'ARM64'){ return 'Arm64' }
  return 'X64'
}
function Install-CodexOfficial {
  $installer = Invoke-RestMethod https://chatgpt.com/codex/install.ps1 -ErrorAction Stop
  if(-not (Codex-InstallerHasOSArchitecture)){
    $arch = Codex-FallbackArchitecture
    Warn "当前 PowerShell 读不到 Codex 官方安装器需要的 OSArchitecture，已启用兼容架构识别：$arch"
    $pattern = '\$architecture = \[System\.Runtime\.InteropServices\.RuntimeInformation\]::OSArchitecture'
    if($installer -notmatch $pattern){ throw "Codex 官方安装器结构变化，无法应用兼容补丁。" }
    $installer = $installer -replace $pattern, ('$architecture = "' + $arch + '"')
  }
  Invoke-Expression $installer
}
function Repair-CodexSandboxSetup {
  $bin = Codex-BinDir
  $codex = Join-Path $bin "codex.exe"
  if(-not (Test-Path $codex)){ return $false }
  $dst = Join-Path $bin "codex-windows-sandbox-setup.exe"
  if(Test-Path $dst){ return $true }

  $candidates = @()
  $current = Join-Path $env:LOCALAPPDATA "openai-codex\current"
  $candidates += (Join-Path $current "codex-resources\codex-windows-sandbox-setup.exe")
  $candidates += (Join-Path (Split-Path -Parent $bin) "codex-resources\codex-windows-sandbox-setup.exe")
  try {
    $item = Get-Item -LiteralPath $bin -Force -ErrorAction Stop
    foreach($target in @($item.Target)){
      if(-not [string]::IsNullOrWhiteSpace($target)){
        $candidates += (Join-Path (Split-Path -Parent $target) "codex-resources\codex-windows-sandbox-setup.exe")
      }
    }
  } catch {}

  foreach($src in $candidates){
    if(Test-Path $src){
      Copy-Item -LiteralPath $src -Destination $dst -Force
      return (Test-Path $dst)
    }
  }

  try {
    $verText = (& $codex --version 2>$null | Select-Object -First 1)
    if("$verText" -notmatch '([0-9]+\.[0-9]+\.[0-9]+)'){ return $false }
    $ver = $Matches[1]
    $target = if((Codex-FallbackArchitecture) -eq 'Arm64'){ 'aarch64-pc-windows-msvc' } else { 'x86_64-pc-windows-msvc' }
    $url = "https://github.com/openai/codex/releases/download/rust-v$ver/codex-windows-sandbox-setup-$target.exe"
    Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing -ErrorAction Stop
    return (Test-Path $dst)
  } catch { return $false }
}
function Codex-Ready { return ((Codex-Ok) -and (Repair-CodexSandboxSetup)) }
# 是否课程主力命令行工具都已装齐：这里不再卡 Obsidian / 桌面 App，避免明明 CLI 全绿却继续问安装。
function All-Installed { return ( ((Cmd-Usable 'claude') -or (Pkg-Installed 'Anthropic.Claude')) -and (Codex-Ok) -and (Cmd-Usable 'hermes') -and (Cmd-Usable 'lark-cli') -and (Lark-SkillsOk) -and (Node-Ok) ) }

function Refresh-Path {
  $m=[System.Environment]::GetEnvironmentVariable("Path","Machine")
  $u=[System.Environment]::GetEnvironmentVariable("Path","User")
  if($m -or $u){ $env:Path = (($m,$u) -join ';').Trim(';') }
}

# 回车=继续 / s=跳过(返回 $false) / q=退出
function Ask($prompt){
  $ans = Read-Host "$prompt  [回车=继续 / s=跳过 / q=退出]"
  if($ans -ieq 's'){ return $false }
  if($ans -ieq 'q'){ Say ""; Say "已退出。随时可重新运行，已装好的会自动跳过。"; exit 0 }
  return $true
}

function Ensure-PowerShellCliPolicy {
  try {
    $machinePolicy = Get-ExecutionPolicy -Scope MachinePolicy -ErrorAction SilentlyContinue
    $userPolicy = Get-ExecutionPolicy -Scope UserPolicy -ErrorAction SilentlyContinue
    if($machinePolicy -ne 'Undefined' -or $userPolicy -ne 'Undefined'){
      Warn "这台电脑的 PowerShell 执行策略由系统/公司策略管理，脚本不能自动修改。若 claude / lark-cli 报无法加载 .ps1，请截图发群里。"
      return
    }
    $current = Get-ExecutionPolicy -ErrorAction SilentlyContinue
    if($current -in @('Restricted','AllSigned')){
      Warn "当前 PowerShell 禁止运行 npm 生成的 .ps1 命令启动脚本，可能导致 claude / lark-cli 明明装了却报 UnauthorizedAccess。"
      Say "  这一步只修改「当前用户」的 PowerShell 策略为 RemoteSigned，不需要管理员；它允许本机生成的命令启动脚本运行。"
      if(Ask "按回车修复 PowerShell 命令启动策略？"){
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
        Ok "PowerShell 命令启动策略已修复"
      }
    }
  } catch { Warn "PowerShell 命令启动策略修复失败：$_" }
}

function Existing-CommandFile($dirs, $files){
  foreach($dir in $dirs){
    if([string]::IsNullOrWhiteSpace($dir)){ continue }
    foreach($file in $files){
      $path = Join-Path $dir $file
      if(Test-Path $path){ return $path }
    }
  }
  return $null
}
function Npm-BinDirs {
  $dirs = @()
  if(Has 'npm'){
    try {
      $prefix = (& npm config get prefix 2>$null | Select-Object -First 1)
      if(-not [string]::IsNullOrWhiteSpace($prefix)){ $dirs += $prefix.Trim() }
    } catch {}
  }
  if(-not [string]::IsNullOrWhiteSpace($env:APPDATA)){ $dirs += (Join-Path $env:APPDATA "npm") }
  return ($dirs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}
function Node-BinDirs {
  $dirs = @()
  if(-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)){ $dirs += (Join-Path $env:ProgramFiles "nodejs") }
  $pf86=[System.Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
  if(-not [string]::IsNullOrWhiteSpace($pf86)){ $dirs += (Join-Path $pf86 "nodejs") }
  return ($dirs | Select-Object -Unique)
}
function Git-BinDirs {
  $dirs = @()
  if(-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)){
    $dirs += (Join-Path $env:ProgramFiles "Git\cmd")
    $dirs += (Join-Path $env:ProgramFiles "Git\bin")
  }
  if(-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)){ $dirs += (Join-Path $env:LOCALAPPDATA "Programs\Git\cmd") }
  return ($dirs | Select-Object -Unique)
}
function Hermes-BinDir { return (Join-Path $env:LOCALAPPDATA "hermes\hermes-agent\venv\Scripts") }
function Claude-BinDirs {
  $dirs = @()
  if(-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)){
    $dirs += (Join-Path $env:USERPROFILE ".claude\bin")
    $dirs += (Join-Path $env:USERPROFILE ".local\bin")
  }
  if(-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)){
    $dirs += (Join-Path $env:LOCALAPPDATA "Programs\Claude Code\bin")
    $dirs += (Join-Path $env:LOCALAPPDATA "AnthropicClaude\bin")
  }
  return ($dirs | Select-Object -Unique)
}
function Repair-PathForTool($display, $command, $dirs, $files){
  if(Cmd-Usable $command){ return $null }
  $found = Existing-CommandFile $dirs $files
  if(-not $found){ return $null }
  $dir = Split-Path -Parent $found
  Say ""
  Hr
  Say "PATH 修复：$display"
  Warn "检测到 $display 本体已安装在：$dir"
  Warn "但当前 PowerShell 找不到「$command」命令，说明 PATH（命令查找目录）缺少这一项。"
  if(-not (Ask "按回车配置 PATH，让现在和新开的 PowerShell 都能找到 $command？")){ return $false }
  Add-UserPathEntry $dir | Out-Null
  Refresh-Path
  if(Cmd-Usable $command){
    Ok "$display 环境已补好：$command 可用了"
    Say ""
    return $true
  }
  Warn "$display 的 PATH 已写入，但当前窗口仍没识别；关掉 PowerShell 重开后再试 $command --version。"
  Say ""
  return $false
}
function Ensure-PathRepairs {
  $touched = $false
  foreach($spec in @(
    @{d='Claude Code (CLI)'; c='claude'; dirs=(Claude-BinDirs); files=@('claude.exe','claude.cmd')},
    @{d='Codex (CLI)'; c='codex'; dirs=@(Codex-BinDir); files=@('codex.exe')},
    @{d='Hermes (CLI)'; c='hermes'; dirs=@(Hermes-BinDir); files=@('hermes.exe','hermes.cmd')},
    @{d='Node.js / npm'; c='node'; dirs=(Node-BinDirs); files=@('node.exe')},
    @{d='npm'; c='npm'; dirs=(Node-BinDirs); files=@('npm.cmd')},
    @{d='Git'; c='git'; dirs=(Git-BinDirs); files=@('git.exe')},
    @{d='飞书 CLI'; c='lark-cli'; dirs=(Npm-BinDirs); files=@('lark-cli.cmd','lark-cli.ps1')}
  )){
    $r = Repair-PathForTool $spec.d $spec.c $spec.dirs $spec.files
    if($null -ne $r){ $touched = $true }
  }
  if($touched){ Hr }
}

# ---------- 环境检测 ----------
$OSVer  = [System.Environment]::OSVersion.Version
$Build  = $OSVer.Build
$Arch   = if($env:PROCESSOR_ARCHITECTURE -match 'ARM'){ 'ARM64' } else { 'x64' }
$WinName= try { (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption } catch { "Windows" }

# ---------- winget 就绪检查 + 自动修复 ----------
function Ensure-Winget {
  if(Has 'winget'){ return $true }
  Warn "没检测到 winget（Windows 的「应用安装程序」），尝试自动注册……"
  try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop } catch {}
  Start-Sleep -Seconds 2
  if(Has 'winget'){ Ok "winget 已就绪"; return $true }
  Warn "winget 还是不可用。请打开 Microsoft Store 搜「应用安装程序 / App Installer」装一下，再重跑本脚本。"
  Say  "  商店链接：https://apps.microsoft.com/detail/9nblggh4nns1"
  return $false
}

function Winget-Install($id, $name){
  if(-not (Ensure-Winget)){ return $false }
  Say "  正在用 winget 安装 $name（请稍候，别关窗口）……"
  winget install -e --id $id --accept-source-agreements --accept-package-agreements --silent
  $rc = $LASTEXITCODE
  Refresh-Path
  if($rc -ne 0 -and $rc -ne -1978335189){ Warn "winget 装 $name 返回码 $rc（非 0，可能失败或已是最新；下面会再核对一次）" }
  return ($rc -eq 0 -or $rc -eq -1978335189)
}

function Pkg-Installed($id){
  if(-not (Has 'winget')){ return $false }
  $out = (winget list --id $id -e --accept-source-agreements 2>$null | Out-String)
  return ($out -match [regex]::Escape($id))
}

# ---------- 网络检测 ----------
function Test-Url($url){
  try { Invoke-WebRequest -Uri $url -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop | Out-Null; return $true } catch {}
  try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0")
    $wc.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    if($wc.Proxy){ $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials }
    $wc.DownloadString($url) | Out-Null
    return $true
  } catch { return $false }
}
function Test-AnyUrl($urls){
  foreach($url in $urls){ if(Test-Url $url){ return $true } }
  return $false
}
function Check-Network {
  Hr; Say "先检查 PowerShell 下载通道（仅提醒，不拦安装）"; Hr
  $gh = Test-AnyUrl @(
    "https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/go.ps1",
    "https://github.com"
  )
  $ai = Test-AnyUrl @(
    "https://downloads.claude.ai/claude-code-releases/bootstrap.ps1",
    "https://chatgpt.com/codex/install.ps1"
  )
  if($gh){ Ok "GitHub / Raw GitHub 下载通道可访问" } else { Warn "PowerShell 暂时访问不到 GitHub / Raw GitHub 下载通道" }
  if($ai){ Ok "Claude / Codex 官方下载源可访问" } else { Warn "PowerShell 暂时访问不到 Claude / Codex 官方下载源" }
  if(-not $gh -or -not $ai){
    Warn "这只是 PowerShell 预检失败，不等于浏览器打不开，也不直接说明脚本有问题。"
    Say  "  常见原因：浏览器走了代理，但 PowerShell 没走同一个代理。脚本会继续尝试安装；如果后面某个工具下载失败，再换节点 / 开系统代理或 TUN 模式 / 截图发群。"
  }
}

# ---------- 检测清单 ----------
function Detect {
  Hr; Say "先看看你这台电脑现在的安装情况"; Hr
  Say "  本机：$WinName (build $Build) / $Arch"
  if(-not [Environment]::Is64BitProcess){ Warn "你开的是 32 位 PowerShell。建议关掉、用开始菜单里普通的「Windows PowerShell」或「终端」重开，否则有些工具可能装不上。" }
  Say "  命令行工具(CLI)=终端里用、功能最全；桌面 App=图形界面、更直观。两者不冲突、可以都装。"
  Say "  >> 命令行工具（CLI）"
  if(Cmd-Usable 'claude'){ Ok "Claude Code (CLI) 已装" } else { Bad "Claude Code (CLI) 未装" }
  if(Codex-Ok){ Ok "Codex (CLI) 已装" } else { Bad "Codex (CLI) 未装" }
  if(Cmd-Usable 'hermes'){ Ok "Hermes (CLI) 已装" } else { Bad "Hermes (CLI) 未装" }
  if(Cmd-Usable 'lark-cli'){ Ok "飞书 CLI 已装" } else { Bad "飞书 CLI 未装" }
  if(Lark-SkillsOk){ Ok "飞书官方 Agent Skills 已装" } else { Warn "飞书官方 Agent Skills 未补齐（装飞书 CLI 时会一起补）" }
  if($Build -lt 17763){
    Warn "你的 Windows 偏旧（build $Build，低于 Win10 1809）：命令行 Claude Code / Codex 官方要求 1809+，可能装不了，建议升级 Windows。"
  }
  Say "  >> 桌面 App / 知识库（后面安装步骤会用 winget 自动判断 / 安装）"
  Say "  -- 下面是依赖，不用单独管 --"
  if(Has 'node'){ Ok "Node.js $(node -v)" } else { Warn "Node.js 没有（装飞书 CLI 时自动装）" }
  if(Has 'git'){ Ok "Git 已就绪" } else { Warn "Git 没有（装 Hermes 时自动装）" }
}

# ---------- 工作区 ----------
function Setup-Workspace {
  Step "先建一个工作区（你的知识库文件夹）"
  Say "给一个固定的文件夹放知识库 + AI 工作区，以后 Obsidian 和 AI 都在这里干活——选个你以后不会乱动的位置。"
  Say "  建议别放在 OneDrive 同步的「文档」里（同步大文件容易出问题、路径还会变）。"
  $default = Join-Path $env:USERPROFILE "AI-Workspace"
  Say "  直接回车用默认：$default"
  Say "  或粘贴你想要的完整路径（例如 D:\AI-Workspace）："
  $inp = Read-Host "工作区路径"
  if([string]::IsNullOrWhiteSpace($inp)){ $script:WORKSPACE = $default } else { $script:WORKSPACE = $inp }
  New-Item -ItemType Directory -Force -Path $script:WORKSPACE | Out-Null
  Set-Location $script:WORKSPACE
  Ok "工作区：$script:WORKSPACE（已进入，后面装的工具都以这里为工作目录）"
}

# ---------- 各 CLI 安装 ----------
function Do-Claude {
  Step "Claude Code —— 大课主力 AI 助手（命令行）"
  if(Cmd-Usable 'claude'){ Ok "已安装"; $script:SKIPPED+="Claude Code"; return }
  if($Build -lt 17763){
    Warn "你的 Windows 偏旧（build $Build）。命令行 Claude Code 官方要求 Win10 1809+，可能装不上。"
    Say  "  建议：升级 Windows 到 1809+，或用 Claude 桌面客户端（后面会引导）。"
    $script:SKIPPED+="Claude Code 命令行（Windows 旧）"; return
  }
  if(-not (Ask "现在安装 Claude Code（命令行）？")){ $script:SKIPPED+="Claude Code"; return }
  Say "  正在下载安装（官方 PowerShell 安装器，1-2 分钟，别关窗口）……"
  $ok=$true; $cfBlocked=$false
  try {
    $cc = Invoke-RestMethod https://claude.ai/install.ps1 -ErrorAction Stop
    if("$cc" -match 'Just a moment|cf_chl|challenge-platform|<html') {
      $cfBlocked=$true
      Warn "claude.ai 入口返回了 Cloudflare 验证页，改用官方下载备用源……"
      $cc = Invoke-RestMethod https://downloads.claude.ai/claude-code-releases/bootstrap.ps1 -ErrorAction Stop
    }
    if("$cc" -match 'Just a moment|cf_chl|challenge-platform|<html') { $ok=$false }
    else { Invoke-Expression "$cc" }
  } catch { $ok=$false; Warn "安装过程报错：$_" }
  Refresh-Path
  if(Cmd-Usable 'claude'){ Ok "Claude Code 安装成功"; $script:INSTALLED+="Claude Code" }
  elseif($cfBlocked){
    Bad "Claude Code 下载入口被 Cloudflare 拦了，官方备用源也没装成——这不是网络完全不通。"
    Say "  是 claude.ai 入口前面的 Cloudflare 把你这个 IP 判成可疑了（跟机房/住宅无关，是这个具体 IP 的信誉评分）。解决：换个节点/IP 再跑（换机场节点、或开手机热点；住宅 IP 通常最稳），或授权那步选「中转」走 CC Switch。"
    $script:FAILED+="Claude Code（入口被 Cloudflare 拦，备用源也失败 → 换 IP 或走中转）"
  }
  elseif(-not $ok){ Bad "Claude Code 安装失败（多半网络），截图发到群里。"; $script:FAILED+="Claude Code（安装失败）" }
  else { Warn "装完了但当前窗口没认到命令（结束后重开 PowerShell 再试 claude --version）"; $script:INSTALLED+="Claude Code（需重开终端确认）" }
}

function Do-Codex {
  Step "Codex —— OpenAI 的 AI 终端（命令行）"
  if(Codex-Ok){
    if(Repair-CodexSandboxSetup){ Ok "已安装，Windows sandbox 辅助程序已就绪" }
    else { Ok "已安装"; Warn "Windows sandbox 辅助程序未补齐；如启动 Codex 弹窗找不到 codex-windows-sandbox-setup.exe，截图发群里。" }
    $script:SKIPPED+="Codex"
    return
  }
  if($Build -lt 17763){
    Warn "你的 Windows 偏旧（build $Build）。命令行 Codex 官方要求 Win10 1809+，可能装不上。"
    Say  "  建议：升级 Windows，或用 Codex 桌面 App（后面会引导）。"
    $script:SKIPPED+="Codex 命令行（Windows 旧）"; return
  }
  if(-not (Ask "现在安装 Codex？")){ $script:SKIPPED+="Codex"; return }
  Say "  正在下载安装（官方 PowerShell 安装器）……"
  $ok=$true
  try { Install-CodexOfficial } catch { $ok=$false; Warn "安装过程报错：$_" }
  Refresh-Path
  Ensure-CodexPath | Out-Null
  if(Codex-Ok){
    if(Repair-CodexSandboxSetup){ Ok "Codex 安装成功，Windows sandbox 辅助程序已就绪" }
    else { Ok "Codex 安装成功"; Warn "Windows sandbox 辅助程序未补齐；如启动 Codex 弹窗找不到 codex-windows-sandbox-setup.exe，截图发群里。" }
    $script:INSTALLED+="Codex"
  }
  elseif(-not $ok){ Bad "Codex 安装失败（多半网络），截图发到群里。"; $script:FAILED+="Codex（安装失败）" }
  else {
    Bad "Codex 安装后仍没识别到命令。"
    Say "  请截图发到群里；也可以先手动检查：$env:LOCALAPPDATA\Programs\OpenAI\Codex\bin\codex.exe --version"
    $script:FAILED+="Codex（安装后命令未识别）"
  }
}

function Do-Hermes {
  Step "Hermes Agent —— 能成长的 AI 助手"
  if(Cmd-Usable 'hermes'){ Ok "已安装"; $script:SKIPPED+="Hermes"; return }
  if(-not (Ask "现在安装 Hermes？（会自动装 Git/Python/Node 等依赖，耗时几分钟）")){ $script:SKIPPED+="Hermes"; return }
  Say "  正在装 Hermes：只安装本体和环境，不进入 Hermes 配置向导；会下 uv / Python / Node 等依赖，正常首次 5-15 分钟、没进度条别慌。"
  Warn "卡在某一步（如 Installing managed uv）超过 10 分钟完全不动 = 网络/Cloudflare 拦了下载：按 Ctrl+C 中断，先跳过 Hermes（Claude Code/Codex 是主力、够用），换干净网络/IP 再单独装。"
  $ok=$true
  try {
    $installer = Invoke-RestMethod https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1 -ErrorAction Stop
    $installerBlock = [ScriptBlock]::Create("$installer")
    & $installerBlock -SkipSetup
  } catch { $ok=$false; Warn "安装过程报错：$_" }
  Refresh-Path
  Add-UserPathEntry (Hermes-BinDir) | Out-Null
  if(Cmd-Usable 'hermes'){ Ok "Hermes 安装成功"; $script:INSTALLED+="Hermes" }
  elseif(-not $ok){ Bad "Hermes 安装失败（多半网络），截图发到群里。"; $script:FAILED+="Hermes（安装失败）" }
  else { Warn "装完了但当前窗口没认到命令（结束后重开 PowerShell）"; $script:INSTALLED+="Hermes（需重开终端）" }
}

function Install-Node {
  if(Node-Ok){ return $true }
  Warn "飞书 CLI 需要 Node.js，没检测到，正在用 winget 自动装……"
  Winget-Install 'OpenJS.NodeJS.LTS' 'Node.js LTS' | Out-Null
  Refresh-Path
  foreach($dir in (Node-BinDirs)){ Add-UserPathEntry $dir | Out-Null }
  if(Has 'node'){ Ok "Node 安装成功：$(node -v)"; return $true }
  Warn "Node 装了但当前窗口还没刷新到（可能需重开 PowerShell）。"
  return (Has 'node')
}

function Ensure-BaseDeps {
  Hr; Say "先把基础底座装好（winget / Git / Node，后面各工具都依赖）"; Hr
  if(Ensure-Winget){ Ok "winget（应用安装程序）—— 已就绪" }
  if(Has 'git'){ Ok "Git —— 已就绪" }
  else {
    Warn "没检测到 Git，正在用 winget 自动装（Claude Code / Hermes 都可能要用）……"
    Winget-Install 'Git.Git' 'Git for Windows' | Out-Null
    Refresh-Path
    foreach($dir in (Git-BinDirs)){ Add-UserPathEntry $dir | Out-Null }
    if(Has 'git'){ Ok "Git 安装成功" } else { Warn "Git 没装上（可能需重开 PowerShell）；后续报缺 Git 就手动装 https://gitforwindows.org" }
  }
  if(Node-Ok){ Ok "Node.js / npm —— 已就绪（$(node -v)）" } else { Install-Node | Out-Null; if(-not (Node-Ok)){ Warn "Node 没装好（飞书 CLI 那步会再试）"; $script:FAILED+="Node.js（飞书 CLI 依赖）" } }
}

function Do-Larkcli {
  Step "飞书 CLI —— 让 AI 直接读写你的飞书表格 / 文档"
  if(-not (Node-Ok)){
    if(-not (Install-Node)){
      Bad "Node 自动安装失败（多半网络）。先弄通网络重跑，或到 https://nodejs.org/zh-cn/download 手动装 LTS。"
      $script:SKIPPED+="飞书 CLI（缺 Node）"; return
    }
  }
  if(Cmd-Usable 'lark-cli'){
    Ok "已检测到飞书 CLI：$(Cmd-Version 'lark-cli')"
    Say "  为了补齐官方 AI Agent Skills，这一步会再运行一次官方安装器（已装好的会自动升级/跳过）。"
  }
  if(-not (Ask "现在安装 / 补齐飞书 CLI + 官方 AI Agent Skills？")){ $script:SKIPPED+="飞书 CLI"; return }
  Say "  通过官方安装器安装：CLI 本体 + 飞书官方 AI Agent Skills 会一起装好……"
  cmd /c "npx --yes @larksuite/cli@latest install"
  $rc=$LASTEXITCODE
  Refresh-Path
  foreach($dir in (Npm-BinDirs)){ Add-UserPathEntry $dir | Out-Null }
  if((Cmd-Usable 'lark-cli') -and (Lark-SkillsOk)){ Ok "飞书 CLI + 官方 Agent Skills 安装成功"; $script:INSTALLED+="飞书 CLI（含官方 Agent Skills）" }
  elseif(Cmd-Usable 'lark-cli'){ Warn "飞书 CLI 已可用，但官方 Agent Skills 没检测到；重跑脚本会继续补。"; $script:INSTALLED+="飞书 CLI（Agent Skills 待补）" }
  elseif($rc -ne 0){ Bad "飞书 CLI 安装失败（npm 返回 $rc，多半网络/权限），截图发到群里。"; $script:FAILED+="飞书 CLI（安装失败）" }
  else { Warn "装完了但当前窗口没认到命令（结束后重开 PowerShell）"; $script:INSTALLED+="飞书 CLI（需重开终端）" }
}

function Do-Obsidian {
  Step "Obsidian —— 你的 AI 第二大脑 / 知识库（核心）"
  if(Pkg-Installed 'Obsidian.Obsidian'){ Ok "已安装"; $script:SKIPPED+="Obsidian"; return }
  if(-not (Ask "现在安装 Obsidian（核心知识库）？")){ $script:SKIPPED+="Obsidian"; return }
  Winget-Install 'Obsidian.Obsidian' 'Obsidian' | Out-Null
  if(Pkg-Installed 'Obsidian.Obsidian'){ Ok "Obsidian 安装成功"; $script:INSTALLED+="Obsidian"; return }
  Warn "自动装没成功（多半网络），手动下载：https://obsidian.md/download"
  Start-Process "https://obsidian.md/download" 2>$null
  $script:FAILED+="Obsidian（请手动装）"
}

# ---------- CC Switch（中转管理，自动下载安装）----------
function Start-CCSwitch {
  Say "  正在帮你打开 CC Switch……"
  $exe = Get-ChildItem "$env:LOCALAPPDATA\Programs","$env:ProgramFiles" -Recurse -Filter "CC Switch*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if($exe){ Start-Process $exe.FullName 2>$null } else { Say "  （没自动找到，到开始菜单搜「CC Switch」打开即可）" }
}
function Install-CCSwitch {
  if(Pkg-Installed 'farion1231.CC-Switch'){ Ok "CC Switch 已安装"; Start-CCSwitch; return }
  Say "帮你自动下载安装 CC Switch（一键管理中转，Claude Code / Codex / Hermes 的中转都在它里面配）"
  Winget-Install 'farion1231.CC-Switch' 'CC Switch' | Out-Null
  if(Pkg-Installed 'farion1231.CC-Switch'){ Ok "CC Switch 安装成功"; Start-CCSwitch; return }
  Warn "自动装没成功（多半网络），帮你打开下载页手动装（下载 Windows 版 .msi 双击安装）："
  Say  "  https://github.com/farion1231/cc-switch/releases/latest"
  Start-Process "https://github.com/farion1231/cc-switch/releases/latest" 2>$null
}

# ---------- 授权 / 登录 ----------
function Auth-Phase {
  Hr; Say "第二步：一个个带你登录 / 授权"; Hr
  Say "每个工具会打开浏览器或问你几个问题，跟着走就行。脚本不碰你的任何密码。"

  if(Cmd-Usable 'codex'){
    Step "1) Codex OAuth（用你的 ChatGPT 账号）"
    Say "脚本不自动打开 OAuth 登录。需要官方账号登录时，之后手动运行：codex login"
    Say "  远程/无浏览器环境可用：codex login --device-auth"
  }
  if(Cmd-Usable 'lark-cli'){
    Step "2) 配置并授权 飞书 CLI"
    if(Ask "现在配置并授权飞书 CLI？"){ try { cmd /c "lark-cli config init --new"; cmd /c "lark-cli auth login --recommend" } catch { Warn "授权没完成，稍后可手动运行 lark-cli auth login --recommend" } }
  }
  if(Cmd-Usable 'hermes'){
    Step "3) Hermes —— 装好就行，先不用配"
    Ok "Hermes 命令行已就绪（hermes --version 能看到版本就成）。"
    Say "  今晚不用急着选模型 / 订阅。要用中转的话：和 Claude Code / Codex 一样，在 CC Switch 里点右上角「新建」，填中转地址和密钥即可。"
  }
  if(Cmd-Usable 'claude'){
    Step "4) Claude Code 登录（重点）"
    Say "Claude Code 登录是最容易卡住的一步。下面一次只问一个问题，按当前问题回答即可。"
    Say ""
    Say "问题 1：你有 Claude 官方付费账号吗？（Claude Pro / Max）"
    Say "  为什么问：没有官方账号就没法走官方登录，只能用第三方中转。"
    Say "    1 = 有        2 = 没有"
    $q1 = Read-Host "输入 1 或 2"
    Say ""

    if($q1 -eq '2'){
      Say "建议走第三方中转：你没有 Claude 官方账号，官方登录走不通。"
      if(-not (Ask "现在安装 CC Switch 中转管理器？")){ $script:SKIPPED+="Claude Code 登录 / CC Switch"; return }
      Say "好的，下面帮你自动下载官方版本并安装："
      Install-CCSwitch
      Say "  配置（在打开的 CC Switch 里）：点右上角「新建」-> 填中转地址和密钥 -> 选中 -> 应用。"
      Say "  中转地址和密钥自己去这两个靠谱的中转站注册、充值一些先试用（充一两百够用很久）："
      Say "    https://aigocode.com/invite/ATR5EXTD"
      Say "    https://apikey.fun/register?aff=S46XYZ9AKRFM"
      Say "  配好后 Claude Code / Codex / Hermes 都走这个中转。脚本不预置密钥（避免泄露和封号）。"
      return
    }

    Say "问题 2：这个 Claude 官方账号被封过、或你担心被封吗？"
    Say "  为什么问：账号被封过的话，再用官方登录很容易又被封；改用中转更稳妥。"
    Say "    1 = 没事 / 不担心      2 = 被封过 / 担心"
    $q2 = Read-Host "输入 1 或 2"
    Say ""

    if($q2 -eq '2'){
      Say "建议走第三方中转：账号被封过 / 担心被封，不拿正式账号冒险。"
      if(-not (Ask "现在安装 CC Switch 中转管理器？")){ $script:SKIPPED+="Claude Code 登录 / CC Switch"; return }
      Say "好的，下面帮你自动下载官方版本并安装："
      Install-CCSwitch
      Say "  配置（在打开的 CC Switch 里）：点右上角「新建」-> 填中转地址和密钥 -> 选中 -> 应用。"
      Say "  中转地址和密钥自己去这两个靠谱的中转站注册、充值一些先试用（充一两百够用很久）："
      Say "    https://aigocode.com/invite/ATR5EXTD"
      Say "    https://apikey.fun/register?aff=S46XYZ9AKRFM"
      Say "  配好后 Claude Code / Codex / Hermes 都走这个中转。脚本不预置密钥（避免泄露和封号）。"
      return
    }

    Say "建议走 Claude 官方账号登录。"
    Say "即将运行 claude，会打开浏览器走官方登录；登录后在里面输入 /exit 退出。"
    if(Ask "现在登录 Claude Code 官方？"){ try { cmd /c "claude" } catch { Warn "登录没完成，稍后可手动运行 claude" } }
  }
}

# ---------- 图形界面：Claudian 插件 + 桌面客户端 ----------
function Do-Clients {
  Step "图形界面：Claudian 插件 + 桌面客户端"
  Say "1) 在 Obsidian 里装 Claudian 插件（强烈推荐，所有系统都能用）"
  Say "  它让你在 Obsidian 界面里直接用 Claude Code / Codex（侧边栏聊天、选中改写），体验很接近 Codex 桌面 app。"
  Say "  装法：打开 Obsidian -> 设置 -> 第三方插件（社区插件）-> 搜 Claudian -> 安装并启用 -> 选 Claude 或 Codex。"
  Say "  小提示：Windows 上 Claude Code 已由本脚本用官方安装器装好（不是 npm），Claudian 能正确检测到。"

  Say ""
  Say "2) Claude 桌面客户端（图形界面，Intel / 新机器都能装）"
  if(Pkg-Installed 'Anthropic.Claude'){ Ok "Claude 桌面客户端已安装" }
  else {
    if(Ask "现在用 winget 装 Claude 桌面客户端？"){
      Winget-Install 'Anthropic.Claude' 'Claude 桌面客户端' | Out-Null
      if(Pkg-Installed 'Anthropic.Claude'){ Ok "Claude 桌面客户端安装成功"; $script:INSTALLED+="Claude 桌面客户端" }
      else { Warn "没装成功，可去 https://claude.ai/download 手动下载"; Start-Process "https://claude.ai/download" 2>$null }
    }
  }

  Say ""
  Say "3) Codex 桌面 App（图形界面，需 ChatGPT 账号）"
  if(Pkg-Installed '9PLM9XGG6VKS'){ Ok "Codex 桌面 App 已安装" }
  elseif(Ask "现在装 Codex 桌面 App？（走 Microsoft 商店）"){
    if(Ensure-Winget){
      Say "  正在从 Microsoft Store 安装 Codex App……"
      winget install -e --id 9PLM9XGG6VKS -s msstore --accept-source-agreements --accept-package-agreements
      if($LASTEXITCODE -eq 0){ Ok "Codex 桌面 App 安装成功（开始菜单搜 Codex 打开）"; $script:INSTALLED+="Codex 桌面 App" }
      else { Warn "Codex App 没装成功（商店源可能要登录或网络问题）。可去 Microsoft Store 搜 Codex 手动装。" }
    }
  }

  Say ""
  Say "4) Hermes 桌面 App（图形界面，比命令行友好；和命令行 Hermes 共享同一份配置）"
  if(Cmd-Usable 'hermes'){
    Say "  你已装命令行 Hermes，最省事：用官方命令 hermes desktop 后台构建并打开桌面 App（首次几分钟）。"
    if(Ask "现在后台构建并打开 Hermes 桌面 App？（后台跑、不打断后面流程，几分钟后自动打开）"){
      Start-Process -FilePath "cmd.exe" -ArgumentList "/d /c hermes desktop" -WindowStyle Hidden
      Ok "已在后台开始构建 Hermes 桌面 App（几分钟后自动打开；若没反应可去 https://hermes-agent.nousresearch.com/desktop 下安装包）。"
    }
  } elseif(Ask "下载并运行 Hermes 桌面 App 安装包？"){
    $exe="$env:TEMP\Hermes-Setup.exe"
    Say "  正在下载（官方源，约 8MB）……"
    try {
      Invoke-WebRequest -Uri "https://hermes-assets.nousresearch.com/Hermes-Setup.exe" -OutFile $exe -ErrorAction Stop
      Start-Process $exe
      Say "  跟着安装器点「下一步」装完即可。"
    } catch { Warn "下载没成功（多半网络），可手动下载：https://hermes-agent.nousresearch.com/desktop" }
  }
}

# ---------- 小结 ----------
function Summary {
  Hr; Say "安装小结"; Hr
  if($script:INSTALLED.Count -gt 0){ Ok "本次新装好："; $script:INSTALLED | ForEach-Object { Say "    - $_" } }
  if($script:SKIPPED.Count  -gt 0){ Say "跳过 / 本来就有："; $script:SKIPPED | ForEach-Object { Say "    - $_" } }
  if($script:FAILED.Count   -gt 0){ Bad "还没搞定（需处理）："; $script:FAILED | ForEach-Object { Say "    - $_" }; Say "  把上面这几行截图发到群里。" }
}

function Show-FinalCheck {
  Hr; Say "最后确认：逐个检查命令是否能用"; Hr
  $claudeVer = Cmd-Version 'claude'
  if($claudeVer){ Ok "Claude Code 可用：$claudeVer" } else { Bad "Claude Code 未识别" }
  $codexVer = Cmd-Version 'codex'
  if($codexVer){ Ok "Codex 可用：$codexVer" }
  else {
    Bad "Codex 未识别"
    Say "  修复命令（复制这一行重跑新版一键脚本）："
    Say '  irm https://raw.githubusercontent.com/0xWinner98/mac-onboarding-setup/main/go.ps1 | iex'
  }
  $hermesVer = Cmd-Version 'hermes'
  if($hermesVer){ Ok "Hermes 可用：$hermesVer" } else { Bad "Hermes 未识别" }
  $larkVer = Cmd-Version 'lark-cli'
  if($larkVer){ Ok "飞书 CLI 可用：$larkVer" } else { Bad "飞书 CLI 未识别" }
}

# ---------- 主流程 ----------
function Banner {
  Say "============================================"
  Say "   航海家 · AI 工具一键部署助手 (Windows)"
  Say "============================================"
}

function Main {
  if($env:CHECK_ONLY -eq '1'){ Banner; Check-Network; Detect; Say ""; Say "（这是只检测模式，没有安装任何东西）"; return }
  Clear-Host
  Banner
  Say "这个脚本帮你检测、安装、并带你登录 6/6 大课要用的工具。"
  Say "工具都从各家官方源下载，脚本里不含任何密钥。"
  Say "按提示回车即可；不想装某个就输 s 跳过；想退出输 q。"
  Check-Network
  Ensure-PowerShellCliPolicy
  Ensure-PathRepairs
  Detect
  if(All-Installed){
    Repair-CodexSandboxSetup | Out-Null
    Hr; Ok "恭喜！大课主力命令行工具已经装好了，不用重新安装 🎉"
    Say "  已确认：Claude Code / Codex / Hermes / 飞书 CLI + 官方 Agent Skills / Node.js。"
    Say "  Obsidian、Claudian、桌面 App 属于图形界面补充；需要时再单独装，不再卡住主流程。"
    Show-FinalCheck
    Hr; Ok "全部就绪，祝大课顺利！"; return
  }
  Hr; Say "第一步：逐个检查并安装"; Hr
  if(-not (Ask "开始安装流程？")){ Say "好的，下次再来。已装好的不会重复装。"; return }
  Setup-Workspace
  Ensure-BaseDeps
  Do-Claude
  Do-Codex
  Do-Hermes
  Do-Larkcli
  Do-Obsidian
  Do-Clients
  Ensure-PowerShellCliPolicy
  Ensure-PathRepairs
  Summary
  Say ""
  if(Ask "进入第二步：登录授权？"){ Auth-Phase }
  Hr; Ok "全部流程结束！"
  Show-FinalCheck
  Say "建议：关掉这个 PowerShell 窗口，重新开一个；如果上面仍有红色报错，截图发到群里。祝大课顺利！"
}

Main
