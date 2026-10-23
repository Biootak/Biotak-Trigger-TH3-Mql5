#!/usr/bin/env node
// BUILD HASH — one source identity for every stamp the panel and the log print.
//
// Ported from the MetaTrader 4 tree (tools/gen-build-hash.js) on 2026-10-23.
// MT4 has regenerated Biotak/BuildHash.mqh on every build since P-BUILD-08;
// this tree never did, so TH3_SRC_HASH stayed frozen at the value commit
// cf10c2d wrote and every MT5 build printed the same "Build src:" line no
// matter how much code had changed since. That is exactly the eight-day
// confusion the original fix was written to end.
//
// WHY IT EXISTS (MT4, verbatim): the stamps that answer "which build is on
// this chart?" used to be hand-typed strings. They never changed when the code
// changed, so two different builds printed the same line. The fix is to print
// a fact the SOURCE owns: a content hash over the bytes of every file the
// compiling unit actually contains — the entries, every `#include` they reach
// transitively, and every raster those units `#resource`.
//
//   same tree -> same hash -> same stamp (a re-compile is not a new build)
//   one edit  -> new hash  -> a different stamp (any edit is a new build)
//
// Two deliberate differences from the MT4 script, both because this tree owns
// its own layout:
//   * it walks the #include graph itself instead of importing
//     tools/check-resources.js (MT5 has no such gate);
//   * it keeps the OWNED MT5 banner at the top of Biotak/BuildHash.mqh and
//     rewrites only the generated block below it.
//
// USAGE:  node tools/gen-build-hash.js           -> rewrite Biotak/BuildHash.mqh
//         node tools/gen-build-hash.js --check   -> exit 1 if it is out of date
// Stdout (first line): hash=<16hex> short=<8hex> files=<n>

'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.dirname(__dirname);
const OUT = path.join(ROOT, 'Biotak', 'BuildHash.mqh');
const SELF = OUT; // the generated file is not part of its own input

// Both entries are separate compiling units; the hashed set is the union, so
// either build carries the identity of the whole tree (MT4 does the same).
const ENTRIES = ['Biotak Trigger TH3.mq5', 'Biotak Trigger TH3 Lite.mq5'];

const RE_INCLUDE = /^\s*#include\s+["<]([^">]+)[">]/gim;
const RE_RESOURCE = /^\s*#resource\s+"\\+Files\\+Icons\\+([^"]+)"/gim;

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function relOf(abs) {
  return path.relative(ROOT, abs).split(path.sep).join('/');
}

// MQL5 writes includes with backslashes and resolves them relative to the
// INCLUDING file first (MetaEditor also searches the terminal's Include dir,
// which this repository does not use). Anything unresolved is a hard failure:
// a silently skipped file would be a hash that lies about its own contents.
function resolveInclude(fromAbs, spec) {
  const norm = spec.replace(/\\/g, '/');
  const tries = [
    path.resolve(path.dirname(fromAbs), norm),
    path.resolve(ROOT, norm),
  ];
  for (const t of tries) {
    if (fs.existsSync(t) && fs.statSync(t).isFile()) return t;
  }
  console.error(`[FAIL] #include "${spec}" in ${relOf(fromAbs)} not found`);
  process.exit(1);
}

function rawFilesOf(entryAbs) {
  const seen = new Set();
  const order = [];

  const walk = (abs) => {
    const key = path.normcase ? path.normcase(abs) : abs.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    order.push(abs);
    const src = fs.readFileSync(abs, 'utf8');
    RE_INCLUDE.lastIndex = 0;
    let m;
    while ((m = RE_INCLUDE.exec(src)) !== null) {
      walk(resolveInclude(abs, m[1]));
    }
  };

  walk(entryAbs);
  return order;
}

