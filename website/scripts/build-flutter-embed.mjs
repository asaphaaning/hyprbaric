import {spawnSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const project = path.dirname(website);
const widgetbook = path.join(project, 'widgetbook');
const output = path.join(website, 'static', 'flutter', 'previews');

export function buildFlutterEmbed({mode = 'release'} = {}) {
  if (mode !== 'debug' && mode !== 'release') {
    throw new Error(`Unsupported Flutter embed build mode: ${mode}`);
  }

  const result = spawnSync(
    'flutter',
    [
      'build',
      'web',
      `--${mode}`,
      '--target',
      'lib/embed.dart',
      '--output',
      output,
      '--no-web-resources-cdn',
    ],
    {cwd: widgetbook, stdio: 'inherit'},
  );

  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`Flutter embed build exited with status ${result.status ?? 'unknown'}.`);
  }

  writeFileSync(
    path.join(output, 'version.json'),
    `${JSON.stringify({version: Date.now()})}\n`,
  );
}

const invokedDirectly = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) {
  buildFlutterEmbed({mode: process.argv.includes('--debug') ? 'debug' : 'release'});
}
