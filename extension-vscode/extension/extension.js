// Puente entre el zorro Kitsune y las terminales de VS Code. Corre en cada ventana:
// - anota sus terminales (pid de la shell -> nombre de la ventana) en kitsune/terminales/
// - anota en kitsune/foco.json que terminal tiene el foco, para que el hook no marque rojo lo que estas mirando
// - cuando el zorro escribe kitsune/enfocar.json, la ventana duena de esa terminal la muestra.
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const os = require('os');

const base = path.join(os.homedir(), '.claude', 'kitsune');
const carpetaTerminales = path.join(base, 'terminales');
const archivoFoco = path.join(base, 'foco.json');
const archivoPedido = path.join(base, 'enfocar.json');

function escribir(archivo, datos) {
  try { fs.writeFileSync(archivo, JSON.stringify(datos)); } catch { /* el zorro es opcional */ }
}

async function registrar(terminal) {
  const pid = await terminal.processId;
  if (pid) escribir(path.join(carpetaTerminales, `${pid}.json`), { ventana: vscode.workspace.name || '', nombre: terminal.name });
}

async function informarFoco() {
  if (!vscode.window.state.focused) return;
  const terminal = vscode.window.activeTerminal;
  escribir(archivoFoco, { shell: terminal ? await terminal.processId : null, ts: Date.now() });
}

async function atenderPedido() {
  let pedido;
  try { pedido = JSON.parse(fs.readFileSync(archivoPedido, 'utf8')); } catch { return; }
  if (!pedido.shell || Date.now() - pedido.ts > 5000) return;
  for (const terminal of vscode.window.terminals) {
    if ((await terminal.processId) === pedido.shell) {
      terminal.show(false);
      return;
    }
  }
}

function activate(context) {
  fs.mkdirSync(carpetaTerminales, { recursive: true });
  vscode.window.terminals.forEach(registrar);

  context.subscriptions.push(
    vscode.window.onDidOpenTerminal(registrar),
    vscode.window.onDidCloseTerminal(async (terminal) => {
      const pid = await terminal.processId;
      if (pid) fs.rmSync(path.join(carpetaTerminales, `${pid}.json`), { force: true });
    }),
    vscode.window.onDidChangeActiveTerminal(informarFoco),
    vscode.window.onDidChangeWindowState((estado) => {
      if (estado.focused) informarFoco();
      else escribir(archivoFoco, { shell: null, ts: Date.now() });
    }),
  );

  fs.watchFile(archivoPedido, { interval: 300 }, atenderPedido);
  context.subscriptions.push({ dispose: () => fs.unwatchFile(archivoPedido, atenderPedido) });
}

module.exports = { activate, deactivate() {} };
