# Black Sheep AIOS - instalador Windows
# Uso:  .\install.ps1 [-ClaudeHome <dir>] [-DryRun] [-Yes] [-SkipTools] [-Name "..."] [-Role "..."] [-Focus "..."]
#
# O que faz:
#   1. Checa pre-requisitos (git, node, python, uv, jq, claude). NAO os instala: imprime o
#      comando certo do manifest.json (instalacao de linguagem/runtime fica a cargo do usuario).
#   2. Copia o harness para ~/.claude (backup de tudo que for sobrescrito).
#   3. Copia plugins/ para ~/.claude/plugins/bsaios-marketplace (plugin vendorizado bsaios-core)
#      usando robocopy (caminhos longos).
#   4. Gera ~/.claude/settings.json e ~/.claude/CLAUDE.md a partir dos templates (GateGuard ON;
#      no Windows nativo o hook do RTK e REMOVIDO - RTK opera via @RTK.md no CLAUDE.md).
#   5. Ferramentas externas (rtk, graphify, agent-browser): para cada uma AUSENTE, PERGUNTA e
#      instala (fail-soft). rtk nao tem winget/scoop: baixa o .zip do release, extrai rtk.exe
#      para ~/.local/bin, adiciona ao PATH do usuario e roda rtk init -g.
#   6. Instala PyYAML (hook validate-agent-frontmatter) - pulado no -DryRun.
#   7. Grava ~/.claude/.bsaios/{version,profile,manifest.installed}.json (ancora de versao +
#      identidade cacheada + inventario para prune) - ULTIMO passo bem-sucedido.
#
# -DryRun:    exige -ClaudeHome, nao pergunta nada, nao instala pacote
#             (usa uma identidade de teste para o render nao recusar por placeholder).
# -Yes:       aceita automaticamente a instalacao das ferramentas externas (nao interativo).
# -SkipTools: nao instala ferramentas externas (so avisa quais faltam).

[CmdletBinding()]
param(
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE ".claude"),
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$SkipTools,
    [string]$Name = "",
    [string]$Role = "",
    [string]$Focus = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$RepoDir   = Split-Path $ScriptDir -Parent

function Say($m)  { Write-Host $m }
function Ok($m)   { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!!] $m" -ForegroundColor Yellow }

# Baixa o rtk.exe do release (nao ha winget/scoop), extrai para ~/.local/bin e ajusta o PATH.
function Install-RtkWindows {
    $dest = Join-Path $env:USERPROFILE ".local\bin"
    New-Item -ItemType Directory -Force $dest | Out-Null
    $zip = Join-Path $env:TEMP "rtk-win.zip"
    $url = "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-x86_64-pc-windows-msvc.zip"
    Say "  baixando $url"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notmatch [regex]::Escape($dest)) {
        [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $dest), "User")
        Ok "adicionado ao PATH do usuario: $dest (reabra o terminal p/ efeito permanente)"
    }
    $env:Path = "$env:Path;$dest"   # disponivel ja nesta sessao (p/ rtk init -g e verificacao)
}

# Invoke-ExtTool <id> <bin-p/-Get-Command> <scriptblock-install> [scriptblock-post]
# Instala uma ferramenta externa AUSENTE: pergunta (a menos que -Yes), instala, verifica, roda o post.
# Fail-soft: qualquer falha vira aviso e o instalador segue.
function Invoke-ExtTool($id, $bin, [scriptblock]$Install, [scriptblock]$Post) {
    if (Get-Command $bin -ErrorAction SilentlyContinue) { Ok "$id (ja instalado)"; return }
    if ($SkipTools) { Warn "$id ausente (-SkipTools) - instale depois"; return }
    if ($DryRun)    { Warn "$id ausente (dry-run: nao instala)"; return }
    $ans = "y"
    if (-not $Yes) { $ans = Read-Host "  $id ausente. Instalar agora? [Y/n]" }
    if ($ans -match '^[nN]') { Warn "$id pulado (fail-soft) - instale depois"; return }
    Say "  instalando $id..."
    try {
        & $Install
        $env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
        if (Get-Command $bin -ErrorAction SilentlyContinue) {
            Ok "$id instalado"
            if ($Post) { try { & $Post; Ok "$id post-install ok" } catch { Warn "$id post-install falhou (rode manualmente)" } }
        } else {
            Warn "${id}: instalou mas '$bin' ainda nao esta no PATH - reabra o terminal"
        }
    } catch {
        Warn "${id}: instalacao falhou (fail-soft) - $($_.Exception.Message)"
    }
}

