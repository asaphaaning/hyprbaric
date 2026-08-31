import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const project = path.dirname(website);
const widgetbook = path.join(project, 'widgetbook');
const output = path.join(website, 'static', 'flutter', 'previews');

const result = spawnSync(
  'flutter',
  [
    'build',
    'web',
    '--release',
    '--target',
    'lib/embed.dart',
    '--output',
    output,
    '--no-web-resources-cdn',
  ],
  {cwd: widgetbook, stdio: 'inherit'},
);

if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
