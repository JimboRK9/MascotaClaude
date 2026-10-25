# Quita Kitsune del usuario actual: cierra el zorro, quita sus hooks de settings.json
# (con respaldo, sin tocar los hooks ajenos), la extensión, los accesos directos de versiones
# anteriores y sus archivos.
#   powershell -ExecutionPolicy Bypass -File .\desinstalar.ps1
$ErrorActionPreference = 'Stop'
$destino = Join-Path $env:USERPROFILE '.claude\kitsune'

. (Join-Path $PSScriptRoot 'comun.ps1')

function Paso($texto) { Write-Host "`n> $texto" -ForegroundColor Cyan }

Paso 'Cerrando Kitsune'
Asegurar-Cerrado

Paso 'Quitando los hooks de ~\.claude\settings.json'
if (Get-Command node -ErrorAction SilentlyContinue) {
    node (Join-Path $PSScriptRoot 'hooks.mjs') desinstalar
    # Sin hooks quitados no se borra nada: quedarían apuntando a un estado.mjs inexistente.
    if ($LASTEXITCODE) { throw 'No se pudieron quitar los hooks; no se borró nada más (settings.json tiene respaldo).' }
} else {
    Write-Host '  Sin Node: quita a mano las entradas con kitsune/estado.mjs del bloque "hooks".' -ForegroundColor Yellow
}

if (Get-Command code -ErrorAction SilentlyContinue) {
    Paso 'Quitando la extensión de VS Code'
    & { $ErrorActionPreference = 'Continue'; code --uninstall-extension jgomez.kitsune-puente 2>&1 | Out-Null }
}

Paso 'Borrando accesos directos de versiones anteriores'
Quitar-Accesos

Paso "Borrando $destino"
# Un hook que corrió antes de quitarlos pudo volver a abrir el zorro.
$borrado = $false
if (-not (Cerrar-Kitsune)) {
    Write-Host '  Kitsune se volvió a abrir: ciérralo con clic derecho y borra la carpeta a mano.' -ForegroundColor Yellow
} else {
    try {
        if (Test-Path $destino) { Remove-Item $destino -Recurse -Force }
        $borrado = $true
    } catch {
        Write-Host "  No se pudo borrar del todo: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host '  Cierra el zorro si está abierto y borra la carpeta a mano.' -ForegroundColor Yellow
    }
}

if ($borrado) {
    Write-Host "`nKitsune desinstalado. Recarga VS Code para descargar la extensión." -ForegroundColor Green
} else {
    Write-Host "`nKitsune desinstalado salvo la carpeta $destino. Recarga VS Code para descargar la extensión." -ForegroundColor Yellow
}
