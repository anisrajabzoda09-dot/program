// Файл: санҷиши браузерии саҳифаҳои сайт (Chrome headless, CDP) — хатоҳои JavaScript,
// вайронкунии CSP, scroll-и уфуқӣ ва скриншотҳо дар андозаҳо ва мавзӯъҳои гуногун.
//
// Истифода: node scripts/qa/page_qa.mjs http://127.0.0.1:8902 /tmp/out / /faq /ru/get
// Андозаҳо: SIZES='[[390,844,"light"],[1440,900,"dark"]]' (бо пешфарз се андоза).
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';

const [BASE, OUT, ...paths] = process.argv.slice(2);
mkdirSync(OUT, { recursive: true });
const PORT = 9347;
const chrome = spawn('google-chrome', ['--headless=new', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
  `--remote-debugging-port=${PORT}`, `--user-data-dir=/tmp/pageqa_prof_${process.pid}`, 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Ба DevTools пайваст мешавад.
let url;
for (let i = 0; i < 50 && !url; i++) {
  try { url = (await (await fetch(`http://127.0.0.1:${PORT}/json`)).json()).find(t => t.type === 'page')?.webSocketDebuggerUrl; } catch {}
  await sleep(200);
}
const ws = new WebSocket(url);
await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pending = new Map(); let errs = [];
ws.addEventListener('message', m => {
  const x = JSON.parse(m.data);
  if (x.id && pending.has(x.id)) { pending.get(x.id)(x); pending.delete(x.id); return; }
  if (x.method === 'Runtime.exceptionThrown') errs.push(x.params.exceptionDetails.exception?.description?.split('\n')[0]);
  if (x.method === 'Log.entryAdded' && x.params.entry.level === 'error') errs.push('LOG ' + x.params.entry.text + ' ' + (x.params.entry.url || ''));
  if (x.method === 'Runtime.consoleAPICalled' && x.params.type === 'error') errs.push('CONSOLE ' + x.params.args.map(a => a.value || a.description).join(' '));
});
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const ev = async e => (await send('Runtime.evaluate', { expression: e, returnByValue: true, awaitPromise: true })).result?.result?.value;
await send('Page.enable'); await send('Runtime.enable'); await send('Log.enable');

const sizes = process.env.SIZES ? JSON.parse(process.env.SIZES) : [[360, 780, 'light'], [1440, 900, 'dark'], [1440, 900, 'light']];
let fail = 0;
for (const path of paths) {
  for (const [w, h, theme] of sizes) {
    errs = [];
    await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: w < 500 });
    await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: theme }, { name: 'prefers-reduced-motion', value: 'reduce' }] });
    const sc = await send('Page.addScriptToEvaluateOnNewDocument', { source: `try{localStorage.setItem('nigoh-theme','${theme}')}catch(e){}` });
    await send('Page.navigate', { url: BASE + path }); await sleep(1600);
    await send('Page.removeScriptToEvaluateOnNewDocument', { identifier: sc.result.identifier });
    const ox = await ev(`Math.max(document.documentElement.scrollWidth,document.body.scrollWidth)-innerWidth`);
    const full = await ev(`Math.min(document.documentElement.scrollHeight,6000)`);
    await send('Emulation.setDeviceMetricsOverride', { width: w, height: full, deviceScaleFactor: 1, mobile: w < 500 }); await sleep(250);
    const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 70 });
    writeFileSync(`${OUT}/${path.replace(/\W+/g, '_') || 'home'}_${w}_${theme}.jpg`, Buffer.from(shot.result.data, 'base64'));
    const bad = ox > 0 || errs.length;
    if (bad) fail++;
    console.log(`${bad ? 'FAIL' : 'ok  '} ${path} ${w} ${theme} overflowX=${ox} errors=${errs.length}${errs.length ? ' | ' + errs.join(' ; ') : ''}`);
  }
}
ws.close(); chrome.kill(); process.exit(fail ? 1 : 0);
