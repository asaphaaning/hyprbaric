import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = (await readFile(new URL('../../widgetbook/web/flutter_bootstrap.js', import.meta.url), 'utf8'))
  .replace('{{flutter_js}}', '')
  .replace('{{flutter_build_config}}', '');

for (const catalog of [false, true]) {
  test(catalog ? 'catalog retains its implicit view' : 'embeds use independent render surfaces in one engine', async () => {
    let engineCount = 0;
    const app = {};
    const window = {};
    vm.runInNewContext(source, {
      URL,
      window,
      document: {
        currentScript: {src: 'http://localhost/flutter/previews/flutter_bootstrap.js'},
        body: {hasAttribute: (name) => name === 'data-hyprbaric-catalog' && catalog},
      },
      _flutter: {loader: {load: ({config, onEntrypointLoaded}) => {
        assert.equal(config.canvasKitForceMultiSurfaceRasterizer, !catalog);
        onEntrypointLoaded({initializeEngine: async (options) => {
          engineCount++;
          assert.equal(options.multiViewEnabled, !catalog);
          assert.equal(options.canvasKitForceMultiSurfaceRasterizer, !catalog);
          return {runApp: async () => app};
        }});
      }}},
    });
    assert.equal(await window.hyprbaricEmbedsReady, app);
    assert.equal(engineCount, 1);
  });
}
