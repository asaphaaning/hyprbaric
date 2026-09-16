import {existsSync, statSync, watch} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

import {buildBarEmbed} from './build-bar-embed.mjs';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const project = path.dirname(website);
const sources = [
  path.join(project, 'lib'),
  path.join(project, 'assets'),
  path.join(project, 'pubspec.yaml'),
  path.join(project, 'widgetbook', 'lib'),
  path.join(project, 'widgetbook', 'pubspec.yaml'),
  path.join(project, 'widgetbook', 'web'),
  // The search index regenerates inside the bar build, so docs edits ride
  // along (with a full rebuild, which is slow but always fresh).
  path.join(website, 'docs'),
  path.join(website, 'sidebars.js'),
].filter(existsSync);

const ignored = [`${path.sep}.dart_tool${path.sep}`, `${path.sep}build${path.sep}`];

let debounce;
let rebuilding = false;
let rebuildAgain = false;

async function rebuild() {
  if (rebuilding) {
    rebuildAgain = true;
    return;
  }

  rebuilding = true;
  console.log('\n[bar-embed] Rebuilding after a shared Flutter source change...');

  try {
    await buildBarEmbed({mode: 'debug'});
    console.log('[bar-embed] Site bar updated.');
  } catch (error) {
    console.error(`[bar-embed] ${error.message}`);
  } finally {
    rebuilding = false;
  }

  if (rebuildAgain) {
    rebuildAgain = false;
    await rebuild();
  }
}

function scheduleRebuild() {
  clearTimeout(debounce);
  debounce = setTimeout(() => {
    rebuild().catch((error) => {
      console.error(`[bar-embed] ${error.message}`);
    });
  }, 250);
}

/** Both filters are separator-anchored so a `buildings/` directory is watched. */
function isIgnored(filename) {
  if (!filename) return false;
  const normalized = `${path.sep}${filename}`;
  return ignored.some((fragment) => normalized.includes(fragment));
}

const watchers = sources.map((source) =>
  watch(source, {recursive: statSync(source).isDirectory()}, (_event, filename) => {
    if (isIgnored(filename)) return;
    scheduleRebuild();
  }),
);

console.log('[bar-embed] Watching app and Widgetbook sources.');

function close() {
  clearTimeout(debounce);
  watchers.forEach((watcher) => watcher.close());
}

process.on('SIGINT', close);
process.on('SIGTERM', close);
