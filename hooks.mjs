// Agrega (instalar) o quita (desinstalar) los hooks de Kitsune en ~/.claude/settings.json
// sin tocar el resto: deja un respaldo, conserva los hooks ajenos y no duplica los propios.
// Uso: node hooks.mjs instalar | desinstalar
import { readFileSync, writeFileSync, copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const accion = process.argv[2];
if (!['instalar', 'desinstalar'].includes(accion)) {
  console.error('Uso: node hooks.mjs instalar | desinstalar');
  process.exit(1);
}

const carpetaClaude = join(homedir(), '.claude');
const archivo = join(carpetaClaude, 'settings.json');
// Entre comillas: el perfil puede tener espacios (C:\Users\Juan Perez).
const comando = `node "${join(carpetaClaude, 'kitsune', 'estado.mjs').replaceAll('\\', '/')}"`;
const EVENTOS = [
  ['SessionStart'],
  ['UserPromptSubmit'],
  ['PostToolUse'],
  ['PreToolUse', 'AskUserQuestion'],
  ['Notification'],
  ['Stop'],
  ['SessionEnd'],
];
const esDeKitsune = (h) => /kitsune\/estado\.mjs/.test(h?.command || '');

let config = {};
if (existsSync(archivo)) {
  config = JSON.parse(readFileSync(archivo, 'utf8').replace(/^﻿/, ''));
  const respaldo = `${archivo}.respaldo-${new Date().toISOString().replace(/[:.]/g, '-')}`;
  copyFileSync(archivo, respaldo);
  console.log(`Respaldo: ${respaldo}`);
}
config.hooks ??= {};

// Primero se quitan los de Kitsune; asi instalar dos veces no duplica.
for (const [evento] of EVENTOS) {
  const grupos = (config.hooks[evento] || [])
    .map((g) => ({ ...g, hooks: (g.hooks || []).filter((h) => !esDeKitsune(h)) }))
    .filter((g) => g.hooks.length);
  if (grupos.length) config.hooks[evento] = grupos;
  else delete config.hooks[evento];
}

if (accion === 'instalar') {
  for (const [evento, matcher] of EVENTOS) {
    (config.hooks[evento] ??= []).push({
      ...(matcher ? { matcher } : {}),
      hooks: [{ type: 'command', command: comando }],
    });
  }
}
if (!Object.keys(config.hooks).length) delete config.hooks;

mkdirSync(carpetaClaude, { recursive: true });
writeFileSync(archivo, `${JSON.stringify(config, null, 2)}\n`);
console.log(accion === 'instalar' ? `Hooks agregados (${EVENTOS.length}) en ${archivo}` : `Hooks quitados de ${archivo}`);
