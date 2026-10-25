// Hook de Claude Code: deja el estado de cada sesion en kitsune/estado/<id>.json
// para que kitsune.ps1 lo pinte en la punta de una cola. Nunca debe bloquear a Claude.
import { readFileSync, writeFileSync, mkdirSync, rmSync, renameSync, openSync, fstatSync, readSync, closeSync } from 'node:fs';
import { join, basename } from 'node:path';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';

const COLOR = {
  SessionStart: 'gris',
  UserPromptSubmit: 'verde',
  PostToolUse: 'verde',
  Stop: 'rojo',
  Notification: 'rojo',
  PreToolUse: 'rojo', // solo llega para AskUserQuestion (matcher en settings.json)
};
const base = join(homedir(), '.claude', 'kitsune');

// Sube por los procesos padres hasta claude.exe: su pid sirve para saber si la sesion sigue viva,
// y el de su padre es la shell de la terminal, el mismo pid con que VS Code identifica la terminal.
// Tarda ~1 s, por eso se hace una sola vez por sesion; claude: 0 marca que ya se intento.
function buscarTerminal() {
  try {
    const ps = `$p = Get-CimInstance Win32_Process -Filter "ProcessId=${process.ppid}"; ` +
      `for ($i = 0; $i -lt 8 -and $p; $i++) { if ($p.Name -like 'claude*') { "$($p.ProcessId) $($p.ParentProcessId)"; break }; ` +
      `$p = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" }`;
    const salida = execFileSync('powershell', ['-NoProfile', '-Command', ps], { encoding: 'utf8', timeout: 5000, windowsHide: true });
    const [claude, shell] = salida.trim().split(/\s+/).map(Number);
    return claude ? { claude, shell } : { claude: 0, shell: 0 };
  } catch {
    return { claude: 0, shell: 0 };
  }
}

// Una respuesta que termina en pregunta deja una decision pendiente. Lee el final de la
// transcripcion y mira la ultima linea del ultimo texto de Claude; se corta al llegar a tu mensaje.
function terminaEnPregunta(ruta) {
  try {
    const fd = openSync(ruta, 'r');
    const tam = fstatSync(fd).size;
    const largo = Math.min(tam, 262144);
    const buf = Buffer.alloc(largo);
    readSync(fd, buf, 0, largo, tam - largo);
    closeSync(fd);
    for (const linea of buf.toString('utf8').split('\n').reverse()) {
      let r;
      try { r = JSON.parse(linea); } catch { continue; }
      if (r.type === 'user' && typeof r.message?.content === 'string') return false;
      if (r.type !== 'assistant') continue;
      const textos = (r.message?.content || []).filter((c) => c.type === 'text').map((c) => c.text);
      if (!textos.length) continue;
      const ultima = textos.join('\n').split('\n').filter((l) => l.trim()).pop() || '';
      return ultima.includes('?');
    }
  } catch { /* sin transcripcion: no se sabe */ }
  return false;
}

try {
  const e = JSON.parse(readFileSync(0, 'utf8'));
  const id = String(e.session_id || '').replace(/[^\w-]/g, '');
  const evento = e.hook_event_name;
  if (id) {
    const carpeta = join(base, 'estado');
    const archivo = join(carpeta, `${id}.json`);
    mkdirSync(carpeta, { recursive: true });

    let actual = null;
    try { actual = JSON.parse(readFileSync(archivo, 'utf8')); } catch { /* sesion nueva */ }

    // El aviso de "sigue esperando tu respuesta" llega ~60 s despues del Stop: no cambia nada.
    const esperaInactiva = evento === 'Notification' &&
      (e.notification_type === 'idle_prompt' || /waiting for your input/i.test(e.message || ''));

    if (evento === 'SessionEnd') {
      rmSync(archivo, { force: true });
    } else if (COLOR[evento] && !esperaInactiva) {
      const omitir =
        (evento === 'SessionStart' && actual) ||            // resume o compact: conserva el color
        (evento === 'PostToolUse' && actual?.estado === 'verde' && 'claude' in actual); // ya trabajaba y esta identificada
      if (!omitir) {
        const ids = actual && 'claude' in actual ? { claude: actual.claude, shell: actual.shell } : buscarTerminal();
        let color = COLOR[evento];
        // Decision pendiente: permiso, AskUserQuestion o respuesta que termina en pregunta.
        // Se queda roja aunque la mires; solo la apaga contestar (UserPromptSubmit o PostToolUse).
        let decision = evento === 'SessionStart' ? Boolean(actual?.decision) : false;
        if (evento === 'Notification' || evento === 'PreToolUse') decision = true;
        if (evento === 'Stop') decision = terminaEnPregunta(e.transcript_path);
        // Termino sin preguntar mientras mirabas su terminal: ya lo viste, queda gris.
        if (evento === 'Stop' && !decision && ids.shell) {
          try { if (JSON.parse(readFileSync(join(base, 'foco.json'), 'utf8')).shell === ids.shell) color = 'gris'; } catch { /* sin extension */ }
        }
        const ahora = Date.now();
        const temporal = `${archivo}.${process.pid}.tmp`;
        writeFileSync(temporal, JSON.stringify({
          proyecto: basename(e.cwd || '') || id.slice(0, 8),
          estado: color,
          decision,
          inicio: actual?.inicio ?? ahora,
          ts: ahora,
          ...ids,
        }));
        renameSync(temporal, archivo);
      }
    }
  }
} catch { /* un fallo del zorro no detiene la sesion */ }
process.exit(0);
