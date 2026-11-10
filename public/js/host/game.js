// A játék menete: lobby -> tábla -> minijáték -> ... -> végeredmény

import * as net from './net.js';
import { G, byPid, newPlayer, statusOf, MAX_PLAYERS, resetForGame, humans } from './state.js';
import { setScene, current, shuffle, onSceneSwap } from './engine.js';
import { LobbyScene } from './lobby.js';
import { BoardScene, buildBoard } from './board.js';
import { MgSelectScene } from './mgflow.js';
import { FinalScene } from './final.js';

export const params = new URLSearchParams(location.search);

export function init() {
  net.setStatusProvider(statusOf);
  onSceneSwap(() => net.cancelAsks());

  net.on('join', (pid, name, isBot) => {
    let p = byPid(pid);
    if (p) {
      p.connected = true;
      if (name) p.name = name;
      net.resendLayout(pid);
      current()?.playersChanged?.();
      return;
    }
    if (G.phase !== 'lobby' || G.players.length >= MAX_PLAYERS) {
      net.setCtrl(pid, {
        mode: 'wait', icon: '⏳',
        title: G.phase !== 'lobby' ? 'A játék már folyik' : 'Megtelt a játék',
        text: 'Várd meg a következő játékot!',
      });
      return;
    }
    p = newPlayer(pid, name, isBot);
    G.players.push(p);
    updateVip();
    current()?.playersChanged?.();
  });

  net.on('leave', (pid) => {
    const p = byPid(pid);
    if (!p) return;
    p.connected = false;
    if (G.phase === 'lobby') {
      G.players.splice(G.players.indexOf(p), 1);
      updateVip();
    } else {
      net.markAway(pid);
    }
    current()?.playersChanged?.();
  });

  net.on('input', (pid, msg) => current()?.input(pid, msg));
}

export function updateVip() {
  const h = humans();
  if (!h.find((p) => p.pid === G.vip)) G.vip = h[0]?.pid ?? null;
}

export function goLobby() {
  G.phase = 'lobby';
  G.players = G.players.filter((p) => p.connected || p.isBot);
  G.players.forEach((p) => { p.ready = p.isBot; });
  updateVip();
  setScene(new LobbyScene());
}

export function startGame() {
  G.phase = 'board';
  G.board = buildBoard();
  G.round = 1;
  G.recentMg = [];
  G.players = shuffle(G.players);
  G.players.forEach((p) => { resetForGame(p); p.node = G.board.start; });
  G.crownNode = null;
  if (params.get('mg')) { setScene(new MgSelectScene(params.get('mg'))); return; }
  setScene(new BoardScene(true));
}

export function afterMinigame() {
  G.round++;
  if (G.round > G.maxRounds) {
    G.phase = 'final';
    setScene(new FinalScene());
  } else {
    setScene(new BoardScene(false));
  }
}
