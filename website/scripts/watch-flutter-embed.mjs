import {existsSync, statSync, watch} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

import {buildFlutterEmbed} from './build-flutter-embed.mjs';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const project = path.dirname(website);
const sources = [
  path.join(project, 'lib'),
  path.join(project, 'assets'),
  path.join(project, 'pubspec.yaml'),
  path.join(project, 'widgetbook', 'lib'),
  path.join(project, 'widgetbook', 'pubspec.yaml'),
  path.join(project, 'widgetbook', 'web'),
].filter(existsSync);

let debounce;
let rebuilding = false;
let rebuildAgain = false;

function rebuild() {
  if (rebuilding) {
    rebuildAgain = true;
    return;
  }

  rebuilding = true;
  console.log('\n[flutter-preview] Rebuilding after a shared Flutter source change...');

  try {
    buildFlutterEmbed({mode: 'debug'});
    console.log('[flutter-preview] Landing-page previews updated.');
  } catch (error) {
    console.error(`[flutter-preview] ${error.message}`);
  } finally {
    rebuilding = false;

    if (rebuildAgain) {
      rebuildAgain = false;
      rebuild();
    }
  }
}

function scheduleRebuild() {
  clearTimeout(debounce);
  debounce = setTimeout(rebuild, 250);
}

const watchers = sources.map((source) =>
  watch(source, {recursive: statSync(source).isDirectory()}, (_event, filename) => {
    if (filename?.includes('.dart_tool') || filename?.includes(`${path.sep}build${path.sep}`)) return;
    scheduleRebuild();
  }),
);

console.log('[flutter-preview] Watching app and Widgetbook sources.');

function close() {
  clearTimeout(debounce);
  watchers.forEach((watcher) => watcher.close());
}

process.on('SIGINT', close);
process.on('SIGTERM', close);
