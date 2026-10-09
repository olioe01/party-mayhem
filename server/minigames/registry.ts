import { RoomState, MinigameResultEntry } from '../../shared/types';
import { MinigameDefinition } from './types';
import { MINIGAME_COIN_REWARDS } from '../../shared/constants';
import { fruitFrenzyMinigame } from './fruitFrenzy';
import { bombDodgeMinigame } from './bombDodge';
import { coinScrambleMinigame } from './coinScramble';
import { treasureGrabMinigame } from './treasureGrab';
import { pushArenaMinigame } from './pushArena';
import { crownChaseMinigame } from './crownChase';
import { paintPanicMinigame } from './paintPanic';
import { deliveryDashMinigame } from './deliveryDash';
import { floorIsLavaMinigame } from './floorIsLava';
import { monsterEscapeMinigame } from './monsterEscape';
import { controllerTestMinigame } from './controllerTest';

// Helper to assign ranks and coin rewards based on score descending
function assignResultsFromScores(
  room: RoomState,
  scores: { playerId: string; score: number; extraInfo?: string }[]
): MinigameResultEntry[] {
  // Sort descending by score
  const sorted = [...scores].sort((a, b) => b.score - a.score);
  return sorted.map((entry, index) => {
    let coins = MINIGAME_COIN_REWARDS[index] || 1;
    // Check if player had BOOST active (+50%)
    const player = room.players[entry.playerId];
    if (player && player.boostActive) {
      coins = Math.round(coins * 1.5);
    }
    // Check if player had TRAP active (-2 coins, min 1)
    if (player && player.trapActive) {
      coins = Math.max(1, coins - 2);
    }
    return {
      playerId: entry.playerId,
      score: entry.score,
      rank: index + 1,
      coinsEarned: coins,
      extraInfo: entry.extraInfo
    };
  });
}

