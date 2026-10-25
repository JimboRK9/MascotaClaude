# Quita Kitsune del usuario actual: cierra el zorro, quita sus hooks de settings.json
# (con respaldo, sin tocar los hooks ajenos), la extensión, los accesos directos y sus archivos.
#   powershell -ExecutionPolicy Bypass -File .\desinstalar.ps1
$ErrorActionPreference = 'Stop'
$destino = Join-Path $env:USERPROFILE '.claude\kitsune'

function Paso($texto) { Write-Host "`n> $texto" -ForegroundColor Cyan }

Paso 'Cerrando Kitsune'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -match 'kitsune\.ps1' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Paso 'Quitando los hooks de ~\.claude\settings.json'
if (Get-Command node -ErrorAction SilentlyContinue) {
    node (Join-Path $PSScriptRoot 'hooks.mjs') desinstalar
} else {
    Write-Host '  Sin Node: quita a mano las entradas con kitsune/estado.mjs del bloque "hooks".' -ForegroundColor Yellow
}

if (Get-Command code -ErrorAction SilentlyContinue) {
    Paso 'Quitando la extensión de VS Code'
    & { $ErrorActionPreference = 'Continue'; code --uninstall-extension jgomez.kitsune-puente 2>&1 | Out-Null }
}

Paso 'Borrando accesos directos'
foreach ($carpeta in @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
        [Environment]::GetFolderPath('Desktop'))) {
    $lnk = Join-Path $carpeta 'Kitsune.lnk'
    if (Test-Path $lnk) { Remove-Item $lnk; Write-Host "  $lnk" }
}

Paso "Borrando $destino"
if (Test-Path $destino) { Remove-Item $destino -Recurse -Force }

Write-Host "`nKitsune desinstalado. Recarga VS Code para descargar la extensión." -ForegroundColor Green
