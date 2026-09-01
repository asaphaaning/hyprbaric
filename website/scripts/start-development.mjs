import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

import {buildFlutterEmbed} from './build-flutter-embed.mjs';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const docusaurus = path.join(website, 'node_modules', '.bin', 'docusaurus');
const watcher = path.join(website, 'scripts', 'watch-flutter-embed.mjs');

console.log('[development] Building the shared Flutter previews...');
buildFlutterEmbed({mode: 'debug'});

const children = [
  spawn(process.execPath, [watcher], {cwd: website, stdio: 'inherit'}),
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
