# Black Sheep AIOS - bootstrap Windows (o degrau ANTERIOR ao install.ps1).
#
# Comando unico (do README):
#   powershell -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/bbrak/black-sheep-aios/stable/install/bootstrap.ps1 | iex"
#
# Resolve o que o install.ps1 so SUGERE: garante um gerenciador de pacotes (winget, fallback scoop) ->
# git/node -> Claude Code, clona o harness em ~\black-sheep-aios e chama install\install.ps1. Zero
# duplicacao: toda a logica de harness fica la. Paridade com o install/bootstrap.sh (macOS).
#
# Invariantes (Fase 0 §3 -> §5.3 do spec):
#   - Idempotente: cada etapa instala SO SE FALTAR; rodar 2x nao duplica nada.
#   - Fail-soft por etapa: se um item falha, avisa + da o comando manual + CONTINUA.
#   - Admin: claude e scoop instalam no usuario; o winget PODE abrir um dialogo UAC ao instalar
#     git/node. O script AVISA antes de instalar (nao ha admin escondido).
#   - Recarrega o PATH na mesma sessao (dor D3) e, no fim, manda reabrir o PowerShell.
#   - ExecutionPolicy Bypass SO neste processo (dor D5, guarda preventiva) - nao altera a maquina.
#
# Flags (funcionam ao rodar o arquivo; via 'iwr | iex' usam os defaults):
#   -DryRun      nao instala nada; so checa e imprime o que FARIA (prova idempotencia; sem efeito colateral).
#   -Dir <d>     pasta do harness (default ~\black-sheep-aios).
#   -Yes         nao pergunta na instalacao de ferramentas externas (repassa -Yes ao install.ps1).
#   -SkipTools   nao instala ferramentas externas (rtk/graphify/agent-browser); repassa ao install.ps1.
#   -Name/-Role/-Focus  identidade (opcional; se ausente, o install.ps1 pergunta). Uso p/ automacao/CI.
# Env de teste: BSAIOS_REPO_URL (default repo publico), BSAIOS_UPDATE_REF (default stable),
#               BSAIOS_CLAUDE_HOME (isola o ~\.claude do install.ps1; usado pelos testes).

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$Dir = (Join-Path $env:USERPROFILE "black-sheep-aios"),
    [switch]$Yes,
    [switch]$SkipTools,
    [string]$Name = "",
    [string]$Role = "",
    [string]$Focus = ""
)

# ExecutionPolicy so p/ este processo (dor D5) e fail-soft (um erro nao aborta o script).
try { Set-ExecutionPolicy -Scope Process Bypass -Force -ErrorAction SilentlyContinue } catch {}
$ErrorActionPreference = "Continue"

function Say($m)  { Write-Host $m }
function Ok($m)   { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!!] $m" -ForegroundColor Yellow }
function Info($m) { Write-Host "  [..] $m" -ForegroundColor Cyan }
function Have($b) { [bool](Get-Command $b -ErrorAction SilentlyContinue) }
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
}

Say ""
Say "== Black Sheep AIOS - instalacao automatica (Windows) =="
Say "   Instala, SO SE FALTAR: gerenciador de pacotes (winget/scoop), git, node, Claude Code, e o harness em $Dir."
Say "   Cada passo avisa antes de agir e CONTINUA mesmo se um item falhar (nada fica pela metade)."
Say "   Dica: cole este comando no PowerShell (nao no Prompt de Comando antigo)."
if ($DryRun) { Say "   (DRY-RUN: nada sera instalado - apenas mostro o que faria.)" }
Say ""

