# Black Sheep AIOS - instalador Windows
# Uso:  .\install.ps1 [-ClaudeHome <dir>] [-DryRun] [-Name "..."] [-Role "..."] [-Focus "..."]
#
# O que faz:
#   1. Checa pre-requisitos (git, node, python, uv, claude) e ferramentas externas (rtk, graphify,
#      agent-browser). NAO instala nada sozinho: imprime o comando certo do manifest.json.
#   2. Copia o harness para ~/.claude (backup de tudo que for sobrescrito).
#   3. Copia plugins/ para ~/.claude/plugins/bsaios-marketplace (plugin vendorizado bsaios-core)
#      usando robocopy (caminhos longos).
#   4. Gera ~/.claude/settings.json e ~/.claude/CLAUDE.md a partir dos templates (GateGuard ON;
#      no Windows nativo o hook do RTK e REMOVIDO - RTK opera via @RTK.md no CLAUDE.md).
#   5. Instala PyYAML (hook validate-agent-frontmatter) - pulado no -DryRun.
#
# -DryRun: exige -ClaudeHome, nao pergunta nada, nao instala pacote.

[CmdletBinding()]
param(
    [string]$ClaudeHome = (Join-Path $env:USERPROFILE ".claude"),
    [switch]$DryRun,
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

Say ""
Say "== Black Sheep AIOS - instalador Windows =="
Say "   repo:        $RepoDir"
if ($DryRun) { Say "   CLAUDE_HOME: $ClaudeHome (DRY-RUN)" } else { Say "   CLAUDE_HOME: $ClaudeHome" }
Say ""

# ---------------------------------------------------------------- 1. pre-requisitos
Say "[1/5] Pre-requisitos"
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
Need "rtk"           "baixar rtk-x86_64-pc-windows-msvc.zip de github.com/rtk-ai/rtk/releases, extrair para o PATH, rodar: rtk init -g   (fail-soft: pode instalar depois)"
Need "graphify"      "uv tool install graphifyy; graphify install; graphify claude install   (opcional)"
Need "agent-browser" "npm install -g agent-browser; agent-browser install; npx skills add vercel-labs/agent-browser   (opcional)"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "node e obrigatorio para o instalador." }
if ($script:Missing -gt 0) { Warn "$($script:Missing) item(ns) ausente(s) - o instalador segue; instale-os depois (lista completa: install\manifest.json)." }

# ---------------------------------------------------------------- 2. harness -> CLAUDE_HOME
Say ""
Say "[2/5] Harness -> $ClaudeHome"
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

# ---------------------------------------------------------------- 3. plugin vendorizado (robocopy: caminhos longos)
Say ""
Say "[3/5] Plugin bsaios-core -> $ClaudeHome\plugins\bsaios-marketplace"
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
Say "[4/5] Gerando settings.json e CLAUDE.md"
if (-not $DryRun -and [string]::IsNullOrWhiteSpace($Name)) {
    $Name  = Read-Host "  Seu nome"
    $Role  = Read-Host "  Sua funcao"
    $Focus = Read-Host "  Areas de foco"
}
$Render  = Join-Path $ScriptDir "lib\render-settings.js"
$RenderArgs = @("--claude-home", $ClaudeHome, "--platform", "windows")
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

# ---------------------------------------------------------------- 5. extras
Say ""
Say "[5/5] Extras"
if ($DryRun) {
    Ok "dry-run: pulando PyYAML"
} elseif (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Warn "python ausente - depois de instalar, rode: python -m pip install pyyaml"
} else {
    cmd /c "python -c ""import yaml"" >nul 2>nul"
    if ($LASTEXITCODE -eq 0) { Ok "PyYAML ja presente" }
    else {
        cmd /c "python -m pip install pyyaml >nul 2>nul"
        cmd /c "python -c ""import yaml"" >nul 2>nul"
        if ($LASTEXITCODE -eq 0) { Ok "PyYAML instalado" }
        else { Warn "nao consegui instalar PyYAML - o hook validate-agent-frontmatter fica inerte ate: python -m pip install pyyaml" }
    }
}

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
