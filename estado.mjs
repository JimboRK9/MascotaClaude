// Hook de Claude Code: deja el estado de cada sesion en kitsune/estado/<id>.json
// para que kitsune.ps1 lo pinte en la punta de una cola. Nunca debe bloquear a Claude.
import { readFileSync, readdirSync, writeFileSync, mkdirSync, rmSync, renameSync, openSync, fstatSync, readSync, closeSync, statSync } from 'node:fs';
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
// Origenes de SessionStart en que el mismo proceso puede pasar a otro session_id.
const CAMBIAN_SESION = ['clear', 'resume', 'fork'];
const ESPERA_REINTENTO = 5 * 60 * 1000;

// Sube por los procesos padres hasta claude.exe: su pid sirve para saber si la sesion sigue viva,
// y el de su padre es la shell de la terminal, el mismo pid con que VS Code identifica la terminal.
// Tarda ~1 s, por eso se hace una sola vez por sesion; claude: 0 marca que ya se busco y no esta.
// Si la busqueda falla (p. ej. PowerShell lento con antivirus) no se sabe nada: devuelve {} y se
// reintenta en UserPromptSubmit, a lo sumo cada 5 min para no cobrar la espera en cada mensaje.
function buscarTerminal() {
  try {
    const ps = `$p = Get-CimInstance Win32_Process -Filter "ProcessId=${process.ppid}" -ErrorAction Stop; ` +
      `for ($i = 0; $i -lt 8 -and $p; $i++) { if ($p.Name -like 'claude*') { "$($p.ProcessId) $($p.ParentProcessId)"; break }; ` +
      `$p = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" -ErrorAction Stop }`;
    const salida = execFileSync('powershell', ['-NoProfile', '-Command', ps], { encoding: 'utf8', timeout: 5000, windowsHide: true });
    const [claude, shell] = salida.trim().split(/\s+/).map(Number);
    return claude ? { claude, shell } : { claude: 0, shell: 0 };
  } catch {
    return {};
  }
}

// /clear y /resume cambian el session_id dentro del mismo proceso. SessionEnd deberia borrar el
// archivo anterior, pero puede no alcanzar a correr, y con el pid vivo el zorro no lo limpia: quedaria
// una cola fantasma congelada (2026-11-01). Se limpia solo aqui y no en el zorro porque un mismo pid
// no siempre es una sola sesion: un host puede ser el ancestro claude* de varias.
function retirarAnteriores(carpeta, id, claude) {
  for (const nombre of readdirSync(carpeta)) {
    if (!nombre.endsWith('.json') || nombre === `${id}.json`) continue;
    const ruta = join(carpeta, nombre);
    try {
      if (JSON.parse(readFileSync(ruta, 'utf8')).claude === claude) rmSync(ruta, { force: true });
    } catch { /* otra sesion lo esta escribiendo o ya no existe */ }
  }
}

// El zorro vivo tiene zorro.pid abierto sin permiso de escritura para otros (ver kitsune.ps1).
function zorroAbierto() {
  try {
    closeSync(openSync(join(base, 'zorro.pid'), 'r+'));
    return false; // nadie lo bloquea: quedo de un zorro que ya murio
  } catch (err) {
    return err.code === 'EBUSY' || err.code === 'EPERM';
  }
}

// Abre el zorro si no esta abierto. Se abre desde aqui y no con un acceso directo: un acceso
// directo a PowerShell abre una ventana de Windows Terminal que -WindowStyle Hidden no oculta
// (2026-10-25). -Soltar relanza el zorro sin consola (ver kitsune.ps1); hay que esperarlo
// (~0,5 s), pero solo cuando el zorro no esta abierto. Si un intento falla (p. ej. un arranque
// que el antivirus hace pasar de 5 s), la marca 'abriendo' queda y frena los reintentos 30 s,
// para no cobrar esa espera en cada mensaje; si sale bien, se borra.
function abrirZorro() {
  if (zorroAbierto()) return;
  const intento = join(base, 'abriendo');
  try { if (Date.now() - statSync(intento).mtimeMs < 30000) return; } catch { /* sin fallos recientes */ }
  writeFileSync(intento, '');
  execFileSync('powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', join(base, 'kitsune.ps1'), '-Soltar'],
    { stdio: 'ignore', timeout: 5000, windowsHide: true });
  rmSync(intento, { force: true });
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
  // Si lo cerraste, vuelve cuando inicias una sesion o le escribes a una.
  if (evento === 'SessionStart' || evento === 'UserPromptSubmit') {
    try { abrirZorro(); } catch { /* el zorro es opcional */ }
  }
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
      const cambiaSesion = evento === 'SessionStart' && CAMBIAN_SESION.includes(e.source);
      const omitir =
        (evento === 'SessionStart' && actual && !cambiaSesion) || // compact: nada cambia
        (evento === 'PostToolUse' && actual?.estado === 'verde' && 'claude' in actual); // ya trabajaba y esta identificada
      if (!omitir) {
        const identificada = actual && 'claude' in actual;
        const ahora = Date.now();
        const buscar = cambiaSesion || !actual ||
          (!identificada && evento === 'UserPromptSubmit' && ahora - (actual.buscado || 0) > ESPERA_REINTENTO);
        let ids = {};
        if (buscar) ids = buscarTerminal(); // un resume puede venir de otro proceso: el pid guardado no sirve
        if (!('claude' in ids) && identificada) ids = { claude: actual.claude, shell: actual.shell };
        if (!('claude' in ids)) ids.buscado = buscar ? ahora : actual?.buscado;
        let color = evento === 'SessionStart' && actual ? actual.estado : COLOR[evento]; // conserva el color
        // Decision pendiente: permiso, AskUserQuestion o respuesta que termina en pregunta.
        // Se queda roja aunque la mires; solo la apaga contestar (UserPromptSubmit o PostToolUse).
        let decision = evento === 'SessionStart' ? Boolean(actual?.decision) : false;
        if (evento === 'Notification' || evento === 'PreToolUse') decision = true;
        if (evento === 'Stop') decision = terminaEnPregunta(e.transcript_path);
        // Termino sin preguntar mientras mirabas su terminal: ya lo viste, queda gris.
        if (evento === 'Stop' && !decision && ids.shell) {
          try { if (JSON.parse(readFileSync(join(base, 'foco.json'), 'utf8')).shell === ids.shell) color = 'gris'; } catch { /* sin extension */ }
        }
        const temporal = `${archivo}.${process.pid}.tmp`;
        writeFileSync(temporal, JSON.stringify({
          proyecto: basename(e.cwd || '') || id.slice(0, 8),
          estado: color,
          decision,
          inicio: actual?.inicio ?? ahora,
          // Si SessionStart conserva el color, conserva el ts: Marcar-Vistas compara el foco contra el.
          ts: evento === 'SessionStart' && actual ? actual.ts : ahora,
          ...ids,
        }));
        renameSync(temporal, archivo);
        // Tambien tras un reintento: si la busqueda fallo en el SessionStart, no se pudo limpiar ahi.
        if ((cambiaSesion || (buscar && actual?.buscado)) && ids.claude) retirarAnteriores(carpeta, id, ids.claude);
      }
    }
  }
} catch { /* un fallo del zorro no detiene la sesion */ }
process.exit(0);
