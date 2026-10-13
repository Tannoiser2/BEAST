// Prova della versione web con Playwright: carica il gioco, apre il menu, avvia una partita contro l'IA
// e controlla che in console non compaiano errori.
// Uso: godot --headless --export-release Web build/web/index.html
//      python3 -m http.server 8060 -d build/web &   node tests/web_test.js http://127.0.0.1:8060/
const { chromium } = require('playwright');

(async () => {
  const url = process.argv[2] || 'http://127.0.0.1:8060/';
  const out = process.argv[3] || 'web_shot';
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM || undefined,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  const logs = [];
  page.on('console', (m) => {
    logs.push(`[${m.type()}] ${m.text()}`);
    if (m.type() === 'error') errors.push(m.text());
  });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  await page.goto(url);
  // aspetta che il motore parta e che il menu sia disegnato
  await page.waitForFunction(() => document.querySelector('#status') === null ||
    getComputedStyle(document.querySelector('#status')).visibility === 'hidden' ||
    document.querySelector('#status').style.display === 'none', null, { timeout: 180000 }).catch(() => {});
  await page.waitForTimeout(8000);
  await page.screenshot({ path: out + '_menu.png', timeout: 120000 });
  // INIZIA PARTITA (in basso a sinistra nel menu, 1920x1080 scalato a 1280x720)
  const pos = (process.env.BS_START || '0.14,0.914').split(',').map(Number);
  await page.mouse.click(1280 * pos[0], 720 * pos[1]);
  await page.waitForTimeout(40000);
  await page.screenshot({ path: out + '_partita.png', timeout: 180000 }).catch((e) => logs.push('screenshot lento: ' + e.message.split('\n')[0]));
  // il tavolo deve rispondere al mouse: trascinamento col destro e rotella
  await page.mouse.move(640, 300);
  await page.mouse.down({ button: 'right' });
  for (let i = 1; i <= 8; i++) await page.mouse.move(640 + i * 25, 300 + i * 6);
  await page.mouse.up({ button: 'right' });
  for (let i = 0; i < 4; i++) await page.mouse.wheel(0, -120);
  await page.waitForTimeout(15000);
  await page.screenshot({ path: out + '_camera.png', timeout: 180000 }).catch((e) => logs.push('screenshot lento: ' + e.message.split('\n')[0]));
  await browser.close();
  const bad = errors.filter((e) => !/favicon/.test(e));
  console.log(logs.slice(-15).join('\n'));
  console.log(`ERRORI IN CONSOLE: ${bad.length}`);
  for (const e of bad.slice(0, 20)) console.log('  ' + e);
  process.exit(bad.length ? 1 : 0);
})();
