import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

import {buildBarEmbed} from './build-bar-embed.mjs';
import {buildFlutterEmbed} from './build-flutter-embed.mjs';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const docusaurus = path.join(website, 'node_modules', '.bin', 'docusaurus');
const previewWatcher = path.join(website, 'scripts', 'watch-flutter-embed.mjs');
const barWatcher = path.join(website, 'scripts', 'watch-bar-embed.mjs');

console.log('[development] Building the shared Flutter previews...');
try {
  await buildFlutterEmbed({mode: 'debug'});
} catch (error) {
  // Docusaurus is still worth starting: the previews render their own
  // "unavailable" state and the watcher rebuilds once the source compiles.
  console.error(`[development] ${error.message}`);
}

console.log('[development] Building the site bar...');
try {
  await buildBarEmbed({mode: 'debug'});
} catch (error) {
  console.error(`[development] ${error.message}`);
}

const children = [
  spawn(process.execPath, [previewWatcher], {cwd: website, stdio: 'inherit'}),
  spawn(process.execPath, [barWatcher], {cwd: website, stdio: 'inherit'}),
  spawn(docusaurus, ['start', ...process.argv.slice(2)], {cwd: website, stdio: 'inherit'}),
];

let stopping = false;

function stop(signal = 'SIGTERM') {
  if (stopping) return;
  stopping = true;
  children.forEach((child) => child.kill(signal));
}

process.on('SIGINT', () => stop('SIGINT'));
process.on('SIGTERM', () => stop('SIGTERM'));

children.forEach((child) => {
  child.on('exit', (code, signal) => {
    if (stopping) return;
    stop();
    process.exitCode = signal ? 1 : (code ?? 1);
  });
});