Say ""
Say "== Black Sheep AIOS - instalador Windows =="
Say "   repo:        $RepoDir"
if ($DryRun) { Say "   CLAUDE_HOME: $ClaudeHome (DRY-RUN)" } else { Say "   CLAUDE_HOME: $ClaudeHome" }
Say ""

# ---------------------------------------------------------------- 1. pre-requisitos
Say "[1/7] Pre-requisitos"
$script:Missing = 0
function Need($bin, $installHint) {
    if (Get-Command $bin -ErrorAction SilentlyContinue) { Ok $bin; return }
    Warn "$bin AUSENTE - instale com: $installHint"
    $script:Missing++
}
Need "git"           "winget install Git.Git"
Need "node"          "winget install OpenJS.NodeJS.LTS"
Need "python"        "winget install Python.Python.3.12"
Need "uv"            "winget install astral-sh.uv"
Need "jq"            "winget install jqlang.jq   (recomendado: team-os usa p/ descobrir agents de plugin)"
Need "claude"        "irm https://claude.ai/install.ps1 | iex"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "node e obrigatorio para o instalador." }
if ($script:Missing -gt 0) { Warn "$($script:Missing) item(ns) ausente(s) - o instalador segue; instale-os depois (lista completa: install\manifest.json)." }

# ---------------------------------------------------------------- 2. harness -> CLAUDE_HOME
Say ""
Say "[2/7] Harness -> $ClaudeHome"
$Stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup = Join-Path $ClaudeHome "backups\bsaios-$Stamp"
New-Item -ItemType Directory -Force $ClaudeHome | Out-Null

function BackupAndCopy($src, $rel) {
    $dest = Join-Path $ClaudeHome $rel
    if (Test-Path $dest) {
        $bdest = Join-Path $Backup $rel
        New-Item -ItemType Directory -Force (Split-Path $bdest) | Out-Null
        Copy-Item $dest $bdest -Recurse -Force
        Remove-Item $dest -Recurse -Force   # evita aninhamento (Copy-Item dir sobre dir existente cria dest\dir)
    }
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item $src $dest -Recurse -Force
    Ok $rel
}

