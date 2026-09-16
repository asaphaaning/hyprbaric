import assert from 'node:assert/strict';
import test from 'node:test';

import {
  attachPreview,
  canReusePreview,
  detachPreview,
} from '../src/components/FlutterDemo/previewEngine.js';

function element() {
  const node = {
    style: {},
    isConnected: true,
    parent: null,
    children: [],
    append(child) {
      if (child.parent?.children) {
        child.parent.children = child.parent.children.filter((node) => node !== child);
      }
      child.parent = this;
      child.isConnected = true;
      this.children.push(child);
    },
    remove() {
      if (!this.parent) return;
      this.parent.children = this.parent.children.filter((child) => child !== this);
      this.parent = null;
      this.isConnected = false;
    },
    getBoundingClientRect() {
      return {width: 320, height: 480};
    },
  };
  return node;
}

function documentStub() {
  const body = element();
  const nodes = new Map();
  return {
    body,
    head: element(),
    createElement(tag) {
      const node = element();
      node.tagName = tag;
      node.setAttribute = (name, value) => {
        node[name] = value;
        if (name === 'id') nodes.set(value, node);
      };
      Object.defineProperty(node, 'id', {
        configurable: true,
        get() {
          return node._id;
        },
        set(value) {
          node._id = value;
          nodes.set(value, node);
        },
      });
      if (tag === 'script') {
        queueMicrotask(() => node.listeners?.load?.());
      }
      node.addEventListener = (type, handler) => {
        node.listeners = {...node.listeners, [type]: handler};
      };
      return node;
    },
    getElementById(id) {
      return nodes.get(id) ?? null;
    },
    remember(id, node) {
      nodes.set(id, node);
    },
  };
}

test('a second attach reuses the parked view instead of adding another', async () => {
  const added = [];
  const app = {
    addView(options) {
      added.push(options.initialData.preview);
      return added.length;
    },
    removeView() {
      throw new Error('should not remove a parked view');
    },
  };

  const document = documentStub();
  globalThis.document = document;
  globalThis.window = {
    setTimeout,
    clearTimeout,
    hyprbaricEmbedsReady: Promise.resolve(app),
  };

  const first = document.createElement('div');
  const second = document.createElement('div');

  await attachPreview({
    preview: 'mixer',
    parent: first,
    bootstrapUrl: '/flutter/previews/flutter_bootstrap.js?v=1',
    onReady: () => {},
  });
  assert.equal(added.length, 1);
  assert.equal(first.children.length, 1);

  const host = first.children[0];
  first.children = [];
  host.parent = null;
  host.isConnected = false;
  detachPreview('mixer');
  assert.equal(host.isConnected, true);
  assert.equal(host.style.width, '1px');
  assert.equal(document.getElementById('hyprbaric-preview-parking') != null, true);
  assert.equal(
    canReusePreview('mixer', '/flutter/previews/flutter_bootstrap.js?v=1'),
    true,
  );

  await attachPreview({
    preview: 'mixer',
    parent: second,
    bootstrapUrl: '/flutter/previews/flutter_bootstrap.js?v=1',
    onReady: () => {},
  });
  assert.equal(added.length, 1);
  assert.equal(second.children.length, 1);
  assert.equal(second.children[0].style.width, '100%');

  await attachPreview({
    preview: 'mixer',
    parent: document.createElement('div'),
    bootstrapUrl: '/flutter/previews/flutter_bootstrap.js?v=1',
    onReady: () => {},
  });
  assert.equal(added.length, 1);
});
