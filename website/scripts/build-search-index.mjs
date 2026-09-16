import {mkdir, readdir, readFile, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

import sidebars from '../sidebars.js';

const website = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const output = path.join(website, 'static', 'flutter', 'bar', 'search-index.json');

export const outputFile = output;

/** Splits frontmatter from the body, so metadata never leaks into the index. */
function splitFrontmatter(raw) {
  const match = raw.match(/^---\n([\s\S]*?)\n---\n?/);
  if (!match) return {frontmatter: {}, body: raw};
  const frontmatter = {};
  for (const line of match[1].split('\n')) {
    const field = line.match(/^([A-Za-z_]+):\s*(.+)$/);
    if (field) frontmatter[field[1]] = field[2].trim();
  }
  return {frontmatter, body: raw.slice(match[0].length)};
}
function plainText(markdown) {
  return markdown
    .replace(/^```[\s\S]*?^```/gm, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/[`*_>#|\-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function inlineText(markdown) {
  return markdown
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/[`*_]/g, '')
    .trim();
}

/**
 * Builds the tiny search index the site bar searches locally.
 *
 * One entry per documentation page, in sidebar order, with its title,
 * section, headings, and a capped body. The bar bundle fetches this file
 * next to itself and ranks client-side, so no page-JS search bridge is
 * needed. Runs inside the bar embed build, which keeps it fresh.
 */
export async function buildSearchIndex() {
  const sections = new Map();
  for (const category of sidebars.docs ?? []) {
    for (const id of category.items ?? []) {
      sections.set(id, category.label);
    }
  }

  const docs = path.join(website, 'docs');
  const files = (await readdir(docs)).filter((file) => file.endsWith('.mdx'));

  const entries = [];
  for (const [id, section] of sections) {
    if (!files.includes(`${id}.mdx`)) continue;
    const raw = await readFile(path.join(docs, `${id}.mdx`), 'utf8');
    const {frontmatter, body: content} = splitFrontmatter(raw);
    // Sidebar labels read best as result titles ("Installation" rather than
    // the page's own sentence headings); the H1 is the fallback.
    const title = inlineText(
      frontmatter.sidebar_label ?? frontmatter.title
        ?? content.match(/^#\s+(.+)$/m)?.[1] ?? section ?? id,
    );
    const headings = [...content.matchAll(/^#{2,3}\s+(.+)$/gm)]
      .map((match) => inlineText(match[1]))
      .filter((heading) => heading.length > 0)
      .slice(0, 24);
    const body = plainText(content).slice(0, 4000);
    entries.push({title, url: `/docs/${id}`, section, headings, body});
  }

  await mkdir(path.dirname(output), {recursive: true});
  await writeFile(output, `${JSON.stringify(entries)}\n`);
  return entries.length;
}

const invokedDirectly = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) {
  try {
    const count = await buildSearchIndex();
    console.log(`[search-index] Wrote ${count} entries.`);
  } catch (error) {
    console.error(`[search-index] ${error.message}`);
    process.exitCode = 1;
  }
}