// The hashed set: the two entries' include closure + the rasters they embed.
function sourceSet() {
  const files = new Set();
  for (const entry of ENTRIES) {
    const entryAbs = path.join(ROOT, entry);
    if (!fs.existsSync(entryAbs)) {
      console.error(`[FAIL] entry not found: ${entry}`);
      process.exit(1);
    }
    for (const abs of rawFilesOf(entryAbs)) {
      if (path.resolve(abs) === path.resolve(SELF)) continue; // not its own input
      files.add(path.resolve(abs));
      const src = fs.readFileSync(abs, 'utf8');
      RE_RESOURCE.lastIndex = 0;
      let m;
      while ((m = RE_RESOURCE.exec(src)) !== null) {
        const bmp = path.join(ROOT, 'Files', 'Icons', m[1]);
        if (fs.existsSync(bmp)) files.add(path.resolve(bmp));
        else {
          console.error(`[FAIL] #resource icon missing: Files/Icons/${m[1]}`);
          process.exit(1);
        }
      }
    }
  }
  return [...files].sort((a, b) => relOf(a) < relOf(b) ? -1 : 1);
}

function compute() {
  const files = sourceSet();
  const h = crypto.createHash('sha256');
  for (const f of files) {
    h.update(relOf(f) + '\n' + sha256(fs.readFileSync(f)) + '\n');
  }
  const hash = h.digest('hex').slice(0, 16);
  return { hash, short: hash.slice(0, 8), count: files.length };
}

const MARKER = '//| BuildHash.mqh';

// Keep whatever sits above the generated block — in this tree that is the
// OWNED MT5 banner every Biotak/ module carries. Never rewrite it here.
function ownedPrefix() {
  if (!fs.existsSync(OUT)) return '';
  const text = fs.readFileSync(OUT, 'utf8').replace(/^\ufeff/, '');
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const at = lines.findIndex((l) => l.trim().startsWith(MARKER));
  if (at < 1) return '';
  // drop the block's own //+--- ruler, keep the banner's CRLF so the file has
  // one line ending throughout (the generated body is CRLF too).
  return lines.slice(0, at - 1).join('\r\n') + '\r\n';
}

function render({ hash, short, count }) {
  const EOL = '\r\n';
  return [
    '//+------------------------------------------------------------------+',
    '//| BuildHash.mqh — GENERATED FILE. DO NOT EDIT.                      |',
    '//|                                                                   |',
    '//| Owner: tools/gen-build-hash.js, run by tools/mt5-build.ps1.       |',
    '//|                                                                   |',
    '//| TH3_SRC_HASH is a SHA-256 (16 hex chars) over the bytes of every  |',
    '//| file these entries compile: the two .mq5 entries, every .mqh they |',
    '//| #include transitively, and every raster they #resource. It is the |',
    '//| ONLY build identity the panel and the log print — a hand-typed tag |',
    '//| cannot change when the code changes, and that is how a stale ex5   |',
    '//| printed the same line as a fresh one for eight days.              |',
    '//|                                                                   |',
    '//| same tree -> same hash ; any edit -> a different hash              |',
    '//|                                                                   |',
    `//| files=${count} hash=${hash}`,
    '//+------------------------------------------------------------------+',
    '#ifndef TH3_BUILD_HASH_MQH',
    '#define TH3_BUILD_HASH_MQH',
    '',
    `#define TH3_SRC_HASH   "${hash}"   // full identity, printed in the log`,
    `#define TH3_SRC_SHORT  "${short}"           // the 8-char stamp the panel chip shows`,
    `#define TH3_SRC_FILES  ${count}                // files covered by the hash`,
    '',
    '#endif // TH3_BUILD_HASH_MQH',
    '',
  ].join(EOL);
}

const { hash, short, count } = compute();
const body = render({ hash, short, count });
const want = ownedPrefix() + body;
const check = process.argv.includes('--check');

if (check) {
  const have = fs.existsSync(OUT)
    ? fs.readFileSync(OUT, 'utf8').replace(/^\ufeff/, '')
    : '';
  if (have.replace(/\r\n/g, '\n') !== want.replace(/\r\n/g, '\n')) {
    console.error('[FAIL] Biotak/BuildHash.mqh is not the hash of this tree.');
    console.error(`       on disk: ${(have.match(/hash=([0-9a-f]{16})/) || [])[1] || 'none'}`);
    console.error(`       tree:    ${hash}`);
    console.error('       Run: node tools/gen-build-hash.js');
    process.exit(1);
  }
} else {
  // BOM, like every other Biotak/ module: MetaEditor reads these files as
  // UTF-8 only when the marker is there, and the banner carries an em dash.
  fs.writeFileSync(OUT, '\ufeff' + want);
}

console.log(`hash=${hash} short=${short} files=${count}`);
