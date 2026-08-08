// Capture full-page desktop screenshots of all three views into /tmp for review.
const http = require('http');
const fs = require('fs');
const puppeteer = require('puppeteer-core');

const MOCK_USER = {
  username: "parniya",
  status: "active",
  used_traffic: 1.7 * 1073741824,
  data_limit: 48 * 1073741824,
  lifetime_used_traffic: 21.5 * 1073741824,
  expire: Math.floor(Date.now() / 1000) + 27 * 86400,
  created_at: Math.floor(Date.now() / 1000) - 3 * 86400,
  edit_at: Math.floor(Date.now() / 1000) - 86400,
  online_at: Math.floor(Date.now() / 1000) - 40,
  ip: "85.9.121.44",
  hwid_limit: 3
};
const MOCK_LINKS = [
  "vless://uuid1@sw1.example.com:443?security=tls&type=ws#Sweden%20-parniya",
  "vless://uuid2@de1.example.com:8080?security=tls&type=xhttp#Germany%20-parniya",
  "vmess://" + Buffer.from(JSON.stringify({ps:"Finland -parniya", add:"fi.example.com", port:443, tls:"tls", net:"grpc"})).toString('base64'),
  "trojan://pass@nl.example.com:443?security=tls&type=tcp#Netherlands%20-parniya",
  "wireguard://cHJpdmF0ZWtleQ==@tr.example.com:51820?publickey=cHVi&address=10.0.0.2/32#Turkey%20-parniya"
];
const MOCK_APPS = [
  { name: "V2rayNG", platform: "android", recommended: true, url: "https://example.com/v2rayng.apk" },
  { name: "Hiddify", platform: "windows", url: "https://example.com/hiddify.exe" },
  { name: "Streisand", platform: "ios", url: "https://apps.apple.com/app/streisand" },
  { name: "Hiddify", platform: "macos", url: "https://example.com/hiddify.dmg" },
  { name: "NekoBox", platform: "linux", url: "https://example.com/nekobox" }
];
function mockUsage() {
  const stats = []; const vals = [310,420,180,520,760,240,610,90,450,380,700,260,540,330,470,620,150,410,580,290,360,680,220,490];
  for (let i = 23; i >= 0; i--) stats.push({ period_start: new Date(Date.now() - i * 3600000).toISOString(), total_traffic: vals[i] * 1048576 });
  return { stats };
}

