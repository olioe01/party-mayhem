import { start, setScene } from './engine.js';
import { initAudio, toggleMute } from './audio.js';
import { init, params } from './game.js';
import { LobbyScene } from './lobby.js';
import * as net from './net.js';
import { G } from './state.js';

init();

const overlay = document.getElementById('start');
let started = false;

async function begin() {
  if (started) return;
  started = true;
  overlay.style.display = 'none';
  initAudio();
  try { await document.fonts.load('700 32px Fredoka'); } catch { /* offline: tartalék betűtípus */ }
  setScene(new LobbyScene(), true);
  start();
  // teszteléshez: ?bots=3 gépi játékosokat ad hozzá
  const nb = Math.min(7, Number(params.get('bots')) || 0);
  for (let i = 0; i < nb; i++) net.addBot(`Bot ${i + 1}`);
  if (params.get('rounds')) G.maxRounds = Math.max(1, Number(params.get('rounds')));
}

overlay.addEventListener('click', begin);
if (params.has('autostart')) begin();

addEventListener('keydown', (e) => {
  if (e.key === 'm' || e.key === 'M') toggleMute();
  if (e.key === 'f' || e.key === 'F') {
    if (document.fullscreenElement) document.exitFullscreen();
    else document.documentElement.requestFullscreen?.();
  }
});
