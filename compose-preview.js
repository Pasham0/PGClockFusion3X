// Compose desktop + mobile screenshots into a side-by-side Preview.png
const fs = require('fs');
const puppeteer = require('puppeteer-core');

const OUT = '/root/subpasar/PGClockFusion3X/Preview.png';
const DESKTOP_PNG = process.env.DESKTOP_PNG || '/tmp/d1280-account.png';
const MOBILE_PNG = process.env.MOBILE_PNG || '/tmp/m390-account.png';

const CANVAS_W = 1800, CANVAS_H = 1100;
const DESKTOP_LEFT = 64, DESKTOP_TOP = 70, DESKTOP_SHOWN_W = 1246;
const MOBILE_LEFT = 1320, MOBILE_TOP = 120, MOBILE_SHOWN_W = 390;
const DESKTOP_CROP_H = Number(process.env.DESKTOP_CROP_H || 1010);
const MOBILE_CROP_H = Number(process.env.MOBILE_CROP_H || 880);

(async () => {
  for (const p of [DESKTOP_PNG, MOBILE_PNG]) {
    if (!fs.existsSync(p)) throw new Error(`missing ${p}`);
  }
  const desktop = fs.readFileSync(DESKTOP_PNG);
  const mobile = fs.readFileSync(MOBILE_PNG);
  const dw = desktop.readUInt32BE(16), dh = desktop.readUInt32BE(20);
  const mw = mobile.readUInt32BE(16), mh = mobile.readUInt32BE(20);
  console.log(`desktop ${dw}x${dh}, mobile ${mw}x${mh}`);

  const desktopScale = DESKTOP_SHOWN_W / dw;
  const mobileScale = MOBILE_SHOWN_W / mw;
  const desktopShownH = Math.round(Math.min(DESKTOP_CROP_H, dh) * desktopScale);
  const mobileShownH = Math.round(Math.min(MOBILE_CROP_H, mh) * mobileScale);

  const browser = await puppeteer.launch({
    executablePath: '/root/subpasar/chrome-headless-shell/linux-152.0.7973.0/chrome-headless-shell-linux64/chrome-headless-shell',
    protocolTimeout: 300000,
    timeout: 180000,
    args: ['--no-sandbox', '--disable-gpu', '--font-render-hinting=none', '--disable-dev-shm-usage',
           '--no-zygote', '--disable-extensions', '--js-flags=--max-old-space-size=200']
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: CANVAS_W, height: CANVAS_H, deviceScaleFactor: 1 });
    await page.setContent(`<!doctype html><html><body style="margin:0;width:${CANVAS_W}px;height:${CANVAS_H}px;overflow:hidden;
      background:linear-gradient(135deg, #0a0d1a 0%, #1a1f3a 50%, #0f1628 100%)">
      <div style="position:absolute;left:${DESKTOP_LEFT}px;top:${DESKTOP_TOP}px;width:${DESKTOP_SHOWN_W}px;height:${desktopShownH}px;
        overflow:hidden;border-radius:22px;
        box-shadow:0 40px 90px rgba(0,0,0,.6), 0 0 0 1px rgba(255,255,255,.07);">
        <img src="data:image/png;base64,${desktop.toString('base64')}" style="display:block;width:${DESKTOP_SHOWN_W}px">
      </div>
      <div style="position:absolute;left:${MOBILE_LEFT}px;top:${MOBILE_TOP}px;width:${MOBILE_SHOWN_W}px;height:${mobileShownH}px;
        overflow:hidden;border-radius:32px;
        box-shadow:0 30px 70px rgba(0,0,0,.5), 0 0 0 1px rgba(255,255,255,.09);">
        <img src="data:image/png;base64,${mobile.toString('base64')}" style="display:block;width:${MOBILE_SHOWN_W}px">
      </div>
    </body></html>`, { waitUntil: 'load', timeout: 120000 });
    await new Promise(r => setTimeout(r, 800));
    await page.screenshot({ path: OUT });
    console.log('saved', OUT);
  } finally {
    await browser.close().catch(() => {});
  }
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });
