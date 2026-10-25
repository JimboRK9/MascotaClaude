# Kitsune

[English](README.md) · **Español**

Un zorro de nueve colas que vive encima de todas tus ventanas y te dice, de un vistazo, qué sesiones de **Claude Code** te necesitan. Cada cola es una sesión; la punta muestra su estado.

![Kitsune pasando de alerta a tranquilo a dormido](demo.gif)

## Qué significa cada color

| Punta | Significa |
|---|---|
| 🟢 Verde | Está trabajando: le escribiste o está usando herramientas |
| 🔴 Roja | Terminó o te pide algo mientras mirabas otra cosa |
| ⚪ Gris | En reposo: ya la viste (fuiste a su terminal) o terminó mientras la mirabas |

- Una **decisión pendiente** (pide permiso, te pregunta con opciones o su última línea termina en «?») se queda roja **hasta que la contestes**, aunque la mires.
- El zorro se pone en **alerta** (ojos rojos, «!» y tiembla) si hay alguna roja, **tranquilo** si alguna trabaja y **dormido** si todas están grises.

| Alerta | Tranquilo | Dormido |
|---|---|---|
| ![alerta](vista-alerta.png) | ![tranquilo](vista-calma.png) | ![dormido](vista-dormido.png) |

## Cómo se usa

- **Clic en el zorro**: lista de sesiones, primero las que te esperan. Elige una y te lleva a su terminal de VS Code.
- **Clic en una cola**: te lleva a esa sesión. Pasa el mouse para ver su nombre.
- **Arrastrar**: lo mueves; recuerda dónde lo dejaste.
- **Clic derecho**: cerrarlo. Vuelve la próxima vez que inicies una sesión de Claude Code o le escribas a una.

## Requisitos

- Windows 10 u 11 (usa Windows PowerShell 5.1, que ya viene)
- [Node.js](https://nodejs.org) en el PATH
- [Claude Code](https://claude.com/claude-code)
- VS Code, opcional: sin él todo funciona menos llevarte a la terminal

## Instalar

**Opción A — con Git.** En PowerShell:

```powershell
git clone https://github.com/JimboRK9/MascotaClaude.git
cd MascotaClaude
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

**Opción B — sin Git.** De la [última versión](https://github.com/JimboRK9/MascotaClaude/releases/latest), baja **`kitsune-vX.Y.Z.zip`** (no *Source code*), descomprímelo y, en PowerShell dentro de la carpeta descomprimida:

```powershell
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

`Unblock-File` quita la marca de «descargado de internet» que Windows pone a lo que sale de un zip; con `git clone` no hace falta.

El instalador:

1. copia los archivos a `~\.claude\kitsune\`;
2. agrega 7 hooks a `~\.claude\settings.json` (deja un respaldo, conserva tus otros hooks y no duplica si lo corres de nuevo);
3. instala la extensión `kitsune-puente` en VS Code;
4. quita los accesos directos del escritorio y de Inicio que creaban versiones anteriores.

Después, recarga VS Code (`Ctrl+Shift+P` → *Developer: Reload Window*). No hay acceso directo ni nada que arranque con Windows: **el zorro aparece solo cuando inicias una sesión de Claude Code o le escribes a una**. Las sesiones que ya estaban abiertas antes de la primera instalación aparecen al reiniciarlas.

**Para actualizar**: `git pull` (o baja la versión nueva) y vuelve a correr `instalar.ps1`.

### Antivirus

Kitsune son scripts de PowerShell y Node en texto plano que puedes leer antes de correrlos. No registra nada para arrancar con Windows ni mata procesos: los antivirus que juzgan el comportamiento (por ejemplo, la *Vigía proactiva* de Kaspersky) marcaron una versión temprana que sí lo hacía. Si el tuyo aún protesta, [abre un issue](https://github.com/JimboRK9/MascotaClaude/issues) con el nombre del antivirus y la detección.

## Desinstalar

```powershell
powershell -ExecutionPolicy Bypass -File .\desinstalar.ps1
```

Quita los hooks (con respaldo y sin tocar los ajenos), la extensión, los accesos directos que hayan dejado versiones anteriores y `~\.claude\kitsune\`.

## Cómo funciona

```
Claude Code ──hooks──▶ estado.mjs ──▶ ~\.claude\kitsune\estado\<sesión>.json ◀──lee cada 1 s── kitsune.ps1 (el zorro)
                                                                                    │
VS Code ── kitsune-puente ──▶ foco.json, terminales\ ◀───────────────────────────────┤
              ▲                                                                     │
              └──────────────────────── enfocar.json ◀──── clic en la lista ────────┘
```

| Archivo | Qué hace |
|---|---|
| `estado.mjs` | Hook de Claude Code. Escribe el estado de cada sesión, identifica su terminal (una vez por sesión) y abre el zorro si no está abierto. Nunca bloquea a Claude |
| `kitsune.ps1` | El zorro: ventana WPF transparente, siempre encima. `-Captura archivo.png` guarda una imagen para revisar el dibujo |
| `extension-vscode/` | Código de la extensión `kitsune-puente`: anota las terminales y cuál tiene el foco, y enfoca la que pide el zorro |
| `kitsune-puente-0.0.1.vsix` | La extensión empaquetada (un zip de `extension-vscode/`) |
| `hooks.mjs` | Agrega o quita los hooks en `settings.json` |

Todo es local: nada sale de tu máquina.

### Reempaquetar la extensión

El `.vsix` es un zip del contenido de `extension-vscode/`. Borra antes el viejo (`CreateFromDirectory` no sobrescribe):

```powershell
Remove-Item .\kitsune-puente-0.0.1.vsix -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory("$PWD\extension-vscode", "$PWD\kitsune-puente-0.0.1.vsix")
```

## Sobre el zorro

El zorro de nueve colas (*kyūbi no kitsune*) viene del folclore japonés. Proyecto personal sin fines comerciales.