const PORT = 18925;
const FLAGS = {
  se: '<circle cx="256" cy="256" r="256" fill="#0058a3"/><rect x="118" y="0" width="76" height="512" fill="#ffcd00"/><rect x="0" y="218" width="512" height="76" fill="#ffcd00"/>',
  de: '<circle cx="256" cy="256" r="256" fill="#d80027"/><path d="M16 342h480a256 256 0 0 1-480 0z" fill="#ffce00"/><path d="M16 170h480a256 256 0 0 0-480 0z" fill="#111"/>',
  fi: '<circle cx="256" cy="256" r="256" fill="#f0f0f0"/><rect x="130" y="0" width="80" height="512" fill="#003580"/><rect x="0" y="216" width="512" height="80" fill="#003580"/>',
  nl: '<circle cx="256" cy="256" r="256" fill="#f0f0f0"/><path d="M16 170h480a256 256 0 0 0-480 0z" fill="#ae1c28"/><path d="M16 342h480a256 256 0 0 1-480 0z" fill="#21468b"/>',
  tr: '<circle cx="256" cy="256" r="256" fill="#e30a17"/><circle cx="230" cy="256" r="90" fill="#fff"/><circle cx="250" cy="256" r="72" fill="#e30a17"/><path d="M320 256l60-20-37 51v-62l37 51z" fill="#fff"/>'
};
const server = http.createServer((req, res) => {
  const json = b => { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify(b)); };
  if (req.url.includes('/sub/') && req.url.includes('/info')) return json(MOCK_USER);
  if (req.url.includes('/sub/') && req.url.includes('/links')) return json(MOCK_LINKS);
  if (req.url.includes('/sub/') && req.url.includes('/apps')) return json(MOCK_APPS);
  if (req.url.includes('/sub/') && req.url.includes('/usage')) return json(mockUsage());
  if (req.url.startsWith('/index.html')) {
    let html = fs.readFileSync('/root/subpasar/PGClockFusion3X/index.html', 'utf8');
    html = html.replace(/https:\/\/cdn\.jsdelivr\.net\/gh\/rastikerdar\/vazirmatn[^"]+/g, '/vazirmatn.woff2');
    html = html.replace(/https:\/\/cdn\.jsdelivr\.net\/gh\/HatScripts\/circle-flags@[^/]+\/flags\//g, '/flags/');
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    return res.end(html);
  }
  if (req.url === '/vazirmatn.woff2') {
    res.writeHead(200, { 'content-type': 'font/woff2' });
    return res.end(fs.readFileSync('/root/subpasar/.fonts/Vazirmatn.woff2'));
  }
  const flag = req.url.match(/^\/flags\/(\w\w)\.svg$/);
  if (flag) {
    res.writeHead(200, { 'content-type': 'image/svg+xml' });
    return res.end(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">${FLAGS[flag[1]] || '<circle cx="256" cy="256" r="256" fill="#888"/>'}</svg>`);
  }
  res.writeHead(404); res.end();
});

async function withBrowser(fn) {
  const browser = await puppeteer.launch({
    executablePath: '/root/subpasar/chrome-headless-shell/linux-152.0.7973.0/chrome-headless-shell-linux64/chrome-headless-shell',
    protocolTimeout: 300000,
    timeout: 180000,
    args: ['--no-sandbox', '--disable-gpu', '--font-render-hinting=none', '--disable-dev-shm-usage', '--no-zygote', '--disable-extensions', '--js-flags=--max-old-space-size=200']
  });
  try { return await fn(browser); } finally { await browser.close().catch(() => {}); }
}

async function capture(browser, viewport, view, out) {
  const page = await browser.newPage();
  await page.setRequestInterception(true);
  page.on('request', req => {
    if (!req.url().startsWith(`http://localhost:${PORT}`)) return req.abort().catch(() => {});
    req.continue();
  });
  await page.setViewport(viewport);
  let loaded = false;
  for (let attempt = 0; attempt < 4 && !loaded; attempt++) {
    try {
      await page.goto(`http://localhost:${PORT}/index.html?token=demo123token`, { waitUntil: 'domcontentloaded', timeout: 120000 });
      loaded = true;
    } catch (e) { console.log('goto retry', attempt + 1, e.message); }
  }
  if (!loaded) throw new Error('page failed to load');
  const hasData = () => page.evaluate(() => {
    const u = document.getElementById('username');
    return !!u && u.textContent.trim() !== '—' && u.textContent.trim() !== '';
  });
  let ready = false;
  for (let round = 0; round < 3 && !ready; round++) {
    if (round) {
      console.log('data not loaded, reloading (round', round + 1, ')');
      await page.reload({ waitUntil: 'domcontentloaded', timeout: 120000 }).catch(() => {});
    }
    for (let i = 0; i < 45 && !ready; i++) {
      ready = await hasData();
      if (!ready) await new Promise(r => setTimeout(r, 1000));
    }
  }
  if (!ready) throw new Error('mock data never rendered');
  await page.evaluate(v => document.body.setAttribute('data-view', v), view);
  for (let i = 0; i < 20; i++) {
    const done = await page.evaluate(() =>
      Array.from(document.querySelectorAll('img.flag-svg')).every(im => im.complete && im.naturalWidth > 0));
    if (done) break;
    await new Promise(r => setTimeout(r, 300));
  }
  if (process.argv[4]) { await page.evaluate(process.argv[4]); await new Promise(r => setTimeout(r, 600)); }
  await new Promise(r => setTimeout(r, 1200));
  const h = await page.evaluate(() => document.documentElement.scrollHeight);
  await page.setViewport({ ...viewport, height: Math.min(h + 20, 4000) });
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: out, type: 'png' });
  console.log('saved', out);
  await page.close();
}

(async () => {
  await new Promise(r => server.listen(PORT, r));
  const width = Number(process.argv[2] || 1280);
  const views = (process.argv[3] || 'account,configs,apps').split(',');
  for (const v of views) {
    await withBrowser(b => capture(b, { width, height: 900, deviceScaleFactor: 1 }, v, `/tmp/d${width}-${v}.png`));
  }
  server.close();
  process.exit(0);
})();
