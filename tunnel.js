// Cloudflare quick tunnel + szerver: a QR-kód a nyilvános https címre mutat,
// így a telefonok bármilyen hálózatról (mobilnetről is) csatlakozhatnak.
const { spawn } = require('child_process');

const PORT = Number(process.env.PORT) || 3000;
const cf = spawn('cloudflared', ['tunnel', '--no-autoupdate', '--url', `http://localhost:${PORT}`]);
let started = false;

function onData(buf) {
  const m = String(buf).match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com/);
  if (m && !started) {
    started = true;
    process.env.PUBLIC_URL = m[0];
    require('./server.js');
  }
}
cf.stdout.on('data', onData);
cf.stderr.on('data', onData);
cf.on('error', (e) => { console.error('cloudflared nem indítható:', e.message); process.exit(1); });
cf.on('exit', (code) => { console.error(`cloudflared kilépett (${code})`); process.exit(1); });
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => { cf.kill(); process.exit(0); });
