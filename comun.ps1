# Compartido por instalar.ps1 y desinstalar.ps1, que lo cargan con dot-source.

# Las versiones 0.1.0 y 0.1.1 creaban accesos directos en el escritorio y en Inicio; ya no se usan.
# Solo se borran si apuntan a kitsune.ps1 (puede haber otro Kitsune.lnk que no es nuestro), y un
# fallo solo avisa: es limpieza opcional y el antivirus pudo haber bloqueado el archivo.
function Quitar-Accesos {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($carpeta in @(
            (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
            [Environment]::GetFolderPath('Desktop'))) {
        $lnk = Join-Path $carpeta 'Kitsune.lnk'
        if (-not (Test-Path $lnk)) { continue }
        try {
            if ($shell.CreateShortcut($lnk).Arguments -notmatch 'kitsune\.ps1') { continue }
            Remove-Item $lnk
            Write-Host "  $lnk"
        } catch {
            Write-Host "  No se pudo borrar $lnk; bórralo a mano." -ForegroundColor Yellow
        }
    }
}

# Pide al zorro que se cierre con su señal con nombre (ver kitsune.ps1) en vez de matar procesos
# de PowerShell, que los antivirus toman por malware. La señal se reenvía en cada intento por si
# el zorro está arrancando. El mutex vive hasta que termina el proceso: cuando desaparece, cerró.
# Devuelve $false si a los 10 s sigue abierto (una versión anterior no conoce la señal).
function Cerrar-Kitsune {
    for ($i = 0; $i -lt 100; $i++) {
        $senal = $null
        if ([Threading.EventWaitHandle]::TryOpenExisting('Local\kitsune-claude-cerrar', [ref]$senal)) {
            [void]$senal.Set(); $senal.Dispose()
        }
        $mutex = $null
        if (-not [Threading.Mutex]::TryOpenExisting('Local\kitsune-claude', [ref]$mutex)) { return $true }
        $mutex.Dispose(); Start-Sleep -Milliseconds 100
    }
    $false
}

# No se sigue con el zorro abierto: su carpeta es el directorio de trabajo del proceso y no se
# podría borrar, y una instancia nueva saldría en silencio por el mutex.
function Asegurar-Cerrado {
    while (-not (Cerrar-Kitsune)) {
        Write-Host '  Kitsune sigue abierto (una versión anterior no entiende el aviso de cierre).' -ForegroundColor Yellow
        $respuesta = Read-Host '  Ciérralo con clic derecho > Cerrar kitsune y pulsa Enter (o escribe s para salir)'
        if ($respuesta -eq 's') { throw 'Cancelado: Kitsune sigue abierto y no se tocó nada.' }
    }
}
