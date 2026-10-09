import { spawn, ChildProcess } from 'child_process';
import os from 'os';
import path from 'path';
import fs from 'fs';

let tunnelProcess: ChildProcess | null = null;
let currentTunnelUrl: string | null = null;

export function getTunnelUrl(): string | null {
  return currentTunnelUrl;
}

/**
 * Spawns cloudflared tunnel in background if available
 */
export function startCloudflareTunnel(
  port: number,
  onUrlDiscovered?: (url: string) => void
): void {
  // If already running, return
  if (tunnelProcess) return;

  const homeDir = os.homedir();
  const userBinary = path.join(homeDir, '.local/bin/cloudflared');

  let binaryPath = 'cloudflared';
  if (fs.existsSync(userBinary)) {
    binaryPath = userBinary;
  }

  try {
    const proc = spawn(binaryPath, ['tunnel', '--url', `http://localhost:${port}`], {
      stdio: ['ignore', 'pipe', 'pipe'],
      detached: false,
    });

    tunnelProcess = proc;

    const handleOutput = (data: Buffer) => {
      const text = data.toString();
      // Match trycloudflare.com URL pattern
      const match = text.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
      if (match && !currentTunnelUrl) {
        currentTunnelUrl = match[0];
        console.log('\n=========================================');
        console.log('📱 TELEFONOS CSATLAKOZÁS KÉSZ! (CLOUDFLARE TUNNEL)');
        console.log('KÖZVETLEN LINK A TELEFONODHOZ (NINCS JELSZÓ, BÁRHONNAN MŰKÖDIK):');
        console.log(`👉 ${currentTunnelUrl}/join`);
        console.log('=========================================\n');
        if (onUrlDiscovered) {
          onUrlDiscovered(currentTunnelUrl);
        }
      }
    };

    proc.stdout.on('data', handleOutput);
    proc.stderr.on('data', handleOutput);

    proc.on('error', (err) => {
      // cloudflared not installed or failed, silently fallback to LAN
      console.log('ℹ️ Cloudflare tunnel nem indítható el, normál LAN módban folytatjuk:', err.message);
      tunnelProcess = null;
    });

    proc.on('exit', () => {
      tunnelProcess = null;
      currentTunnelUrl = null;
    });

    const cleanExit = () => {
      if (tunnelProcess) {
        try {
          tunnelProcess.kill('SIGTERM');
        } catch (_) {}
        tunnelProcess = null;
      }
    };

    process.on('exit', cleanExit);
    process.on('SIGINT', cleanExit);
    process.on('SIGTERM', cleanExit);
  } catch (err: any) {
    console.log('ℹ️ Cloudflare tunnel indítás sikertelen:', err.message);
  }
}
