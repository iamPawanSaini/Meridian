// TC-T03-32 fallback: syntax-level parse of each mermaid block with mermaid.parse().
// Parse only: this does NOT lay out or render. mermaid is loaded from the npx cache of mermaid-cli.
import { readFileSync, readdirSync } from 'node:fs';

const root = process.argv[2];
const dir = process.argv[3];
// No DOM in plain node: stub DOMPurify hooks so the diagram parsers (which are DOM-free) can run.
const purify = (await import(root + '/dompurify/dist/purify.es.mjs')).default;
purify.addHook = purify.addHook || (() => {});
purify.removeHook = purify.removeHook || (() => {});
purify.sanitize = purify.sanitize && purify.isSupported ? purify.sanitize : (s) => s;
const mermaid = (await import(root + '/mermaid/dist/mermaid.core.mjs')).default;
let fail = 0;
const files = readdirSync(dir)
  .filter((x) => x.endsWith('.mmd'))
  .sort();
for (const f of files) {
  try {
    const r = await mermaid.parse(readFileSync(dir + '/' + f, 'utf8'));
    console.log(`PARSE-OK  ${f} diagramType=${r.diagramType}`);
  } catch (e) {
    fail++;
    console.log(`PARSE-ERR ${f}: ${String(e.message || e).split('\n').slice(0, 4).join(' | ')}`);
  }
}
console.log(`mermaid-version=12.3.0 failures=${fail}`);
process.exit(fail ? 1 : 0);