# ---------------------------------------------------------------- 1. gerenciador de pacotes
Say "[1/5] Gerenciador de pacotes (winget / scoop)"
$UseScoop = $false
if (Have winget) {
    Ok "winget presente"
} elseif ($DryRun) {
    Warn "winget ausente (dry-run) - faria: tentar scoop (irm get.scoop.sh | iex) ou instruir o App Installer na Microsoft Store"
} else {
    Warn "winget (App Installer) ausente. Tentando o scoop (nao precisa de admin)..."
    if (-not (Have scoop)) {
        try {
            Invoke-RestMethod get.scoop.sh | Invoke-Expression
            Update-SessionPath
            if (Have scoop) { Ok "scoop instalado" }
        } catch { Warn "scoop falhou (fail-soft) - instale o 'App Installer' na Microsoft Store e rode de novo. $($_.Exception.Message)" }
    }
    if (Have scoop) { $UseScoop = $true; Ok "usando scoop como gerenciador de pacotes" }
    else { Warn "sem winget nem scoop - git/node vao falhar; instale o 'App Installer' (Microsoft Store) e rode de novo." }
}

# ---------------------------------------------------------------- 2. git + node (so o que faltar)
Say ""
Say "[2/5] git + node"
if (-not $DryRun -and -not $UseScoop -and ((-not (Have git)) -or (-not (Have node)))) {
    Say "   Se o Windows abrir um dialogo de 'Controle de Conta de Usuario' (UAC) pedindo permissao para"
    Say "   instalar git/node, pode clicar em 'Sim' - e o gerenciador de pacotes instalando esses programas."
}
function Install-Pkg($bin, $wingetId, $scoopId) {
    if (Have $bin) { Ok "$bin ja instalado"; return }
    if ($DryRun) { Warn "$bin ausente (dry-run) - faria: winget install $wingetId (ou scoop install $scoopId)"; return }
    Info "instalando $bin..."
    try {
        if ($UseScoop) { scoop install $scoopId }
        elseif (Have winget) { winget install --id $wingetId -e --source winget --accept-source-agreements --accept-package-agreements }
        else { Warn "$bin ausente e sem gerenciador de pacotes (fail-soft) - instale git/node manualmente"; return }
        Update-SessionPath
        if (Have $bin) { Ok "$bin instalado" } else { Warn "$bin instalou mas nao esta no PATH - reabra o PowerShell" }
    } catch { Warn "$bin falhou (fail-soft) - $($_.Exception.Message)" }
}
Install-Pkg "git"  "Git.Git"           "git"
Install-Pkg "node" "OpenJS.NodeJS.LTS" "nodejs-lts"

# ---------------------------------------------------------------- 3. Claude Code
Say ""
Say "[3/5] Claude Code"
if (Have claude) {
    Ok "Claude Code ja instalado ($(try { (claude --version 2>$null) } catch { '?' }))"
} elseif ($DryRun) {
    Warn "claude ausente (dry-run) - faria: irm https://claude.ai/install.ps1 | iex"
} else {
    Info "instalando o Claude Code (nao precisa de admin)..."
    try { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression; Update-SessionPath }
    catch {
        Warn "instalador do Claude retornou erro (fail-soft) - manual: irm https://claude.ai/install.ps1 | iex. $($_.Exception.Message)"
        Warn "Se o download foi bloqueado por protecao do Windows (SmartScreen/antivirus): o instalador oficial da Anthropic e confiavel; permita e rode de novo."
    }
    if (Have claude) {
        Ok "Claude Code instalado"
    } else {
        Warn "claude instalou mas nao aparece no PATH nesta sessao (dor D3) - FECHE e reabra o PowerShell."
    }
}

