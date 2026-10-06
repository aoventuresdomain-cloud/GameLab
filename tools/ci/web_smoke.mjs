// Plays one full Holdfast run in the web build, in headless Chrome, with the bot
// aura (?autoplay=1). Fails on a page error, a console error or no finished run.
//   node tools/ci/web_smoke.mjs http://localhost:8060/index.html?autoplay=1&seed=1 [timeout seconds]
import { chromium } from 'playwright-core';

const url = process.argv[2];
const timeoutMs = Number(process.argv[3] || 180) * 1000;
const problems = [];
let done = null;

const browser = await chromium.launch({
  channel: 'chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const page = await browser.newPage();
page.on('console', (msg) => {
  const text = msg.text();
  console.log(`[${msg.type()}] ${text}`);
  if (msg.type() === 'error' || /^(SCRIPT )?ERROR:/.test(text)) problems.push(text);
  if (text.startsWith('AUTOPLAY DONE ')) done = text.slice('AUTOPLAY DONE '.length);
});
page.on('pageerror', (err) => problems.push(`page error: ${err.message}`));

await page.goto(url);
const started = Date.now();
while (done === null && problems.length === 0 && Date.now() - started < timeoutMs) {
  await page.waitForTimeout(500);
}
await browser.close();

if (done === null && problems.length === 0) problems.push(`no finished run within ${timeoutMs / 1000} s`);
if (problems.length > 0) {
  for (const p of problems) console.error(`::error::web smoke: ${p}`);
  process.exit(1);
}
console.log(`web smoke passed in ${((Date.now() - started) / 1000).toFixed(1)} s: ${done}`);
