# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es

Kitsune: un zorro de nueve colas en una ventana WPF transparente y siempre encima, que muestra
el estado de cada sesión de Claude Code (una cola por sesión; punta gris/verde/roja). Solo
Windows, todo local. Hooks de Claude Code en Node escriben el estado; un script de PowerShell lo
dibuja; una extensión mínima de VS Code enlaza las sesiones con sus terminales. No hay `SPEC.md`:
el comportamiento visible está descrito en `README.md`.

## Estado — 2026-10-25

Versión inicial (`fc34ad2`). Sin tests, sin linter, sin build, sin pipeline: se distribuye como
carpeta y se instala con `instalar.ps1`.

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

# Instalar / actualizar / desinstalar (tocan ~\.claude\settings.json, VS Code y accesos directos: los corre el usuario)
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
powershell -ExecutionPolicy Bypass -File .\desinstalar.ps1
```

`kitsune.ps1` usa un mutex `Local\kitsune-claude`: si ya hay un zorro abierto (el del acceso
directo de Inicio), una segunda instancia sale en silencio. Para probar cambios, cerrar antes el
instalado (clic derecho → Cerrar).

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
| Las tildes salen rotas en el zorro | `kitsune.ps1` no tiene BOM y PowerShell 5.1 lo lee como ANSI: los textos no ASCII se arman con `[char]0x00F3` etc. Los instaladores sí llevan BOM UTF-8 y usan tildes literales | 2026-10-25 |

## No hagas

- **No hagas que `estado.mjs` pueda fallar o tardar**: corre en cada evento de cada sesión. Todo va en `try/catch`, termina con `process.exit(0)` y la búsqueda de procesos tiene `timeout: 5000`. Un error del zorro nunca debe bloquear a Claude.
- **No llames `buscarTerminal()` en cada evento**: cuesta ~1 s por invocación; se reutilizan `claude`/`shell` del archivo existente.
- **No escribas el JSON de estado directo**: se escribe a `<archivo>.<pid>.tmp` y se renombra, porque `kitsune.ps1` lo lee cada segundo y varias sesiones escriben en paralelo.
- **No metas caracteres no ASCII literales en `kitsune.ps1`** ni le agregues lógica que dependa de PowerShell 7: el acceso directo usa `powershell.exe` (5.1).
- **No cambies el nombre ni la versión del `.vsix` sin actualizar `instalar.ps1`** (lo copia por nombre literal), ni el `publisher`/`name` de la extensión sin actualizar `desinstalar.ps1` (`jgomez.kitsune-puente`).
- **No toques `extension-vscode/` sin reempaquetar el `.vsix`**: el instalador usa el `.vsix`, no la carpeta.
- **No ejecutes `instalar.ps1`/`desinstalar.ps1` ni `node hooks.mjs`**: modifican `~\.claude\settings.json`, VS Code y el inicio de Windows del usuario. Se entrega el comando.

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
