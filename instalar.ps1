# Instala Kitsune para el usuario actual. Correr desde la carpeta descomprimida:
#   powershell -ExecutionPolicy Bypass -File .\instalar.ps1
# Se puede correr de nuevo para actualizar: reemplaza los archivos y no duplica los hooks.
# No crea accesos directos ni arranque con Windows: el hook (estado.mjs) abre el zorro al iniciar
# una sesión o escribirle. Un instalador que registra un PowerShell oculto para arrancar con
# Windows es lo que Kaspersky marcó como PDM:Trojan.Win32.Generic (2026-10-25), y un acceso
# directo a PowerShell deja abierta una ventana de Windows Terminal en Windows 11.
$ErrorActionPreference = 'Stop'
$origen = $PSScriptRoot
$destino = Join-Path $env:USERPROFILE '.claude\kitsune'
. (Join-Path $origen 'comun.ps1')

function Paso($texto) { Write-Host "`n> $texto" -ForegroundColor Cyan }

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

Paso 'Quitando accesos directos de versiones anteriores'
Quitar-Accesos

# No se abre el zorro desde aquí: lanzarlo oculto desde el instalador es parte de lo que el
# antivirus marcó. Lo abre el hook.
Write-Host "`nListo." -ForegroundColor Green
Write-Host '  - El zorro aparece cuando inicias una sesión de Claude Code o le escribes a una.'
Write-Host '  - Recarga VS Code (Ctrl+Shift+P > Developer: Reload Window) para activar la extensión.'
Write-Host '  - Las sesiones que ya estaban abiertas antes de la primera instalación aparecen al reiniciarlas.'
