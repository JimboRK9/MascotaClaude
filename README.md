# Kitsune

**English** · [Español](README.es.md)

A nine-tailed fox that sits on top of all your windows and tells you, at a glance, which **Claude Code** sessions need you. Each tail is a session; its tip shows the session's state.

![Kitsune switching from alert to calm to asleep](demo.gif)

> The fox's labels and menus are in Spanish (*trabajando* = working, *te espera* = waiting for you, *espera tu decisión* = waiting for your decision).

## What the colors mean

| Tip | Meaning |
|---|---|
| 🟢 Green | Working: you sent it a prompt or it is using tools |
| 🔴 Red | Finished, or is asking for something, while you were looking elsewhere |
| ⚪ Gray | Idle: you already saw it (you went to its terminal) or it finished while you were watching |

- A **pending decision** (a permission prompt, a multiple-choice question, or a reply whose last line ends in «?») stays red **until you answer it**, even if you look at it.
- The fox goes on **alert** (red eyes, «!», shaking) if any tail is red, is **calm** if any session is working, and **asleep** if every tail is gray.

| Alert | Calm | Asleep |
|---|---|---|
| ![alert](vista-alerta.png) | ![calm](vista-calma.png) | ![asleep](vista-dormido.png) |

## Usage

- **Click the fox**: list of sessions, the ones waiting for you first. Pick one and it takes you to its VS Code terminal.
- **Click a tail**: takes you to that session. Hover to see its name.
- **Drag**: moves the fox; it remembers where you left it.
- **Right-click**: close it. It comes back the next time you start a Claude Code session or send a prompt to one.

## Requirements

- Windows 10 or 11 (uses the built-in Windows PowerShell 5.1)
- [Node.js](https://nodejs.org) on the PATH
- [Claude Code](https://claude.com/claude-code)
- VS Code, optional: everything works without it except jumping to the terminal

## Install

**Option A — with Git.** In PowerShell:

```powershell
git clone https://github.com/JimboRK9/MascotaClaude.git
cd MascotaClaude
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

**Option B — without Git.** From the [latest release](https://github.com/JimboRK9/MascotaClaude/releases/latest), download **`kitsune-vX.Y.Z.zip`** (not *Source code*), extract it, and in PowerShell inside the extracted folder:

```powershell
Get-ChildItem -Recurse | Unblock-File
powershell -ExecutionPolicy Bypass -File .\instalar.ps1
```

`Unblock-File` removes the "downloaded from the internet" mark Windows puts on files extracted from a zip; a `git clone` doesn't need it.

The installer:

1. copies the files to `~\.claude\kitsune\`;
2. adds 7 hooks to `~\.claude\settings.json` (it leaves a backup, keeps your other hooks, and doesn't duplicate them if you run it again);
3. installs the `kitsune-puente` VS Code extension;
4. removes the desktop and Startup shortcuts that older versions created.

Then reload VS Code (`Ctrl+Shift+P` → *Developer: Reload Window*). There is no shortcut and nothing runs at Windows startup: **the fox appears by itself when you start a Claude Code session or send a prompt to one**. Sessions that were already open before the first install show up once you restart them.

**To update**: `git pull` (or download the new release) and run `instalar.ps1` again.

### Antivirus

Kitsune is a set of plain-text PowerShell and Node scripts you can read before running. It doesn't register anything to run at Windows startup or kill processes: behavior-based antivirus engines (e.g. Kaspersky's *System Watcher*) flagged an early version that did. If yours still complains, please [open an issue](https://github.com/JimboRK9/MascotaClaude/issues) with the antivirus name and the detection.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\desinstalar.ps1
```

Removes the hooks (with a backup and without touching anyone else's), the extension, any shortcuts left by older versions and `~\.claude\kitsune\`.

## How it works

```
Claude Code ──hooks──▶ estado.mjs ──▶ ~\.claude\kitsune\estado\<session>.json ◀──reads every 1 s── kitsune.ps1 (the fox)
                                                                                    │
VS Code ── kitsune-puente ──▶ foco.json, terminales\ ◀───────────────────────────────┤
              ▲                                                                     │
              └──────────────────────── enfocar.json ◀──── click on the list ───────┘
```

| File | What it does |
|---|---|
| `estado.mjs` | Claude Code hook. Writes each session's state, identifies its terminal (once per session) and opens the fox if it isn't running. Never blocks Claude |
| `kitsune.ps1` | The fox: transparent, always-on-top WPF window. `-Captura file.png` saves an image to check the drawing |
| `extension-vscode/` | Source of the `kitsune-puente` extension: records the terminals and which one has focus, and focuses the one the fox asks for |
| `kitsune-puente-0.0.1.vsix` | The packaged extension (a zip of `extension-vscode/`) |
| `hooks.mjs` | Adds or removes the hooks in `settings.json` |

Everything is local: nothing leaves your machine.

### Repackaging the extension

The `.vsix` is a zip of the contents of `extension-vscode/`. Delete the old one first (`CreateFromDirectory` won't overwrite):

```powershell
Remove-Item .\kitsune-puente-0.0.1.vsix -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory("$PWD\extension-vscode", "$PWD\kitsune-puente-0.0.1.vsix")
```

## About the fox

The nine-tailed fox (*kyūbi no kitsune*) comes from Japanese folklore. Personal, non-commercial project.
