# Instala Kitsune para el usuario actual. Correr desde la carpeta descomprimida:
#   powershell -ExecutionPolicy Bypass -File .\instalar.ps1
# Se puede correr de nuevo para actualizar: reemplaza los archivos y no duplica los hooks.
$ErrorActionPreference = 'Stop'
$origen = $PSScriptRoot
$destino = Join-Path $env:USERPROFILE '.claude\kitsune'

function Paso($texto) { Write-Host "`n> $texto" -ForegroundColor Cyan }

Paso 'Revisando requisitos'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Falta Node.js (https://nodejs.org). Instálalo y vuelve a correr este script.'
}
Write-Host "  Node $(node --version)"
$hayCode = [bool](Get-Command code -ErrorAction SilentlyContinue)
if ($hayCode) { Write-Host '  VS Code encontrado' } else { Write-Host '  VS Code no encontrado: se omite la extensión (la lista del zorro no podrá llevarte a la terminal)' -ForegroundColor Yellow }

Paso 'Cerrando Kitsune si está abierto'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -match 'kitsune\.ps1' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Paso "Copiando archivos a $destino"
New-Item -ItemType Directory -Force -Path $destino | Out-Null
foreach ($f in 'estado.mjs', 'kitsune.ps1', 'kitsune-puente-0.0.1.vsix') {
    Copy-Item (Join-Path $origen $f) $destino -Force
    Write-Host "  $f"
}

Paso 'Agregando los hooks a ~\.claude\settings.json'
node (Join-Path $origen 'hooks.mjs') instalar
if ($LASTEXITCODE) { throw 'No se pudieron agregar los hooks. settings.json quedó como estaba (hay respaldo).' }

if ($hayCode) {
    Paso 'Instalando la extensión de VS Code'
    # code escribe avisos en stderr; con 'Stop' Windows PowerShell los volveria errores.
    & { $ErrorActionPreference = 'Continue'; code --install-extension (Join-Path $destino 'kitsune-puente-0.0.1.vsix') --force 2>&1 | Out-Null }
}

Paso 'Creando accesos directos (Inicio y Escritorio)'
$argumentos = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$destino\kitsune.ps1`""
$shell = New-Object -ComObject WScript.Shell
foreach ($carpeta in @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
        [Environment]::GetFolderPath('Desktop'))) {
    $lnk = $shell.CreateShortcut((Join-Path $carpeta 'Kitsune.lnk'))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = $argumentos
    $lnk.WorkingDirectory = $destino
    $lnk.Description = 'Abrir Kitsune'
    $lnk.Save()
    Write-Host "  $carpeta\Kitsune.lnk"
}

Paso 'Abriendo Kitsune'
Start-Process powershell.exe -ArgumentList $argumentos

Write-Host "`nListo." -ForegroundColor Green
Write-Host '  - Recarga VS Code (Ctrl+Shift+P > Developer: Reload Window) para activar la extensión.'
Write-Host '  - Las sesiones de Claude Code que abras desde ahora aparecen como colas; las ya abiertas, al reiniciarlas.'
