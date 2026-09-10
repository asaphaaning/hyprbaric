import {spawn} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const project = path.dirname(website);
const widgetbook = path.join(project, 'widgetbook');
const output = path.join(website, 'static', 'flutter', 'bar');

export const outputDirectory = output;

/**
 * Builds the site bar as its own single-view engine into the site's static
 * directory. The bar must not share the previews' multi-view engine: engine
 * views no longer keep their own sizes once several share one engine (every
 * view converges onto the latest one's), while the iframe viewport sizes a
 * single view exactly.
 */
export function buildBarEmbed({mode = 'release'} = {}) {
  if (mode !== 'debug' && mode !== 'release') {
    throw new Error(`Unsupported bar embed build mode: ${mode}`);
  }

  return new Promise((resolve, reject) => {
    const child = spawn(
      'flutter',
      [
        'build',
        'web',
        `--${mode}`,
        '--target',
        'lib/bar_site_embed.dart',
        '--output',
        output,
        '--no-web-resources-cdn',
        // The iframe resolves the bundle relative to its own page, so the
        // placeholder base href has to name the deployed directory. This
        // mirrors `baseUrl` in docusaurus.config.js.
        '--base-href',
        '/hyprbaric/flutter/bar/',
      ],
      {cwd: widgetbook, stdio: 'inherit'},
    );

    child.on('error', reject);
    child.on('exit', async (code, signal) => {
      if (signal) {
        reject(new Error(`Bar embed build was terminated by ${signal}.`));
        return;
      }
      if (code !== 0) {
        reject(new Error(`Bar embed build exited with status ${code ?? 'unknown'}.`));
        return;
      }

      try {
        // Written last, and only on success: the host treats this file as the
        // signal that a complete build is in place.
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
    await buildBarEmbed({mode: process.argv.includes('--debug') ? 'debug' : 'release'});
  } catch (error) {
    console.error(`[bar-embed] ${error.message}`);
    process.exitCode = 1;
  }
}
