import {spawn} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const project = path.dirname(website);
const widgetbook = path.join(project, 'widgetbook');
const output = path.join(website, 'static', 'flutter', 'previews');

export const outputDirectory = output;

/**
 * Builds the shared Flutter embed into the site's static directory.
 *
 * Asynchronous on purpose: a synchronous build blocks the event loop for the
 * whole compile, which stalls the watcher's own signal handling and makes any
 * re-entrancy guard around it meaningless.
 */
export function buildFlutterEmbed({mode = 'release'} = {}) {
  if (mode !== 'debug' && mode !== 'release') {
    throw new Error(`Unsupported Flutter embed build mode: ${mode}`);
  }

  return new Promise((resolve, reject) => {
    const child = spawn(
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

    child.on('error', reject);
    child.on('exit', async (code, signal) => {
      if (signal) {
        reject(new Error(`Flutter embed build was terminated by ${signal}.`));
        return;
      }
      if (code !== 0) {
        reject(new Error(`Flutter embed build exited with status ${code ?? 'unknown'}.`));
        return;
      }

      try {
        // Written last, and only on success: the host treats this file as the
        // signal that a complete build is in place, and `flutter build`
        // recreates the output directory on every run.
        await writeFile(
          path.join(output, 'version.json'),
          `${JSON.stringify({version: Date.now()})}\n`,
        );
        resolve();
      } catch (error) {
        reject(error);
      }
    });
  });
}

const invokedDirectly = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) {
  try {
    await buildFlutterEmbed({mode: process.argv.includes('--debug') ? 'debug' : 'release'});
  } catch (error) {
    console.error(`[flutter-preview] ${error.message}`);
    process.exitCode = 1;
  }
}