BackupAndCopy (Join-Path $RepoDir "harness\RTK.md")                "RTK.md"
BackupAndCopy (Join-Path $RepoDir "harness\statusline-command.js") "statusline-command.js"
Get-ChildItem (Join-Path $RepoDir "harness\skills") -Directory | ForEach-Object {
    BackupAndCopy $_.FullName ("skills\" + $_.Name)
}
Get-ChildItem (Join-Path $RepoDir "harness\agents") -Filter *.md | ForEach-Object {
    BackupAndCopy $_.FullName ("agents\" + $_.Name)
}
BackupAndCopy (Join-Path $RepoDir "harness\hooks\git-moment-advisor.sh")         "hooks\git-moment-advisor.sh"
BackupAndCopy (Join-Path $RepoDir "harness\hooks\validate-agent-frontmatter.py") "hooks\validate-agent-frontmatter.py"
BackupAndCopy (Join-Path $RepoDir "harness\hooks\team")                          "hooks\team"
Get-ChildItem (Join-Path $RepoDir "harness\rules") -Filter *.md | ForEach-Object {
    BackupAndCopy $_.FullName ("rules\" + $_.Name)
}
Get-ChildItem (Join-Path $RepoDir "harness\commands") -Filter *.md | ForEach-Object {
    BackupAndCopy $_.FullName ("commands\" + $_.Name)
}

# updater fora da sessao (bundle estavel) + wrappers de recuperacao -> ~\.claude\.bsaios\
$UpdaterDir = Join-Path $ClaudeHome ".bsaios\updater"
New-Item -ItemType Directory -Force $UpdaterDir | Out-Null
Remove-Item (Join-Path $UpdaterDir "lib") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $UpdaterDir "migrations") -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $RepoDir "install\lib")           (Join-Path $UpdaterDir "lib") -Recurse -Force
Copy-Item (Join-Path $RepoDir "install\migrations")    (Join-Path $UpdaterDir "migrations") -Recurse -Force
Copy-Item (Join-Path $RepoDir "install\manifest.json") (Join-Path $UpdaterDir "manifest.json") -Force
Copy-Item (Join-Path $RepoDir "harness\wrappers\*")    (Join-Path $ClaudeHome ".bsaios") -Force
Ok "updater + wrappers (.bsaios\updater; /bsaios-update no chat)"

# ---------------------------------------------------------------- 3. plugin vendorizado (robocopy: caminhos longos)
Say ""
Say "[3/7] Plugin bsaios-core -> $ClaudeHome\plugins\bsaios-marketplace"
$Market = Join-Path $ClaudeHome "plugins\bsaios-marketplace"
if (Test-Path $Market) {
    New-Item -ItemType Directory -Force (Join-Path $Backup "plugins") | Out-Null
    robocopy $Market (Join-Path $Backup "plugins\bsaios-marketplace") /E /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy falhou (codigo $LASTEXITCODE) ao fazer BACKUP do marketplace antigo - nada foi apagado." }
    Remove-Item $Market -Recurse -Force
}
robocopy (Join-Path $RepoDir "plugins") $Market /E /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy falhou (codigo $LASTEXITCODE) ao copiar o plugin." }
$SkillCount = (Get-ChildItem (Join-Path $Market "bsaios-core\skills") -Directory).Count
Ok "marketplace por diretorio copiado ($SkillCount skills no plugin; os agents vao para agents\ do CLAUDE_HOME)"

# ---------------------------------------------------------------- 4. settings + CLAUDE.md
Say ""
Say "[4/7] Gerando settings.json e CLAUDE.md"
if ($DryRun -and [string]::IsNullOrWhiteSpace($Name)) { $Name = "Dry Run"; $Role = "CI"; $Focus = "parity-check" }
if (-not $DryRun -and [string]::IsNullOrWhiteSpace($Name)) {
    $Name  = Read-Host "  Seu nome"
    $Role  = Read-Host "  Sua funcao"
    $Focus = Read-Host "  Areas de foco"
}
$Render  = Join-Path $ScriptDir "lib\render-settings.js"
$ProfilePath = Join-Path $ClaudeHome ".bsaios\profile.json"
$RenderArgs = @("--claude-home", $ClaudeHome, "--platform", "windows", "--profile", $ProfilePath)
if ($Name)  { $RenderArgs += @("--name",  $Name) }
if ($Role)  { $RenderArgs += @("--role",  $Role) }
if ($Focus) { $RenderArgs += @("--focus", $Focus) }

$SettingsDest = Join-Path $ClaudeHome "settings.json"
if (Test-Path $SettingsDest) {
    New-Item -ItemType Directory -Force $Backup | Out-Null
    Copy-Item $SettingsDest (Join-Path $Backup "settings.json") -Force
}
& node $Render (Join-Path $RepoDir "harness\settings.team.json") $SettingsDest @RenderArgs
if ($LASTEXITCODE -ne 0) { throw "render-settings falhou para settings.json" }

$ClaudeMdDest = Join-Path $ClaudeHome "CLAUDE.md"
if (Test-Path $ClaudeMdDest) {
    New-Item -ItemType Directory -Force $Backup | Out-Null
    Copy-Item $ClaudeMdDest (Join-Path $Backup "CLAUDE.md") -Force
}
& node $Render (Join-Path $RepoDir "harness\CLAUDE.md.template") $ClaudeMdDest @RenderArgs
if ($LASTEXITCODE -ne 0) { throw "render-settings falhou para CLAUDE.md" }
Ok "settings.json (GateGuard ON, hook rtk REMOVIDO no Windows - modo @RTK.md)"
Ok "CLAUDE.md"

# ---------------------------------------------------------------- 5. ferramentas externas
Say ""
Say "[5/7] Ferramentas externas (rtk, graphify, agent-browser)"
Invoke-ExtTool "rtk" "rtk" { Install-RtkWindows } { rtk init -g }
# graphify precisa de 'uv'. Se o bootstrap nao conseguiu instalar (winget quebrado), instala via o
# script oficial aqui mesmo; e poe ~/.local/bin (bin do uv e das tools) no PATH da MESMA sessao.
Invoke-ExtTool "graphify" "graphify" {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
        $env:Path = "$env:Path;" + (Join-Path $env:USERPROFILE ".local\bin")
    }
    uv tool install graphifyy
    $env:Path = "$env:Path;" + (Join-Path $env:USERPROFILE ".local\bin")
    graphify install
    graphify claude install
}
# 'npm install -g' poe o .cmd no prefixo global do npm (%APPDATA%\npm no Windows padrao). Como o
# node costuma ser machine-wide, esse dir NAO esta no PATH do usuario -> persiste (sessao + User)
# p/ o 'agent-browser' ser achado agora E ao reabrir. Usa 'cmd /c' (npm.cmd) p/ nao esbarrar na
# ExecutionPolicy do npm.ps1; fallback p/ %APPDATA%\npm.
Invoke-ExtTool "agent-browser" "agent-browser" {
    npm install -g agent-browser
    $npmBin = (cmd /c "npm config get prefix" 2>$null | Select-Object -Last 1)
    if ($npmBin) { $npmBin = $npmBin.Trim() }
    if (-not $npmBin) { $npmBin = Join-Path $env:APPDATA "npm" }
    $env:Path = "$env:Path;$npmBin"
    $u = [Environment]::GetEnvironmentVariable("Path","User")
    if (($u -split ';') -notcontains $npmBin) { [Environment]::SetEnvironmentVariable("Path", ($u.TrimEnd(';') + ";" + $npmBin), "User") }
    agent-browser install
    npx -y skills add vercel-labs/agent-browser -a claude-code -g -y
    npx -y skills remove find-skills -g -y 2>$null
}

# ---------------------------------------------------------------- 6. extras
Say ""
Say "[6/7] Extras"
if ($DryRun) {
    Ok "dry-run: pulando PyYAML"
} elseif (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Warn "python ausente - depois de instalar, rode: python -m pip install pyyaml"
} else {
    cmd /c "python -c ""import yaml"" >nul 2>nul"
    if ($LASTEXITCODE -eq 0) { Ok "PyYAML ja presente" }
    else {
        # python machine-wide tem site-packages nao-gravavel -> --user explicito (o pip cai nele de
        # qualquer forma). NAO engole o erro: captura e mostra a ultima linha real se falhar.
        $pipOut = cmd /c "python -m pip install --user --disable-pip-version-check pyyaml 2>&1"
        cmd /c "python -c ""import yaml"" >nul 2>nul"
        if ($LASTEXITCODE -eq 0) { Ok "PyYAML instalado" }
        else {
            $pipErr = ($pipOut | Where-Object { $_ -match '\S' } | Select-Object -Last 1)
            Warn "nao consegui instalar PyYAML: $pipErr"
            Warn "hook validate-agent-frontmatter fica inerte ate: python -m pip install --user pyyaml"
        }
    }
}

# ---------------------------------------------------------------- 7. estado (.bsaios) - ULTIMO passo
Say ""
Say "[7/7] Estado -> $ClaudeHome\.bsaios"
$StateArgs = @("--claude-home", $ClaudeHome, "--platform", "windows", "--repo", $RepoDir, "--manifest", (Join-Path $RepoDir "install\manifest.json"))
if ($Name)  { $StateArgs += @("--name",  $Name) }
if ($Role)  { $StateArgs += @("--role",  $Role) }
if ($Focus) { $StateArgs += @("--focus", $Focus) }
& node (Join-Path $ScriptDir "lib\bsaios-state.js") @StateArgs
if ($LASTEXITCODE -ne 0) { throw "bsaios-state falhou ao gravar o estado" }
Ok "version.json + profile.json + manifest.installed.json (carimbo por ultimo)"
& node (Join-Path $ScriptDir "lib\verify-harness.js") --claude-home $ClaudeHome
if ($LASTEXITCODE -ne 0) { Warn "health check reportou problemas (veja acima) - o install foi concluido, mas verifique" }

Say ""
Say "== Pronto =="
Say "Backup do que foi sobrescrito: $Backup (se existia algo)"
Say "Proximos passos:"
Say "  1. claude doctor                  # saude do Claude Code"
Say "  2. claude plugin list             # deve listar bsaios-core"
Say "  3. abra uma sessao e rode /bsaios-core:ecc-guide para conhecer as skills"
Say "MCPs opcionais (dieta de MCP - so se precisar):"
Say "  claude mcp add --scope user context7 -- cmd /c npx -y @upstash/context7-mcp@latest"
Say "  claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest"
