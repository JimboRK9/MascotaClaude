# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es

Kitsune: un zorro de nueve colas en una ventana WPF transparente y siempre encima, que muestra
el estado de cada sesión de Claude Code (una cola por sesión; punta gris/verde/roja). Solo
Windows, todo local. Hooks de Claude Code en Node escriben el estado; un script de PowerShell lo
dibuja; una extensión mínima de VS Code enlaza las sesiones con sus terminales. No hay `SPEC.md`:
el comportamiento visible está descrito en `README.md`.

## Estado — 2026-10-25

`v0.1.0` publicada; Kaspersky la marcó como troyano al instalar (ver Gotchas). La `v0.1.1`
(probada solo en local, sin publicar) instaló sin alerta, pero su acceso directo dejaba una
ventana de Windows Terminal abierta. En curso, la `v0.1.2`: sin accesos directos ni arranque con
Windows; el hook abre el zorro. Sin tests, sin linter, sin build, sin pipeline: se distribuye como ZIP de
release (`instalar.ps1`, `desinstalar.ps1`, `comun.ps1`, `hooks.mjs`, `estado.mjs`,
`kitsune.ps1`, el `.vsix` y los README) que el usuario sube a mano a GitHub Releases.

## Cómo correr esto

No hay `package.json` ni dependencias: Node para los hooks, Windows PowerShell 5.1 para el zorro.

```powershell
# Abrir el zorro desde el repo (-STA es obligatorio para WPF). Lee ~\.claude\kitsune\estado por defecto
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\kitsune.ps1
# Leer otra carpeta de estado (para probar con JSON de mentira sin tocar las sesiones reales)
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\kitsune.ps1 -Carpeta C:\ruta\estado
# Guardar un PNG del dibujo a los 3 s (así se generaron vista-*.png); la ventana sigue abierta
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\kitsune.ps1 -Captura .\prueba.png

# Simular un evento de hook (ESCRIBE en ~\.claude\kitsune\estado real: estado.mjs no tiene ruta configurable)
'{"session_id":"prueba","hook_event_name":"Stop","cwd":"C:\\x\\demo"}' | node .\estado.mjs

# Instalar / actualizar / desinstalar (tocan ~\.claude\settings.json y VS Code: los corre el usuario)
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
powershell -ExecutionPolicy Bypass -File .\desinstalar.ps1
```

`kitsune.ps1` usa un mutex `Local\kitsune-claude`: si ya hay un zorro abierto (el que abrió el
hook), una segunda instancia sale en silencio. Para probar cambios, cerrar antes el
instalado (clic derecho → Cerrar), o usar una copia con otro nombre de mutex y de señal. El zorro
también escucha el evento con nombre `Local\kitsune-claude-cerrar`: los instaladores lo usan para
cerrarlo (`Cerrar-Kitsune` en `comun.ps1`), y la desaparición del mutex confirma que cerró. Si
no cierra (versión sin señal), `Asegurar-Cerrado` le pide al usuario cerrarlo y no sigue hasta
que lo haga.