# ---------------------------------------------------------------- 4. harness -> ~\black-sheep-aios
Say ""
Say "[4/5] Harness -> $Dir"
$RepoUrl = if ($env:BSAIOS_REPO_URL)   { $env:BSAIOS_REPO_URL }   else { "https://github.com/bbrak/black-sheep-aios.git" }
$Ref     = if ($env:BSAIOS_UPDATE_REF) { $env:BSAIOS_UPDATE_REF } else { "stable" }
if (Test-Path (Join-Path $Dir ".git")) {
    if ($DryRun) {
        Ok "harness ja existe em $Dir (dry-run: faria git fetch --tags --force + checkout $Ref)"
    } else {
        # release = mover a tag `stable`: precisa de --tags --force. NAO usar git pull (checkout de tag
        # fica em detached HEAD). try/catch NAO pega exit code de comando nativo -> checar $LASTEXITCODE.
        Info "harness ja clonado - atualizando (fetch --tags --force + checkout $Ref)..."
        git -C $Dir fetch --all --tags --force -q 2>$null
        $fetchOk = ($LASTEXITCODE -eq 0)
        if ($fetchOk) { git -C $Dir checkout -q $Ref 2>$null }
        if ($fetchOk -and $LASTEXITCODE -eq 0) { Ok "harness atualizado em $Dir ($Ref)" }
        else { Warn "atualizacao falhou (fail-soft) - sigo com o que ja esta em $Dir" }
    }
} elseif ($DryRun) {
    Warn "harness ausente (dry-run) - faria: git clone $RepoUrl $Dir"
} elseif (Have git) {
    Info "clonando o harness ($Ref) em $Dir..."
    try {
        git clone -q --branch $Ref $RepoUrl $Dir 2>$null
        if (-not (Test-Path (Join-Path $Dir ".git"))) { git clone -q $RepoUrl $Dir }
        if (Test-Path (Join-Path $Dir ".git")) { Ok "harness clonado em $Dir" }
        else { Warn "git clone falhou (fail-soft) - verifique a rede e rode de novo" }
    } catch { Warn "git clone falhou (fail-soft) - $($_.Exception.Message)" }
} else {
    Warn "git ausente - nao da pra clonar. Instale git (passo 2) e rode de novo."
}

# ---------------------------------------------------------------- 5. install.ps1 (escreve o harness)
Say ""
Say "[5/5] Instalador do harness (install.ps1)"
$InstallPs1 = Join-Path $Dir "install\install.ps1"
if ($DryRun) {
    if ($env:BSAIOS_CLAUDE_HOME -and (Test-Path $InstallPs1)) {
        Info "dry-run isolado: install.ps1 -DryRun -ClaudeHome $env:BSAIOS_CLAUDE_HOME"
        & $InstallPs1 -DryRun -ClaudeHome $env:BSAIOS_CLAUDE_HOME
    } else {
        Warn "dry-run: pularia a chamada real ao install.ps1 (faria: $InstallPs1)"
    }
} elseif (Test-Path $InstallPs1) {
    Info "rodando install.ps1 (resolve rtk/graphify/agent-browser e escreve o harness)..."
    $iargs = @()
    if ($env:BSAIOS_CLAUDE_HOME) { $iargs += @("-ClaudeHome", $env:BSAIOS_CLAUDE_HOME) }
    if ($Yes)       { $iargs += "-Yes" }
    if ($SkipTools) { $iargs += "-SkipTools" }
    if ($Name)  { $iargs += @("-Name",  $Name) }
    if ($Role)  { $iargs += @("-Role",  $Role) }
    if ($Focus) { $iargs += @("-Focus", $Focus) }
    try { & $InstallPs1 @iargs } catch { Warn "install.ps1 reportou problema (veja acima) - o bootstrap terminou, mas verifique. $($_.Exception.Message)" }
} else {
    Warn "nao encontrei $InstallPs1 - o clone do harness pode ter falhado. Rode o bootstrap de novo."
}

# ---------------------------------------------------------------- done-signal (dor N4/N8: sem sinal de fim)
Say ""
Say "============================================================"
Say " TUDO PRONTO - o Black Sheep AIOS esta instalado."
Say "============================================================"
if ($DryRun) {
    Say " (isto foi um DRY-RUN - nada foi instalado de verdade.)"
} else {
    Say " Pode PARAR aqui - nao precisa mandar mais nenhum comando."
    Say ""
    Say " 1) FECHE este PowerShell e abra um NOVO (pra tudo entrar no PATH)."
    Say " 2) No PowerShell novo, digite:   claude"
    Say " 3) Dentro do Claude, rode:       /bsaios-core:ecc-guide"
}
Say ""