export const MINIGAMES: Record<string, MinigameDefinition> = {
  // CORE ARENA GAMEPAD MINIGAMES
  'fruit-frenzy': fruitFrenzyMinigame,
  'bomb-dodge': bombDodgeMinigame,
  'coin-scramble': coinScrambleMinigame,
  'treasure-grab': treasureGrabMinigame,
  'delivery-dash': deliveryDashMinigame,
  'floor-is-lava': floorIsLavaMinigame,
  'monster-escape': monsterEscapeMinigame,
  'push-arena': pushArenaMinigame,
  'crown-chase': crownChaseMinigame,
  'paint-panic': paintPanicMinigame,
  'controller-test': controllerTestMinigame,

  // 1. REACTION RUSH
  'reaction-rush': {
    id: 'reaction-rush',
    name: 'REACTION RUSH',
    description: 'Várd meg a GO! jelzést, majd nyomd le a gombot a leggyorsabban!',
    duration: 10,
    instructions: 'VÁRJ A GO-RA! Ha korán nyomod, kiesel!',
    setup(room) {
      const goDelay = 2.5 + Math.random() * 3.5; // between 2.5s and 6s
      room.activeMinigame!.data = {
        goDelay,
        elapsed: 0,
        goTriggered: false,
        reactions: {} as Record<string, { time: number; falseStart: boolean }>
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.reactions[playerId]) return;
      if (!mgData.goTriggered) {
        // False start!
        mgData.reactions[playerId] = { time: 99999, falseStart: true };
      } else {
        const reactionMs = Math.round((mgData.elapsed - mgData.goDelay) * 1000);
        mgData.reactions[playerId] = { time: reactionMs, falseStart: false };
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      mgData.elapsed += dt;
      if (mgData.elapsed >= mgData.goDelay && !mgData.goTriggered) {
        mgData.goTriggered = true;
      }
      // Bot actions
      if (mgData.goTriggered) {
        Object.values(room.players).forEach(p => {
          if (p.isBot && !mgData.reactions[p.id]) {
            const botDelay = 0.25 + Math.random() * 0.45; // 250-700ms reaction
            if (mgData.elapsed >= mgData.goDelay + botDelay) {
              const reactionMs = Math.round(botDelay * 1000);
              mgData.reactions[p.id] = { time: reactionMs, falseStart: false };
            }
          }
        });
      }
      // Check if everyone reacted
      const playerIds = Object.keys(room.players);
      const allReacted = playerIds.every(id => mgData.reactions[id]);
      return allReacted;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const reactions = mgData.reactions || {};
      const scores = Object.keys(room.players).map(id => {
        const r = reactions[id];
        if (!r) return { playerId: id, score: 0, extraInfo: 'Nem reagált' };
        if (r.falseStart) return { playerId: id, score: -100, extraInfo: 'KORAI RAJT! (False Start)' };
        return { playerId: id, score: Math.max(1, 10000 - r.time), extraInfo: `${r.time} ms` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 2. SHAKE IT
  'shake-it': {
    id: 'shake-it',
    name: 'SHAKE IT',
    description: 'Rázd a telefont (vagy nyomd hipergyorsan a gombot), hogy a rakétád a legmagasabbra repüljön!',
    duration: 10,
    instructions: 'RÁZD VAGY TAPELD GŐZERŐVEL 10 MÁSODPERCIG!',
    setup(room) {
      const shakes: Record<string, number> = {};
      Object.keys(room.players).forEach(id => (shakes[id] = 0));
      room.activeMinigame!.data = { shakes };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const shakes = room.activeMinigame?.data?.shakes;
      if (!shakes) return;
      const count = Number(data?.intensity) || 1;
      shakes[playerId] = (shakes[playerId] || 0) + count;
    },
    update(room, dt) {
      const shakes = room.activeMinigame?.data?.shakes;
      if (!shakes) return false;
      // Bot actions
      Object.values(room.players).forEach(p => {
        if (p.isBot) {
          if (Math.random() < 0.6) {
            shakes[p.id] = (shakes[p.id] || 0) + (1 + Math.floor(Math.random() * 2));
          }
        }
      });
      return false;
    },
    calculateResults(room) {
      const shakes = room.activeMinigame?.data?.shakes || {};
      const scores = Object.keys(room.players).map(id => ({
        playerId: id,
        score: shakes[id] || 0,
        extraInfo: `${shakes[id] || 0} magasság`
      }));
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 3. BOMB PASS
  'bomb-pass': {
    id: 'bomb-pass',
    name: 'BOMB PASS',
    description: 'A bomba ketyeg! Add tovább a többieknek mielőtt nálad robban fel!',
    duration: 14,
    instructions: 'ADD ÁT MÁSNAK! Akinél felrobban, az veszít!',
    setup(room) {
      const pIds = Object.keys(room.players);
      const initialHolder = pIds[Math.floor(Math.random() * pIds.length)];
      const fuseTime = 7 + Math.random() * 6; // 7 to 13s
      room.activeMinigame!.data = {
        currentHolder: initialHolder,
        fuseTime,
        elapsed: 0,
        exploded: false,
        passHistory: [] as { from: string; to: string; time: number }[]
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.exploded) return;
      if (mgData.currentHolder === playerId && data?.targetPlayerId && room.players[data.targetPlayerId]) {
        mgData.passHistory.push({
          from: playerId,
          to: data.targetPlayerId,
          time: Math.round(mgData.elapsed * 10) / 10
        });
        mgData.currentHolder = data.targetPlayerId;
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.exploded) return false;
      mgData.elapsed += dt;
      // Bot logic: if bot holds bomb, pass after 0.5-1.5s
      const currentHolderObj = room.players[mgData.currentHolder];
      if (currentHolderObj && currentHolderObj.isBot) {
        if (Math.random() < 0.25) {
          const others = Object.keys(room.players).filter(id => id !== mgData.currentHolder);
          if (others.length > 0) {
            const target = others[Math.floor(Math.random() * others.length)];
            mgData.passHistory.push({
              from: currentHolderObj.id,
              to: target,
              time: Math.round(mgData.elapsed * 10) / 10
            });
            mgData.currentHolder = target;
          }
        }
      }
      if (mgData.elapsed >= mgData.fuseTime) {
        mgData.exploded = true;
        return true;
      }
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const loserId = mgData.currentHolder;
      const scores = Object.keys(room.players).map(id => {
        if (id === loserId) {
          return { playerId: id, score: 0, extraInfo: '💥 BUMM! Nála robbant fel!' };
        }
        return { playerId: id, score: 100, extraInfo: 'Túlélte a bombát!' };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 4. DON'T TOUCH
  'dont-touch': {
    id: 'dont-touch',
    name: "DON'T TOUCH",
    description: 'Ne érj a képernyőhöz az álhírek alatt! Csak a "NOW!" feliratnál szabad nyomni!',
    duration: 10,
    instructions: 'CSAK A "NOW!" UTÁN NYOMD MEG! A hamis feliratok elkapnak!',
    setup(room) {
      room.activeMinigame!.data = {
        nowTime: 5.5 + Math.random() * 2.5,
        fakeouts: [
          { time: 1.5, text: 'VÁRJ MÉG...' },
          { time: 3.2, text: 'MAJDNEM...' },
          { time: 4.6, text: 'NEM MOST...' }
        ],
        currentPrompt: "NE ÉRJ HOZZÁ!",
        elapsed: 0,
        nowTriggered: false,
        taps: {} as Record<string, { time: number; disqualified: boolean }>
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.taps[playerId]) return;
      if (!mgData.nowTriggered) {
        mgData.taps[playerId] = { time: 0, disqualified: true };
      } else {
        mgData.taps[playerId] = { time: mgData.elapsed - mgData.nowTime, disqualified: false };
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      mgData.elapsed += dt;
      // Fakeout updates
      for (const fo of mgData.fakeouts) {
        if (mgData.elapsed >= fo.time && mgData.elapsed < fo.time + 1.2) {
          mgData.currentPrompt = fo.text;
        }
      }
      if (mgData.elapsed >= mgData.nowTime && !mgData.nowTriggered) {
        mgData.nowTriggered = true;
        mgData.currentPrompt = 'MOST! (NOW!)';
      }
      // Bot actions
      if (mgData.nowTriggered) {
        Object.values(room.players).forEach(p => {
          if (p.isBot && !mgData.taps[p.id]) {
            if (Math.random() < 0.2) {
              mgData.taps[p.id] = { time: 0.3 + Math.random() * 0.4, disqualified: false };
            }
          }
        });
      }
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const taps = mgData.taps || {};
      const scores = Object.keys(room.players).map(id => {
        const t = taps[id];
        if (!t) return { playerId: id, score: 0, extraInfo: 'Lecsúszott a gombnyomásról' };
        if (t.disqualified) return { playerId: id, score: -50, extraInfo: 'KORAI ÉRINTÉS! (Disqualified)' };
        return { playerId: id, score: Math.max(1, 5000 - Math.round(t.time * 1000)), extraInfo: `${Math.round(t.time * 1000)} ms` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 5. PERFECT STOP
  'perfect-stop': {
    id: 'perfect-stop',
    name: 'PERFECT STOP',
    description: 'Állítsd meg a gyorsan csúszkáló mutatót a középső célvonalon!',
    duration: 10,
    instructions: 'ÁLLÍTSD MEG KÖZÉPEN! Minél közelebb a 0-hoz, annál több pont!',
    setup(room) {
      const stops: Record<string, number> = {};
      room.activeMinigame!.data = { stops };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const stops = room.activeMinigame?.data?.stops;
      if (!stops || stops[playerId] !== undefined) return;
      stops[playerId] = Number(data?.position) || 0; // -100 to 100
    },
    update(room, dt) {
      const stops = room.activeMinigame?.data?.stops;
      if (!stops) return false;
      // Bot logic
      Object.values(room.players).forEach(p => {
        if (p.isBot && stops[p.id] === undefined) {
          if (Math.random() < 0.15) {
            // bot lands near center with random deviation
            stops[p.id] = Math.round((Math.random() - 0.5) * 35);
          }
        }
      });
      return Object.keys(room.players).every(id => stops[id] !== undefined);
    },
    calculateResults(room) {
      const stops = room.activeMinigame?.data?.stops || {};
      const scores = Object.keys(room.players).map(id => {
        const pos = stops[id];
        if (pos === undefined) return { playerId: id, score: 0, extraInfo: 'Nem állította meg' };
        const diff = Math.abs(pos);
        const score = Math.max(0, 100 - Math.round(diff));
        return { playerId: id, score, extraInfo: `${score}% pontosság` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 6. TAP WAR
  'tap-war': {
    id: 'tap-war',
    name: 'TAP WAR',
    description: 'Nyomkodd, amíg bírod, de az utolsó 2 másodpercben ÁLLJ! A STOP alatti tap mínusz pont!',
    duration: 10,
    instructions: '10 MÁSODPERC! Az utolsó 2 másodpercben STOP van!',
    setup(room) {
      const taps: Record<string, number> = {};
      const penalties: Record<string, number> = {};
      Object.keys(room.players).forEach(id => {
        taps[id] = 0;
        penalties[id] = 0;
      });
      room.activeMinigame!.data = { taps, penalties, stopTriggered: false, elapsed: 0 };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return;
      if (mgData.stopTriggered) {
        mgData.penalties[playerId] = (mgData.penalties[playerId] || 0) + 2;
      } else {
        mgData.taps[playerId] = (mgData.taps[playerId] || 0) + 1;
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      mgData.elapsed += dt;
      if (mgData.elapsed >= 8 && !mgData.stopTriggered) {
        mgData.stopTriggered = true;
      }
      // Bot actions
      Object.values(room.players).forEach(p => {
        if (p.isBot) {
          if (!mgData.stopTriggered) {
            if (Math.random() < 0.6) mgData.taps[p.id] = (mgData.taps[p.id] || 0) + 1;
          } else {
            // bot small chance of accidental penalty tap
            if (Math.random() < 0.08) mgData.penalties[p.id] = (mgData.penalties[p.id] || 0) + 2;
          }
        }
      });
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const taps = mgData.taps || {};
      const penalties = mgData.penalties || {};
      const scores = Object.keys(room.players).map(id => {
        const net = Math.max(0, (taps[id] || 0) - (penalties[id] || 0));
        return {
          playerId: id,
          score: net,
          extraInfo: `${taps[id] || 0} tap - ${penalties[id] || 0} hiba = ${net} pont`
        };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 7. BALANCE
  'balance': {
    id: 'balance',
    name: 'BALANCE',
    description: 'Tartsd a golyót a kör közepén döntéssel vagy a virtuális joystickkal!',
    duration: 12,
    instructions: 'DÖNTSD A TELEFONT! Tartsd a golyót középen!',
    setup(room) {
      const centerTime: Record<string, number> = {};
      Object.keys(room.players).forEach(id => (centerTime[id] = 0));
      room.activeMinigame!.data = { centerTime };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const ct = room.activeMinigame?.data?.centerTime;
      if (!ct) return;
      if (data?.inCenter) {
        ct[playerId] = (ct[playerId] || 0) + 0.1;
      }
    },
    update(room, dt) {
      const ct = room.activeMinigame?.data?.centerTime;
      if (!ct) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot) {
          if (Math.random() < 0.8) {
            ct[p.id] = (ct[p.id] || 0) + dt * 0.9;
          }
        }
      });
      return false;
    },
    calculateResults(room) {
      const ct = room.activeMinigame?.data?.centerTime || {};
      const scores = Object.keys(room.players).map(id => {
        const time = Math.round((ct[id] || 0) * 10) / 10;
        return {
          playerId: id,
          score: Math.round(time * 10),
          extraInfo: `${time}s stabilitás`
        };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 8. CHOOSE YOUR ENEMY
  'choose-your-enemy': {
    id: 'choose-your-enemy',
    name: 'CHOOSE YOUR ENEMY',
    description: 'Válassz titokban valakit a telefonodon! Ha senki nem választ téged, +5 coin jár!',
    duration: 12,
    instructions: 'SZAVAZZ VALAKIRE! 0 szavazat = +5 coin, 2+ szavazat = célpont!',
    setup(room) {
      room.activeMinigame!.data = { votes: {} as Record<string, string>, revealed: false };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const votes = room.activeMinigame?.data?.votes;
      if (!votes || votes[playerId]) return;
      if (data?.targetPlayerId && data.targetPlayerId !== playerId) {
        votes[playerId] = data.targetPlayerId;
      }
    },
    update(room, dt) {
      const votes = room.activeMinigame?.data?.votes;
      if (!votes) return false;
      // Bot votes
      Object.values(room.players).forEach(p => {
        if (p.isBot && !votes[p.id]) {
          const others = Object.keys(room.players).filter(id => id !== p.id);
          votes[p.id] = others[Math.floor(Math.random() * others.length)];
        }
      });
      return Object.keys(room.players).every(id => votes[id]);
    },
    calculateResults(room) {
      const votes = (room.activeMinigame?.data?.votes || {}) as Record<string, string>;
      const voteCounts: Record<string, number> = {};
      Object.keys(room.players).forEach(id => (voteCounts[id] = 0));
      Object.values(votes).forEach((targetId: string) => {
        if (voteCounts[targetId] !== undefined) voteCounts[targetId]++;
      });

      const scores = Object.keys(room.players).map(id => {
        const count = voteCounts[id] || 0;
        let score = 50;
        let info = `${count} szavazat érkezett rá`;
        if (count === 0) {
          score = 100;
          info = '🎉 SENKI NEM VÁLASZTOTTA! (+5 érme bónusz)';
        } else if (count >= 2) {
          score = 20;
          info = `⚠️ ${count} ember szívatta meg! (Célkeresztben)`;
        }
        return { playerId: id, score, extraInfo: info };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 9. BUTTON CHICKEN
  'button-chicken': {
    id: 'button-chicken',
    name: 'BUTTON CHICKEN',
    description: 'Minden nyomás +1 érme! De bármikor robbanhat a gomb! Zárd le a pontjaidat időben!',
    duration: 12,
    instructions: 'NYOMD A COINÉRT! Zárd le a "BANK" gombbal a robbanás előtt!',
    setup(room) {
      const boomTime = 4 + Math.random() * 7; // 4 to 11s
      room.activeMinigame!.data = {
        boomTime,
        elapsed: 0,
        exploded: false,
        presses: {} as Record<string, number>,
        banked: {} as Record<string, boolean>
      };
      Object.keys(room.players).forEach(id => {
        room.activeMinigame!.data.presses[id] = 0;
        room.activeMinigame!.data.banked[id] = false;
      });
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.exploded || mgData.banked[playerId]) return;
      if (data?.action === 'press') {
        mgData.presses[playerId] = (mgData.presses[playerId] || 0) + 1;
      } else if (data?.action === 'bank') {
        mgData.banked[playerId] = true;
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.exploded) return false;
      mgData.elapsed += dt;
      // Bot actions
      Object.values(room.players).forEach(p => {
        if (p.isBot && !mgData.banked[p.id]) {
          if (mgData.elapsed < mgData.boomTime - 1.5) {
            if (Math.random() < 0.4) mgData.presses[p.id] = (mgData.presses[p.id] || 0) + 1;
          } else {
            mgData.banked[p.id] = true; // Bot banks
          }
        }
      });
      if (mgData.elapsed >= mgData.boomTime) {
        mgData.exploded = true;
        return true;
      }
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const presses = mgData.presses || {};
      const banked = mgData.banked || {};
      const scores = Object.keys(room.players).map(id => {
        if (!banked[id]) {
          return { playerId: id, score: 0, extraInfo: '💥 BUMM! Felrobbant, mielőtt bankolt volna!' };
        }
        const pts = presses[id] || 0;
        return { playerId: id, score: pts * 10, extraInfo: `${pts} érme sikeresen lebankolva!` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 10. HOLD YOUR NERVE
  'hold-your-nerve': {
    id: 'hold-your-nerve',
    name: 'HOLD YOUR NERVE',
    description: 'Tartsd lenyomva a kijelzőt! A szorzó emelkedik, de bármikor jöhet a CRASH!',
    duration: 12,
    instructions: 'TARTSD LENYOMVA! Engedd fel a CRASH előtt!',
    setup(room) {
      const crashTime = 3 + Math.random() * 8; // 3 to 11s
      room.activeMinigame!.data = {
        crashTime,
        elapsed: 0,
        crashed: false,
        releasedAt: {} as Record<string, number>
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.crashed || mgData.releasedAt[playerId] !== undefined) return;
      if (data?.action === 'release') {
        mgData.releasedAt[playerId] = mgData.elapsed;
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.crashed) return false;
      mgData.elapsed += dt;
      // Bot logic
      Object.values(room.players).forEach(p => {
        if (p.isBot && mgData.releasedAt[p.id] === undefined) {
          if (mgData.elapsed >= mgData.crashTime * (0.5 + Math.random() * 0.45)) {
            mgData.releasedAt[p.id] = mgData.elapsed;
          }
        }
      });
      if (mgData.elapsed >= mgData.crashTime) {
        mgData.crashed = true;
        return true;
      }
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const released = mgData.releasedAt || {};
      const scores = Object.keys(room.players).map(id => {
        const time = released[id];
        if (time === undefined) {
          return { playerId: id, score: 0, extraInfo: '💥 CRASH! 0 pont, túl sokáig tartotta!' };
        }
        const multiplier = (1 + time * 0.8).toFixed(1);
        const score = Math.round(time * 25);
        return { playerId: id, score, extraInfo: `${multiplier}x szorzónál engedte fel!` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 11. SAFE TILE
  'safe-tile': {
    id: 'safe-tile',
    name: 'SAFE TILE',
    description: 'Válassz egy színt (Piros, Kék, Zöld, Sárga)! A kieső szín játékosai búcsúznak!',
    duration: 10,
    instructions: 'VÁLASSZ SZÍNT! Egy szín azonnal leszakad a TV-n!',
    setup(room) {
      const colors = ['red', 'blue', 'green', 'yellow'];
      const dangerousColor = colors[Math.floor(Math.random() * colors.length)];
      room.activeMinigame!.data = {
        dangerousColor,
        choices: {} as Record<string, string>,
        colors
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const choices = room.activeMinigame?.data?.choices;
      if (!choices || choices[playerId]) return;
      if (data?.color) {
        choices[playerId] = data.color;
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot && !mgData.choices[p.id]) {
          mgData.choices[p.id] = mgData.colors[Math.floor(Math.random() * mgData.colors.length)];
        }
      });
      return Object.keys(room.players).every(id => mgData.choices[id]);
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const choices = mgData.choices || {};
      const dang = mgData.dangerousColor;
      const scores = Object.keys(room.players).map(id => {
        const c = choices[id];
        if (c === dang) {
          return { playerId: id, score: 0, extraInfo: `💥 A(z) ${dang.toUpperCase()} mező lezuhant!` };
        }
        return { playerId: id, score: 100, extraInfo: `Biztonságban maradt a(z) ${c ? c.toUpperCase() : 'semleges'} mezőn!` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 12. COPYCAT
  'copycat': {
    id: 'copycat',
    name: 'COPYCAT',
    description: 'Figyeld a TV-n felvillanó színsort, majd ismételd meg a telefonodon!',
    duration: 12,
    instructions: 'ISMÉTELT A MINTÁT PONTOSAN ÉS GYORSAN!',
    setup(room) {
      const colors = ['🔴', '🔵', '🟢', '🟡'];
      const sequence = [
        colors[Math.floor(Math.random() * 4)],
        colors[Math.floor(Math.random() * 4)],
        colors[Math.floor(Math.random() * 4)],
        colors[Math.floor(Math.random() * 4)]
      ];
      room.activeMinigame!.data = {
        sequence,
        submissions: {} as Record<string, { correct: boolean; time: number }>
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.submissions[playerId]) return;
      const userSeq = data?.sequence || [];
      const match = JSON.stringify(userSeq) === JSON.stringify(mgData.sequence);
      mgData.submissions[playerId] = { correct: match, time: data?.time || 5 };
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot && !mgData.submissions[p.id]) {
          mgData.submissions[p.id] = { correct: Math.random() < 0.75, time: 2 + Math.random() * 2 };
        }
      });
      return Object.keys(room.players).every(id => mgData.submissions[id]);
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const subs = mgData.submissions || {};
      const scores = Object.keys(room.players).map(id => {
        const s = subs[id];
        if (!s || !s.correct) {
          return { playerId: id, score: 0, extraInfo: 'Hibás minta!' };
        }
        const score = Math.max(10, Math.round(100 - s.time * 8));
        return { playerId: id, score, extraInfo: `Tökéletes! (${s.time.toFixed(1)}s)` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 13. PHONE HOT POTATO
  'phone-hot-potato': {
    id: 'phone-hot-potato',
    name: 'PHONE HOT POTATO',
    description: 'A TV kiírja, ki a célpont! Annak a játékosnak gyorsan tovább kell adnia!',
    duration: 12,
    instructions: 'KÖVESD A TV UTASÍTÁSAIT ÉS NYOMD MEG A CÉLPONTOT!',
    setup(room) {
      const pIds = Object.keys(room.players);
      room.activeMinigame!.data = {
        targetPlayerId: pIds[Math.floor(Math.random() * pIds.length)],
        passes: 0,
        eliminated: {} as Record<string, boolean>,
        elapsed: 0,
        stepTime: 2.5
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return;
      if (playerId === mgData.targetPlayerId && data?.nextPlayerId) {
        mgData.passes++;
        mgData.targetPlayerId = data.nextPlayerId;
        mgData.elapsed = 0;
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      mgData.elapsed += dt;
      // Bot automatic reaction
      const currentTarget = room.players[mgData.targetPlayerId];
      if (currentTarget && currentTarget.isBot) {
        if (mgData.elapsed > 0.8) {
          const others = Object.keys(room.players).filter(id => id !== currentTarget.id);
          mgData.targetPlayerId = others[Math.floor(Math.random() * others.length)];
          mgData.passes++;
          mgData.elapsed = 0;
        }
      }
      if (mgData.elapsed > mgData.stepTime) {
        mgData.eliminated[mgData.targetPlayerId] = true;
      }
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const elim = mgData.eliminated || {};
      const scores = Object.keys(room.players).map(id => {
        if (elim[id]) return { playerId: id, score: 0, extraInfo: 'Lecsúszott a továbbadásról!' };
        return { playerId: id, score: 100, extraInfo: 'Sikeresen átadta a forró krumplit!' };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 14. FAKE BUTTONS
  'fake-buttons': {
    id: 'fake-buttons',
    name: 'FAKE BUTTONS',
    description: 'Találd meg a 9 gomb közül a TV által kért egyetlen helyes szimbólumot!',
    duration: 10,
    instructions: 'KERESD MEG A KÉRT IKONT ÉS NYOMD MEG ELSŐKÉNT!',
    setup(room) {
      const symbols = ['⭐', '🔺', '🔵', '⚡', '💎', '🚀', '🍀', '🔥', '👑'];
      const target = symbols[Math.floor(Math.random() * symbols.length)];
      room.activeMinigame!.data = {
        symbols,
        target,
        clicks: {} as Record<string, { correct: boolean; time: number }>
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.clicks[playerId]) return;
      const isCorrect = data?.symbol === mgData.target;
      mgData.clicks[playerId] = { correct: isCorrect, time: data?.time || 3 };
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot && !mgData.clicks[p.id]) {
          mgData.clicks[p.id] = { correct: Math.random() < 0.8, time: 1.5 + Math.random() * 2 };
        }
      });
      return Object.keys(room.players).every(id => mgData.clicks[id]);
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const clicks = mgData.clicks || {};
      const scores = Object.keys(room.players).map(id => {
        const c = clicks[id];
        if (!c || !c.correct) return { playerId: id, score: 0, extraInfo: 'Rossz ikont nyomott meg!' };
        const score = Math.max(10, Math.round(100 - c.time * 15));
        return { playerId: id, score, extraInfo: `Helyes ikon! (${c.time.toFixed(1)}s)` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 15. LAST SECOND
  'last-second': {
    id: 'last-second',
    name: 'LAST SECOND',
    description: 'A stopper elindul a TV-n, majd eltűnik! Nyomd meg pontosan 10.00 másodpercnél!',
    duration: 14,
    instructions: 'SZÁMOLJ FEJBEN! Nyomd meg minél közelebb a 10.00-hoz!',
    setup(room) {
      room.activeMinigame!.data = {
        elapsed: 0,
        stops: {} as Record<string, number>
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData || mgData.stops[playerId] !== undefined) return;
      mgData.stops[playerId] = mgData.elapsed;
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      mgData.elapsed += dt;
      // Bot logic
      Object.values(room.players).forEach(p => {
        if (p.isBot && mgData.stops[p.id] === undefined) {
          if (mgData.elapsed >= 9.2 + Math.random() * 1.6) {
            mgData.stops[p.id] = mgData.elapsed;
          }
        }
      });
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const stops = mgData.stops || {};
      const scores = Object.keys(room.players).map(id => {
        const time = stops[id];
        if (time === undefined) return { playerId: id, score: 0, extraInfo: 'Nem állította meg!' };
        const diff = Math.abs(10.0 - time);
        const score = Math.max(0, Math.round(100 - diff * 20));
        return { playerId: id, score, extraInfo: `${time.toFixed(2)}s (${diff.toFixed(2)}s eltérés)` };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 16. TUG OF WAR (2 vs 2 vs 1)
  'tug-of-war': {
    id: 'tug-of-war',
    name: 'TUG OF WAR (2 vs 2 vs 1)',
    description: 'Kötélhúzás! A solo játékos 1.7x szorzóval küzd a csapatok ellen!',
    duration: 10,
    instructions: 'TAPELJ AMILYEN GYORSAN CSAK TUDSZ A CSAPATODÉRT!',
    setup(room) {
      const pIds = Object.keys(room.players);
      const teams: Record<string, 'A' | 'B' | 'SOLO'> = {};
      // Assign teams
      if (pIds.length >= 5) {
        teams[pIds[0]] = 'A';
        teams[pIds[1]] = 'A';
        teams[pIds[2]] = 'B';
        teams[pIds[3]] = 'B';
        teams[pIds[4]] = 'SOLO';
      } else {
        pIds.forEach((id, i) => (teams[id] = i === 0 ? 'SOLO' : i % 2 === 0 ? 'A' : 'B'));
      }
      room.activeMinigame!.data = {
        teams,
        teamScores: { A: 0, B: 0, SOLO: 0 } as Record<string, number>,
        playerTaps: {} as Record<string, number>
      };
      pIds.forEach(id => (room.activeMinigame!.data.playerTaps[id] = 0));
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return;
      const team = mgData.teams[playerId];
      const mult = team === 'SOLO' ? 1.7 : 1.0;
      mgData.teamScores[team] = (mgData.teamScores[team] || 0) + mult;
      mgData.playerTaps[playerId] = (mgData.playerTaps[playerId] || 0) + 1;
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot) {
          if (Math.random() < 0.6) {
            const team = mgData.teams[p.id];
            const mult = team === 'SOLO' ? 1.7 : 1.0;
            mgData.teamScores[team] = (mgData.teamScores[team] || 0) + mult;
            mgData.playerTaps[p.id] = (mgData.playerTaps[p.id] || 0) + 1;
          }
        }
      });
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const teamScores = mgData.teamScores || {};
      const teams = mgData.teams || {};
      const scores = Object.keys(room.players).map(id => {
        const myTeam = teams[id] || 'SOLO';
        const teamScore = Math.round(teamScores[myTeam] || 0);
        return {
          playerId: id,
          score: teamScore,
          extraInfo: `${myTeam} csapat: ${teamScore} pont`
        };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 17. BOSS BATTLE (Everyone vs Leader)
  'boss-battle': {
    id: 'boss-battle',
    name: 'BOSS BATTLE',
    description: 'Az élen álló a BOSS! A többiek összefognak ellene!',
    duration: 12,
    instructions: 'A BOSS VÉDEKEZIK, A CSAPAT TÁMAD! TAPELJETEK!',
    setup(room) {
      // Find leader
      const sorted = Object.values(room.players).sort((a, b) => b.crowns - a.crowns || b.coins - a.coins);
      const bossId = sorted[0]?.id || Object.keys(room.players)[0];
      room.activeMinigame!.data = {
        bossId,
        bossHp: 100,
        maxHp: 100,
        bossShieldActive: false,
        teamHits: 0
      };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return;
      if (playerId === mgData.bossId) {
        // Boss tapping to shield
        if (data?.action === 'shield') {
          mgData.bossHp = Math.min(mgData.maxHp, mgData.bossHp + 0.8);
        }
      } else {
        // Team attacker
        if (data?.action === 'attack') {
          mgData.bossHp = Math.max(0, mgData.bossHp - 1.2);
          mgData.teamHits++;
        }
      }
    },
    update(room, dt) {
      const mgData = room.activeMinigame?.data;
      if (!mgData) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot) {
          if (p.id === mgData.bossId) {
            if (Math.random() < 0.6) mgData.bossHp = Math.min(mgData.maxHp, mgData.bossHp + 0.8);
          } else {
            if (Math.random() < 0.4) {
              mgData.bossHp = Math.max(0, mgData.bossHp - 1.2);
              mgData.teamHits++;
            }
          }
        }
      });
      if (mgData.bossHp <= 0) return true; // Boss defeated early!
      return false;
    },
    calculateResults(room) {
      const mgData = room.activeMinigame?.data || {};
      const bossWon = (mgData.bossHp || 0) > 0;
      const scores = Object.keys(room.players).map(id => {
        if (id === mgData.bossId) {
          return {
            playerId: id,
            score: bossWon ? 100 : 20,
            extraInfo: bossWon ? '👑 A BOSS TÚLÉLTE! (+10 érme)' : 'A Bosst legyőzték!'
          };
        } else {
          return {
            playerId: id,
            score: !bossWon ? 80 : 30,
            extraInfo: !bossWon ? '⚔️ A CSAPAT GYŐZÖTT! (+4 érme mindenkinek)' : 'A Boss túl erős volt!'
          };
        }
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 18. TARGET LOCK
  'target-lock': {
    id: 'target-lock',
    name: 'TARGET LOCK',
    description: 'Húzd a célkeresztet az ellenfelek avatarjaira a TV-n és nyomj a ZAP gombra!',
    duration: 12,
    instructions: 'CÉLOZZ ÉS LŐJ! Saját magadat nem lőheted!',
    setup(room) {
      const zaps: Record<string, number> = {};
      Object.keys(room.players).forEach(id => (zaps[id] = 0));
      room.activeMinigame!.data = { zaps };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const zaps = room.activeMinigame?.data?.zaps;
      if (!zaps) return;
      if (data?.hitTargetId && data.hitTargetId !== playerId) {
        zaps[playerId] = (zaps[playerId] || 0) + 1;
      }
    },
    update(room, dt) {
      const zaps = room.activeMinigame?.data?.zaps;
      if (!zaps) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot) {
          if (Math.random() < 0.3) {
            zaps[p.id] = (zaps[p.id] || 0) + 1;
          }
        }
      });
      return false;
    },
    calculateResults(room) {
      const zaps = room.activeMinigame?.data?.zaps || {};
      const scores = Object.keys(room.players).map(id => ({
        playerId: id,
        score: (zaps[id] || 0) * 15,
        extraInfo: `${zaps[id] || 0} sikeres találat`
      }));
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  },

  // 19. SECRET NUMBER
  'secret-number': {
    id: 'secret-number',
    name: 'SECRET NUMBER',
    description: 'Válassz titokban egy számot 1 és 10 között! Ha egyedül választod, +5 pont!',
    duration: 10,
    instructions: 'VÁLASSZ SZÁMOT 1 ÉS 10 KÖZÖTT! Légy egyedi!',
    setup(room) {
      room.activeMinigame!.data = { choices: {} as Record<string, number> };
    },
    start(room) {},
    handleInput(room, playerId, data) {
      const choices = room.activeMinigame?.data?.choices;
      if (!choices || choices[playerId] !== undefined) return;
      const num = Number(data?.number);
      if (num >= 1 && num <= 10) {
        choices[playerId] = num;
      }
    },
    update(room, dt) {
      const choices = room.activeMinigame?.data?.choices;
      if (!choices) return false;
      Object.values(room.players).forEach(p => {
        if (p.isBot && choices[p.id] === undefined) {
          choices[p.id] = 1 + Math.floor(Math.random() * 10);
        }
      });
      return Object.keys(room.players).every(id => choices[id] !== undefined);
    },
    calculateResults(room) {
      const choices = (room.activeMinigame?.data?.choices || {}) as Record<string, number>;
      const numCounts: Record<number, number> = {};
      let total = 0;
      let count = 0;
      Object.values(choices).forEach((n: number) => {
        numCounts[n] = (numCounts[n] || 0) + 1;
        total += n;
        count++;
      });
      const avg = count > 0 ? total / count : 5.5;

      const scores = Object.keys(room.players).map(id => {
        const num = choices[id];
        if (num === undefined) return { playerId: id, score: 0, extraInfo: 'Nem választott számot' };
        const occurrences = numCounts[num] || 0;
        let score = 0;
        let info = `${num} (Többen is választották)`;
        if (occurrences === 1) {
          score = 60;
          info = `🎉 ${num} (EGYEDI VÁLASZTÁS! +5 érme)`;
        }
        // Closeness to average bonus
        if (Math.abs(num - avg) < 1.2) {
          score += 20;
          info += ' + Átlaghoz közeli bónusz!';
        }
        return { playerId: id, score, extraInfo: info };
      });
      return assignResultsFromScores(room, scores);
    },
    cleanup(room) {}
  }
};
