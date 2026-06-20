# mark-coach-mcp one-line installer for Windows (PowerShell)
# Uso:
#   iwr -useb https://raw.githubusercontent.com/BlueNacho/mark-coach-mcp/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$RepoUrl    = 'https://github.com/BlueNacho/mark-coach-mcp.git'
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:USERPROFILE 'mark-coach-mcp' }

Write-Host "`nmark-coach-mcp - one-line installer (Windows)" -ForegroundColor White
Write-Host "Destino: $InstallDir`n"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "git no esta instalado. Instalalo desde https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

if (Test-Path (Join-Path $InstallDir '.git')) {
    Write-Host "Repo ya existe en $InstallDir - haciendo git pull..." -ForegroundColor Yellow
    git -C $InstallDir pull --rebase --autostash
} else {
    git clone $RepoUrl $InstallDir
}

Push-Location $InstallDir
powershell -ExecutionPolicy Bypass -File .\setup.ps1
Pop-Location

Write-Host "`nInstalacion completa." -ForegroundColor Green
Write-Host "Repo en: $InstallDir`n"
