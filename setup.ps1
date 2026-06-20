# mark-coach-mcp setup for Windows (PowerShell)
# Equivalente nativo de setup.sh

$ErrorActionPreference = 'Stop'

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$UvBin   = Join-Path $env:USERPROFILE '.local\bin\uv.exe'

function Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Info($msg)  { Write-Host "  $msg" -ForegroundColor DarkGray }
function ErrLine($msg) { Write-Host "  [X] $msg" -ForegroundColor Red }

function Is-Interactive {
    return [Environment]::UserInteractive -and ($Host.UI.RawUI.KeyAvailable -or $true)
}

function Ask-YesNo($prompt, $default = 'y') {
    if (-not [Environment]::UserInteractive) { return ($default -eq 'y') }
    $opts = if ($default -eq 'y') { '[Y/n]' } else { '[y/N]' }
    $a = Read-Host "  $prompt $opts"
    if ([string]::IsNullOrWhiteSpace($a)) { $a = $default }
    return $a -match '^[YySs]'
}

Write-Host "`nmark-coach-mcp setup" -ForegroundColor White
Info "Repo: $RepoDir"

# ---------- Dependencies ---------------------------------------------------

Step "Verificando dependencias"

if (-not (Test-Path $UvBin)) {
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($uvCmd) {
        $UvBin = $uvCmd.Source
    } else {
        Warn "uv no instalado - instalando..."
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" | Out-Null
    }
}
if (-not (Test-Path $UvBin)) {
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($uvCmd) { $UvBin = $uvCmd.Source }
}
if (-not (Test-Path $UvBin)) {
    ErrLine "No se pudo instalar uv. Instalalo a mano: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
}
Ok "uv -> $UvBin"

$ytDlpCmd = Get-Command yt-dlp -ErrorAction SilentlyContinue
if (-not $ytDlpCmd) {
    Warn "yt-dlp no instalado - instalando via uv tool..."
    & $UvBin tool install yt-dlp | Out-Null
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
    $ytDlpCmd = Get-Command yt-dlp -ErrorAction SilentlyContinue
}
if (-not $ytDlpCmd) {
    ErrLine "No se pudo instalar yt-dlp."
    exit 1
}
Ok "yt-dlp -> $($ytDlpCmd.Source)"

# ---------- Python deps ----------------------------------------------------

Step "Instalando dependencias Python"
Push-Location $RepoDir
& $UvBin sync --quiet
Pop-Location
Ok "Entorno virtual sincronizado"

# ---------- Transcripts ----------------------------------------------------

Step "Transcripts"
$TranscriptsDir = Join-Path $RepoDir 'transcripts'
if (-not (Test-Path $TranscriptsDir)) { New-Item -ItemType Directory -Path $TranscriptsDir | Out-Null }

$VttFiles = @(Get-ChildItem -Path $TranscriptsDir -Filter '*.vtt' -Recurse -ErrorAction SilentlyContinue)
$VttCount = $VttFiles.Count

if ($VttCount -eq 0) {
    Info "No hay transcripts en $TranscriptsDir"
    if (Ask-YesNo "Descargar transcripts del canal Mark Builds Brands ahora?") {
        Info "Descargando transcripts (esto puede tardar varios minutos)..."
        $outTpl = Join-Path $TranscriptsDir '%(title)s [%(id)s].%(ext)s'
        try {
            & yt-dlp --write-auto-sub --sub-lang en --skip-download --output $outTpl "https://www.youtube.com/@markbuildsbrands/videos" *>$null
        } catch { Warn "yt-dlp termino con avisos - continuamos" }
        $VttCount = (Get-ChildItem -Path $TranscriptsDir -Filter '*.vtt' -Recurse).Count
        Ok "$VttCount archivos .vtt descargados"
    } else {
        Warn "Salteamos la descarga. Copia tus .vtt a $TranscriptsDir y volve a correr setup.ps1"
    }
} else {
    Ok "$VttCount archivos .vtt encontrados"
}

# ---------- Indexing -------------------------------------------------------

if ($VttCount -gt 0) {
    Step "Indexando transcripts en la base de conocimiento"
    Push-Location $RepoDir
    & $UvBin run src/indexer.py $TranscriptsDir | Select-Object -Last 3
    Pop-Location
}

# ---------- Claude integration --------------------------------------------

Step "Configurando Claude"

$ClaudeCodeFound    = $false
$ClaudeDesktopFound = $false

$claudeCli = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCli) {
    $ClaudeCodeFound = $true
    Info "Claude Code detectado"

    $skillDst = Join-Path $env:USERPROFILE '.claude\skills\mark-coach'
    if (-not (Test-Path $skillDst)) { New-Item -ItemType Directory -Path $skillDst -Force | Out-Null }
    Copy-Item -Path (Join-Path $RepoDir 'skills\mark-coach.md') -Destination (Join-Path $skillDst 'SKILL.md') -Force
    Ok "Skill instalado en ~/.claude/skills/mark-coach/SKILL.md"

    & claude mcp get mark-coach 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { & claude mcp remove -s user mark-coach 2>$null | Out-Null }
    & claude mcp add -s user mark-coach -- $UvBin --directory $RepoDir run src/server.py | Out-Null
    Ok "MCP registrado en Claude Code (scope: user)"
} else {
    Info "Claude Code no detectado - salteamos su configuracion"
}

$ClaudeDesktopConfig = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
$ClaudeDesktopDir    = Split-Path -Parent $ClaudeDesktopConfig

if (Test-Path $ClaudeDesktopDir) {
    $ClaudeDesktopFound = $true
    Info "Claude Desktop detectado"

    if (-not (Test-Path $ClaudeDesktopConfig)) { '{}' | Set-Content -Path $ClaudeDesktopConfig -Encoding UTF8 }

    $cfgRaw = Get-Content -Raw -Path $ClaudeDesktopConfig
    try { $cfg = $cfgRaw | ConvertFrom-Json -ErrorAction Stop }
    catch { Warn "claude_desktop_config.json invalido - sobreescribiendo"; $cfg = [pscustomobject]@{} }

    if (-not $cfg.PSObject.Properties.Match('mcpServers').Count) {
        $cfg | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $entry = [pscustomobject]@{
        command = $UvBin
        args    = @('--directory', $RepoDir, 'run', 'src/server.py')
    }
    if ($cfg.mcpServers.PSObject.Properties.Match('mark-coach').Count) {
        $cfg.mcpServers.'mark-coach' = $entry
    } else {
        $cfg.mcpServers | Add-Member -NotePropertyName 'mark-coach' -NotePropertyValue $entry -Force
    }
    $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $ClaudeDesktopConfig -Encoding UTF8
    Ok "MCP agregado a claude_desktop_config.json"
} else {
    Info "Claude Desktop no detectado - salteamos su configuracion"
}

# ---------- Summary --------------------------------------------------------

Write-Host "`n[OK] Setup completo`n" -ForegroundColor Green

Write-Host "Proximos pasos:" -ForegroundColor White
if ($ClaudeCodeFound) {
    Write-Host "  - Claude Code: reinicia la sesion y usa " -NoNewline
    Write-Host "/mark-coach" -ForegroundColor Yellow
}
if ($ClaudeDesktopFound) {
    Write-Host "  - Claude Desktop: cerralo (icono de bandeja > Quit) y abrilo de nuevo"
}
if (-not $ClaudeCodeFound -and -not $ClaudeDesktopFound) {
    Warn "No detectamos Claude Code ni Claude Desktop instalados."
}

Info "Para agregar mas videos en el futuro: copia los .vtt a transcripts/ y corre .\setup.ps1"
