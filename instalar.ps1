# Instala Kitsune para el usuario actual. Correr desde la carpeta descomprimida:
#   powershell -ExecutionPolicy Bypass -File .\instalar.ps1 [-ConInicio]
# Se puede correr de nuevo para actualizar: reemplaza los archivos y no duplica los hooks.
# -ConInicio agrega un acceso directo en Inicio para que arranque con Windows. Es opcional porque
# un script descargado que se registra para arrancar oculto es lo que los antivirus marcan como
# troyano (Kaspersky lo detectó como PDM:Trojan.Win32.Generic el 2026-10-25).
param([switch]$ConInicio)
$ErrorActionPreference = 'Stop'
$origen = $PSScriptRoot
$destino = Join-Path $env:USERPROFILE '.claude\kitsune'
$escritorio = [Environment]::GetFolderPath('Desktop')
. (Join-Path $origen 'comun.ps1')

function Paso($texto) { Write-Host "`n> $texto" -ForegroundColor Cyan }

function Crear-Acceso($carpeta) {
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $carpeta 'Kitsune.lnk'))
    $lnk.TargetPath = 'powershell.exe'
    $lnk.Arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$destino\kitsune.ps1`""
    $lnk.WorkingDirectory = $destino
    $lnk.Description = 'Abrir Kitsune'
    $lnk.Save()
    Write-Host "  $carpeta\Kitsune.lnk"
}

Paso 'Revisando requisitos'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Falta Node.js (https://nodejs.org). Instálalo y vuelve a correr este script.'
}
Write-Host "  Node $(node --version)"
$hayCode = [bool](Get-Command code -ErrorAction SilentlyContinue)
if ($hayCode) { Write-Host '  VS Code encontrado' } else { Write-Host '  VS Code no encontrado: se omite la extensión (la lista del zorro no podrá llevarte a la terminal)' -ForegroundColor Yellow }

Paso 'Cerrando Kitsune si está abierto'
Asegurar-Cerrado

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

Paso 'Creando el acceso directo del escritorio'
Crear-Acceso $escritorio

if ($ConInicio) {
    Paso 'Agregando el arranque con Windows'
    Crear-Acceso $inicio
} elseif (Test-Path (Join-Path $inicio 'Kitsune.lnk')) {
    # Una instalación anterior lo creó sin preguntar: se conserva tal cual, sin reescribirlo.
    Write-Host "`n  Se conserva el arranque con Windows de una instalación anterior (desinstalar.ps1 lo quita)."
}

# No se abre el zorro desde aquí: lanzarlo oculto desde el instalador es parte de lo que el
# antivirus marcó. Abrirlo con el acceso directo no despierta alertas.
Write-Host "`nListo." -ForegroundColor Green
Write-Host '  - Abre Kitsune con el acceso directo del escritorio.'
Write-Host '  - Recarga VS Code (Ctrl+Shift+P > Developer: Reload Window) para activar la extensión.'
Write-Host '  - Las sesiones de Claude Code que abras desde ahora aparecen como colas; las ya abiertas, al reiniciarlas.'