Reempaquetar la extensión tras tocar `extension-vscode/` (el `.vsix` es un zip de su contenido;
`CreateFromDirectory` falla si el destino ya existe, así que hay que borrar el viejo primero):

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory("$PWD\extension-vscode", "$PWD\kitsune-puente-0.0.1.vsix")
```

## El mecanismo central

Tres procesos que no se hablan directamente: se coordinan por archivos JSON en
`~\.claude\kitsune\`.

| Archivo | Lo escribe | Lo lee | Contenido |
|---|---|---|---|
| `estado\<session_id>.json` | `estado.mjs` (hook); `kitsune.ps1` al marcar vista | `kitsune.ps1` cada 1 s | `proyecto, estado (gris/verde/rojo), decision, inicio, ts, claude, shell` |
| `foco.json` | extensión | `estado.mjs` (en `Stop`), `kitsune.ps1` | pid de la shell de la terminal enfocada (`null` si VS Code pierde el foco) |
| `terminales\<pid>.json` | extensión | `kitsune.ps1` | nombre de la ventana de VS Code dueña de esa terminal |
| `enfocar.json` | `kitsune.ps1` al hacer clic | extensión (`fs.watchFile` 300 ms) | pedido de mostrar la terminal; se ignora si tiene más de 5 s |
| `posicion.json` | `kitsune.ps1` | `kitsune.ps1` | dónde quedó la ventana |
| `zorro.pid` | `kitsune.ps1`, que lo tiene abierto y bloqueado mientras vive | `estado.mjs` (intenta abrirlo para escribir) | bloqueado = zorro vivo. No se confía en el pid: Windows lo reutiliza y el archivo queda si el zorro muere |
| `abriendo` | `estado.mjs` antes de lanzar; lo borra si sale bien | `estado.mjs` | marca de intento fallido: frena reintentos 30 s |

**Quién abre el zorro:** `estado.mjs`, en `SessionStart` y `UserPromptSubmit`, si nadie tiene
bloqueado `zorro.pid`. Llama a `kitsune.ps1 -Soltar` y espera (~0,5 s); ese PowerShell relanza el
zorro con `CreateNoWindow` y termina. El rodeo es obligatorio: un hijo directo de Node muere al
terminar el hook (Node mete a sus hijos en un job), con `detached` PowerShell 5.1 no arranca, y un
acceso directo abre una ventana de Windows Terminal. El nieto escapa del job y no crea ventana.

**La clave que une todo es el pid de la shell.** `estado.mjs` sube por los procesos padres hasta
`claude*.exe`; guarda su pid (`claude`, para detectar sesiones muertas) y el de su padre (`shell`),
que es el mismo `terminal.processId` que ve VS Code. Esa búsqueda cuesta ~1 s, así que se hace
**una sola vez por sesión**; `claude: 0` significa "ya se intentó y no se encontró".

**Máquina de estados** (`COLOR` en `estado.mjs`, `Marcar-Vistas` en `kitsune.ps1`):

- `UserPromptSubmit`/`PostToolUse` → verde; `Stop`/`Notification`/`PreToolUse(AskUserQuestion)` → rojo; `SessionStart` → gris; `SessionEnd` borra el archivo.
- `decision: true` (permiso, `AskUserQuestion`, o última línea del último texto del asistente con `?`) mantiene la cola roja aunque la mires; solo la apaga contestar.
- Roja sin decisión pasa a gris cuando `foco.json` apunta a su shell con un `ts` posterior al de la sesión. Si el `Stop` llega mientras ya la mirabas, `estado.mjs` la escribe gris directamente.
- `kitsune.ps1` borra estados cuyo pid `claude` ya no existe o con más de 12 h sin cambios.

Los hooks se registran en `~\.claude\settings.json` vía `hooks.mjs`; los reconoce por la regex
`kitsune/estado\.mjs` en el comando, así reinstalar no duplica y desinstalar no toca hooks ajenos.

## Gotchas

| Síntoma | Causa / solución | Fecha |
|---|---|---|
| Una sesión se pone roja ~60 s después de terminar aunque ya la viste | `Notification` de tipo `idle_prompt` / "waiting for your input" llega tras el `Stop`; `estado.mjs` la descarta (`esperaInactiva`) | 2026-10-25 |
| `SessionStart` (resume/compact) borra el rojo de una sesión | Si ya existe el archivo, `SessionStart` se omite y conserva color y decisión | 2026-10-25 |
| El nombre de la cola aparece y desaparece al instante | El `ToolTip` de WPF se cierra en esta ventana transparente/topmost/inactiva: se usa un `Popup` propio (`$burbuja`). Por lo mismo no se redibujan las colas ni tiembla el zorro con el mouse encima | 2026-10-25 |
| `instalar.ps1` aborta al instalar la extensión | `code` escribe avisos en stderr y con `$ErrorActionPreference = 'Stop'` PowerShell 5.1 los vuelve errores; se llama en un bloque con `'Continue'` | 2026-10-25 |
| El hook falla con perfiles tipo `C:\Users\Juan Perez` | La ruta a `estado.mjs` va entre comillas en el comando del hook (`hooks.mjs`) | 2026-10-25 |
| `JSON.parse` de `settings.json` falla | El archivo puede traer BOM; `hooks.mjs` lo quita antes de parsear | 2026-10-25 |
| Kaspersky corta `instalar.ps1` como `PDM:Trojan.Win32.Generic`, mata el proceso y borra el script | Detección por comportamiento: el instalador creaba un acceso directo en Inicio a un PowerShell oculto con `Bypass` y lo lanzaba; además mataba procesos `powershell.exe`. En esa misma máquina, abrir el zorro con el acceso directo del escritorio (la misma línea de comandos) no generó alerta: es una sola observación, no una garantía. Ya no hay arranque con Windows ni accesos directos (abre el hook), el instalador no abre el zorro y el cierre va por señal | 2026-10-25 |
| Al abrir el zorro queda una ventana de PowerShell abierta | En Windows 11 con Windows Terminal como terminal predeterminada, un acceso directo a `powershell.exe -WindowStyle Hidden` abre una pestaña que no se oculta. `FreeConsole` no la cierra, y lanzar vía `conhost.exe` hizo que Kaspersky bloqueara el `.lnk`. Solución: lo abre el hook con `-Soltar` (ver «Quién abre el zorro») | 2026-10-25 |
| Las tildes salen rotas en el zorro | `kitsune.ps1` no tiene BOM y PowerShell 5.1 lo lee como ANSI: los textos no ASCII se arman con `[char]0x00F3` etc. Los instaladores sí llevan BOM UTF-8 y usan tildes literales | 2026-10-25 |

## No hagas

- **No hagas que `estado.mjs` pueda fallar o tardar**: corre en cada evento de cada sesión. Todo va en `try/catch`, termina con `process.exit(0)`, y la búsqueda de procesos y `abrirZorro` tienen `timeout: 5000`. `abrirZorro` solo cuesta tiempo (~0,5 s) cuando el zorro no está abierto: no le quites el chequeo de `zorro.pid`. Un error del zorro nunca debe bloquear a Claude.
- **No llames `buscarTerminal()` en cada evento**: cuesta ~1 s por invocación; se reutilizan `claude`/`shell` del archivo existente.
- **No vuelvas a abrir el zorro con accesos directos ni desde el instalador**: deja ventana en Windows Terminal y lo que se probó para ocultarla (`conhost.exe`, `--headless`, `wscript`/`mshta`) es justo lo que vigilan los antivirus. Lo abre el hook.
- **No agregues a los instaladores conductas que parezcan malware**: registrar arranque automático, lanzar PowerShell oculto, matar procesos (`Stop-Process`), `-EncodedCommand`, descargar cosas o lanzar a través de `explorer.exe`. Kaspersky ya lo marcó como troyano una vez (ver Gotchas, 2026-10-25). Cualquier cambio en `instalar.ps1` se prueba con un antivirus de comportamiento activo antes de publicar.
- **No escribas el JSON de estado directo**: se escribe a `<archivo>.<pid>.tmp` y se renombra, porque `kitsune.ps1` lo lee cada segundo y varias sesiones escriben en paralelo.
- **No metas caracteres no ASCII literales en `kitsune.ps1`** ni le agregues lógica que dependa de PowerShell 7: el hook lo lanza con `powershell.exe` (5.1).
- **No cambies el nombre ni la versión del `.vsix` sin actualizar `instalar.ps1`** (lo copia por nombre literal), ni el `publisher`/`name` de la extensión sin actualizar `desinstalar.ps1` (`jgomez.kitsune-puente`).
- **No toques `extension-vscode/` sin reempaquetar el `.vsix`**: el instalador usa el `.vsix`, no la carpeta.
- **No ejecutes `instalar.ps1`/`desinstalar.ps1` ni `node hooks.mjs`**: modifican `~\.claude\settings.json` y VS Code del usuario. Se entrega el comando.

## Convenciones del código existente

- Todo en español: identificadores (`Leer-Sesiones`, `buscarTerminal`, `carpeta`), mensajes y comentarios. Las funciones de PowerShell siguen `Verbo-Sustantivo` en español.
- Comentarios en `.mjs`/`.ps1` del runtime sin tildes (por la codificación); explican el porqué, no el qué.
- Sin dependencias externas: solo `node:` built-ins, la API `vscode` y WPF/P-Invoke vía `Add-Type`.
- `kitsune.ps1` dibuja sobre un lienzo lógico de 200×190 que un `Viewbox` escala; las piezas simétricas se dibujan del lado izquierdo y `Espejo` las refleja sobre `x = 100`. Cada cola tiene un `Tag` con su sesión.
- Fallos de E/S opcionales se tragan con `catch { }` / `catch { /* motivo */ }`; el comentario dice por qué es aceptable.

## Enlaces

- `README.md` (inglés) y `README.es.md` (español) — uso, instalación y diagrama de flujo; manda sobre el comportamiento visible. Son traducción uno del otro: todo cambio va en ambos. Si contradicen al código, manda el código y hay que corregir los README.
- `demo.gif` se grabó con `ffmpeg -f gdigrab` sobre una copia de `kitsune.ps1` con la ventana al doble (360×342), apuntada con `-Carpeta` a estados de prueba y con un fondo blanco detrás. Si cambia el dibujo, hay que regrabarlo junto con los `vista-*.png` (`-Captura`).
- Ni el código ni los textos públicos nombran personajes ni obras de terceros: el zorro se presenta como el *kyūbi no kitsune* del folclore japonés (decisión del 2026-10-25, para reducir la exposición a reclamos de derechos de autor).
- No existen todavía `SPEC.md`, `ARCHITECTURE.md` ni `DEUDA_TECNICA.md`.
