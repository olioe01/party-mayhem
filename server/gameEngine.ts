import { RoomState, Player, MinigameResultEntry, BonusCrownAward, ChaosEvent } from '../shared/types';
import { BOARD_TILES, getNextTileId } from '../shared/boardData';
import { CHAOS_EVENTS, CROWN_COST_COINS, PARTY_MODE_ROUNDS, PARTY_CHALLENGES, SECRET_MISSION_TEMPLATES, AVATARS } from '../shared/constants';
import { MINIGAMES } from './minigames/registry';

export class GameEngine {
  private minigameInterval: NodeJS.Timeout | null = null;
  private activeTimeouts: NodeJS.Timeout[] = [];
  private onStateChange: (room: RoomState) => void;

  constructor(onStateChange: (room: RoomState) => void) {
    this.onStateChange = onStateChange;
  }

  private safeTimeout(fn: () => void, ms: number): NodeJS.Timeout {
    const t = setTimeout(() => {
      this.activeTimeouts = this.activeTimeouts.filter(item => item !== t);
      fn();
    }, ms);
    this.activeTimeouts.push(t);
    return t;
  }

  public clearAllTimers() {
    if (this.minigameInterval) {
      clearInterval(this.minigameInterval);
      this.minigameInterval = null;
    }
    this.activeTimeouts.forEach(t => clearTimeout(t));
    this.activeTimeouts = [];
  }

  // Create a brand new room
  public createRoom(roomCode: string = '4827', lanIp?: string, port?: number): RoomState {
    return {
      roomCode,
      partyMode: 'normal',
      totalRounds: PARTY_MODE_ROUNDS.normal,
      currentRound: 1,
      phase: 'LOBBY',
      isPaused: false,
      partyChallengeEnabled: false,
      players: {},
      playerOrder: [],
      currentPlayerIndex: 0,
      crownShopTileId: 18,
      lastDiceRoll: null,
      currentTileEffect: null,
      activeMinigame: null,
      activeChaosEvent: null,
      activeForkChoice: null,
      movementPath: null,
      lastReconnectedPlayer: null,
      serverLanIp: lanIp,
      serverPort: port,
      serverLanUrl: lanIp && port ? `http://${lanIp}:${port}` : undefined,
      bonusCrowns: [],
      activePartyChallenge: null,
      isDevMode: false
    };
  }

  // Add bot player for dev testing
  public addBot(room: RoomState): Player | null {
    const existingAvatars = Object.values(room.players).map(p => p.avatar);
    const availableAvatars = Object.keys(AVATARS).filter(a => !existingAvatars.includes(a as any));
    if (availableAvatars.length === 0) return null;

    const avatarId = availableAvatars[0] as any;
    const botId = `bot_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const avatarInfo = AVATARS[avatarId];

    const botPlayer: Player = {
      id: botId,
      socketId: undefined,
      playerToken: `bot_token_${botId}`,
      name: `${avatarInfo.name} Bot`,
      avatar: avatarId,
      color: avatarInfo.color,
      cosmetic: 'none',
      isReady: true,
      isBot: true,
      connected: true,
      disconnectedAt: null,
      coins: 10,
      crowns: 0,
      boardPosition: 0,
      totalCoinsEarned: 10,
      minigamesWon: 0,
      positiveEvents: 0,
      riskyDecisions: 0,
      currentRank: Object.keys(room.players).length + 1,
      boostActive: false,
      trapActive: false,
      luckyDayActive: false,
      slowModeActive: false,
      shieldActive: false,
      secretMission: null
    };

    room.players[botId] = botPlayer;
    room.playerOrder.push(botId);
    this.updateRankings(room);
    this.onStateChange(room);
    return botPlayer;
  }

  public removeBot(room: RoomState, botId: string) {
    if (room.players[botId]?.isBot) {
      delete room.players[botId];
      room.playerOrder = room.playerOrder.filter(id => id !== botId);
      this.updateRankings(room);
      this.onStateChange(room);
    }
  }

  // Update dynamic ranks based on crowns, then coins
  public updateRankings(room: RoomState) {
    const sorted = Object.values(room.players).sort((a, b) => {
      if (b.crowns !== a.crowns) return b.crowns - a.crowns;
      return b.coins - a.coins;
    });

    sorted.forEach((p, index) => {
      p.currentRank = index + 1;
      if (p.initialRank === undefined) p.initialRank = p.currentRank;
    });
  }

  // Start the game
  public startGame(room: RoomState) {
    if (Object.keys(room.players).length === 0) return;
    room.phase = 'BOARD_ROLL';
    room.currentRound = 1;
    room.currentPlayerIndex = 0;
    this.updateRankings(room);

    // Initial secret missions for everyone
    this.assignSecretMissions(room);

    this.onStateChange(room);
    this.checkBotTurn(room);
  }

  // Assign random secret mission to players
  public assignSecretMissions(room: RoomState) {
    Object.values(room.players).forEach(p => {
      if (!p.secretMission) {
        const template = SECRET_MISSION_TEMPLATES[Math.floor(Math.random() * SECRET_MISSION_TEMPLATES.length)];
        const others = Object.keys(room.players).filter(id => id !== p.id);
        const targetPlayerId = others.length > 0 ? others[Math.floor(Math.random() * others.length)] : undefined;
        p.secretMission = {
          id: `mission_${Date.now()}_${Math.random()}`,
          title: template.title,
          description: template.description,
          targetPlayerId,
          rewardCoins: template.rewardCoins,
          conditionType: template.conditionType,
          completed: false
        };
      }
    });
  }

  // Roll dice for active player
  public rollDice(room: RoomState, playerId: string): number {
    const currentPlayerId = room.playerOrder[room.currentPlayerIndex];
    if (currentPlayerId !== playerId || room.phase !== 'BOARD_ROLL') return 0;

    const player = room.players[playerId];
    if (!player) return 0;

    let roll = 1 + Math.floor(Math.random() * 6);
    if (player.luckyDayActive) {
      roll = Math.max(4, roll);
      player.luckyDayActive = false;
    }
    if (player.slowModeActive) {
      roll = Math.min(3, roll);
      player.slowModeActive = false;
    }

    room.lastDiceRoll = roll;
    // Enter BOARD_ROLLING phase: 3D dice spins & tumbles in host scene!
    room.phase = 'BOARD_ROLLING';
    room.movementPath = null;
    this.onStateChange(room);

    // Calculate step-by-step path ahead
    let currentTile = player.boardPosition;
    const path: number[] = [currentTile];
    let passedShop = false;
    let forkTile: number | null = null;
    let branches: number[] | null = null;
    let remainingSteps = 0;

    for (let step = 0; step < roll; step++) {
      const tileObj = BOARD_TILES.find(t => t.id === currentTile);
      if (tileObj && tileObj.branchesTo && tileObj.branchesTo.length > 1 && step < roll - 1) {
        forkTile = currentTile;
        branches = tileObj.branchesTo;
        remainingSteps = roll - step; // remaining steps from the fork
        break;
      }
      currentTile = getNextTileId(currentTile);
      path.push(currentTile);
      if (currentTile === room.crownShopTileId) {
        passedShop = true;
      }
    }

    // 3D dice animation duration: ~1.8 seconds (spin + bounce + settle + short pause)
    this.safeTimeout(() => {
      if (room.phase !== 'BOARD_ROLLING') return;

      // Now start dynamic character hopping movement
      room.phase = 'BOARD_MOVE';
      room.movementPath = {
        playerId: player.id,
        path,
        targetTileId: path[path.length - 1],
        remainingSteps
      };
      this.onStateChange(room);

      // Adaptive movement speed: 1-3 tiles = 380ms/tile, 4-6 tiles = 320ms/tile
      const stepDuration = roll > 3 ? 320 : 380;
      const moveSteps = path.length - 1;
      // Generous landing pause (750ms) ensures character completes arrival animation before tile modal triggers
      const totalMoveTime = Math.max(1, moveSteps) * stepDuration + 750;

      this.safeTimeout(() => {
        if (room.phase !== 'BOARD_MOVE') return;
        room.movementPath = null;
        const finalTile = path[path.length - 1];
        player.boardPosition = finalTile;

        // If stopped at a fork
        if (forkTile !== null && branches !== null) {
          if (player.isBot) {
            const chosen = branches[Math.floor(Math.random() * branches.length)];
            this.handleForkChoice(room, player.id, chosen, remainingSteps);
          } else {
            room.activeForkChoice = {
              playerId: player.id,
              currentTileId: forkTile,
              branches
            };
            this.onStateChange(room);
            // Auto fallback after 12s
            this.safeTimeout(() => {
              if (room.activeForkChoice && room.activeForkChoice.playerId === player.id) {
                this.handleForkChoice(room, player.id, branches![0], remainingSteps);
              }
            }, 12000);
          }
          return;
        }

        // Check if player passed Crown Shop and can afford it
        if (passedShop && player.coins >= CROWN_COST_COINS) {
          room.phase = 'SHOP_DECISION';
          this.onStateChange(room);
          if (player.isBot) {
            this.safeTimeout(() => {
              if (room.phase !== 'SHOP_DECISION') return;
              this.handleShopDecision(room, player.id, true);
            }, 1200);
          }
        } else {
          this.executeTileEffect(room, player);
        }
      }, totalMoveTime);
    }, 1800);

    return roll;
  }

  // Handle Fork choice decision (Left / Right)
  public handleForkChoice(room: RoomState, playerId: string, chosenBranch: number, remainingSteps: number = 0) {
    if (!room.activeForkChoice || room.activeForkChoice.playerId !== playerId) return;
    const player = room.players[playerId];
    if (!player) return;

    room.activeForkChoice = null;

    if (remainingSteps > 1) {
      let curr = chosenBranch;
      const subPath: number[] = [player.boardPosition, chosenBranch];
      for (let s = 1; s < remainingSteps; s++) {
        curr = getNextTileId(curr);
        subPath.push(curr);
      }
      room.phase = 'BOARD_MOVE';
      room.movementPath = {
        playerId: player.id,
        path: subPath,
        targetTileId: subPath[subPath.length - 1]
      };
      this.onStateChange(room);

      const stepDuration = 340;
      const moveTime = (subPath.length - 1) * stepDuration + 750;
      this.safeTimeout(() => {
        room.movementPath = null;
        player.boardPosition = subPath[subPath.length - 1];
        this.executeTileEffect(room, player);
      }, moveTime);
    } else {
      player.boardPosition = chosenBranch;
      this.executeTileEffect(room, player);
    }
  }

  // Handle Shop purchase decision
  public handleShopDecision(room: RoomState, playerId: string, buy: boolean) {
    const player = room.players[playerId];
    if (player && buy && player.coins >= CROWN_COST_COINS) {
      player.coins -= CROWN_COST_COINS;
      player.crowns += 1;
      this.updateRankings(room);
      // Chance for Crown Shop to move after purchase
      if (Math.random() < 0.6) {
        this.relocateCrownShop(room);
      }
    }
    if (player) {
      this.executeTileEffect(room, player);
    }
  }

  // Relocate Crown Shop dynamically
  public relocateCrownShop(room: RoomState) {
    const candidateTiles = [4, 11, 14, 18, 22, 26, 30, 35];
    const newTile = candidateTiles[Math.floor(Math.random() * candidateTiles.length)];
    room.crownShopTileId = newTile;
  }

  // Execute landed tile action
  public executeTileEffect(room: RoomState, player: Player) {
    const tile = BOARD_TILES.find(t => t.id === player.boardPosition) || BOARD_TILES[0];
    room.phase = 'BOARD_ACTION';
    let message = '';
    const otherPlayers = Object.values(room.players).filter(p => p.id !== player.id);

    switch (tile.type) {
      case 'BLUE':
        player.coins += 3;
        player.totalCoinsEarned += 3;
        message = `${player.name} kapott +3 Érmét!`;
        break;
      case 'GOLD':
        player.coins += 8;
        player.totalCoinsEarned += 8;
        message = `${player.name} arany mezőre lépett! +8 Érme!`;
        break;
      case 'RED':
        if (player.shieldActive) {
          player.shieldActive = false;
          message = `${player.name} pajzsa kivédte a piros mező vesztességét!`;
        } else {
          player.coins = Math.max(0, player.coins - 5);
          message = `${player.name} 5 érmét veszített a piros mezőn!`;
        }
        break;
      case 'BOOST':
        player.boostActive = true;
        message = `${player.name} aktiválta a minijáték +50% bónuszt!`;
        break;
      case 'TRAP':
        if (player.shieldActive) {
          player.shieldActive = false;
          message = `${player.name} pajzsa megsemmisítette a csapdát!`;
        } else {
          player.trapActive = true;
          message = `${player.name} csapdába lépett! Hátrány a minijátékban!`;
        }
        break;
      case 'JACKPOT':
        player.coins += 20;
        player.totalCoinsEarned += 20;
        message = `🎰 JACKPOT! ${player.name} zsebre vágott 20 érmét!`;
        break;
      case 'TELEPORT':
        const randomTile = Math.floor(Math.random() * BOARD_TILES.length);
        player.boardPosition = randomTile;
        message = `🌀 Térugrás! ${player.name} a(z) ${randomTile}. mezőre teleportált!`;
        break;
      case 'SWAP':
        if (otherPlayers.length > 0) {
          const target = otherPlayers[Math.floor(Math.random() * otherPlayers.length)];
          const tempPos = player.boardPosition;
          player.boardPosition = target.boardPosition;
          target.boardPosition = tempPos;
          message = `🔄 HELYCSERE! ${player.name} és ${target.name} helyet cseréltek a pályán!`;
        } else {
          message = 'Helycsere mező, de nincs kivel cserélni!';
        }
        break;
      case 'STEAL':
        if (otherPlayers.length > 0) {
          const victim = otherPlayers[Math.floor(Math.random() * otherPlayers.length)];
          const stolen = Math.min(victim.coins, 3 + Math.floor(Math.random() * 6));
          victim.coins -= stolen;
          player.coins += stolen;
          player.totalCoinsEarned += stolen;
          message = `🗡️ LOPÁS! ${player.name} ellopott ${stolen} érmét ${victim.name} zsebéből!`;
        } else {
          message = 'Lopás mező, nincs kit meglopni!';
        }
        break;
      case 'DUEL':
        if (otherPlayers.length > 0) {
          const opponent = otherPlayers[Math.floor(Math.random() * otherPlayers.length)];
          const duelRoll1 = 1 + Math.floor(Math.random() * 6);
          const duelRoll2 = 1 + Math.floor(Math.random() * 6);
          if (duelRoll1 >= duelRoll2) {
            player.coins += 5;
            opponent.coins = Math.max(0, opponent.coins - 5);
            message = `⚔️ PÁRBAJ! ${player.name} (${duelRoll1}) legyőzte ${opponent.name} (${duelRoll2}) játékost és elnyert 5 érmét!`;
          } else {
            opponent.coins += 5;
            player.coins = Math.max(0, player.coins - 5);
            message = `⚔️ PÁRBAJ! ${opponent.name} (${duelRoll2}) megnyerte a párbajt ${player.name} (${duelRoll1}) ellen!`;
          }
        } else {
          message = 'Párbaj mező!';
        }
        break;
      case 'CHAOS':
        this.triggerRandomChaosEvent(room);
        message = '🌀 KÁOSZ MEZŐ! Egy világméretű véletlen esemény történt!';
        break;
      case 'SECRET':
        player.coins += 4;
        player.totalCoinsEarned += 4;
        message = `🤫 Titkos mező! ${player.name} extra jutalmat talált!`;
        break;
    }

    room.currentTileEffect = {
      tileId: tile.id,
      type: tile.type,
      message
    };
    this.updateRankings(room);
    this.onStateChange(room);

    // Auto-advance after 3.5 seconds
    this.safeTimeout(() => {
      if (room.phase !== 'BOARD_ACTION') return;
      this.advanceTurn(room);
    }, 3500);
  }

  // Advance to next player or trigger minigame
  public advanceTurn(room: RoomState) {
    room.currentTileEffect = null;
    room.currentPlayerIndex++;

    if (room.currentPlayerIndex >= room.playerOrder.length) {
      // All players completed board turn for this round!
      // Check Comeback mechanic: last place gets +2 pity coins
      this.applyComebackMechanic(room);

      // Check if Crown Shop moves
      if (room.currentRound % 3 === 0) {
        this.relocateCrownShop(room);
      }

      // Check party challenge if enabled
      if (room.partyChallengeEnabled) {
        room.activePartyChallenge = PARTY_CHALLENGES[Math.floor(Math.random() * PARTY_CHALLENGES.length)];
      }

      // Start Minigame Phase!
      this.startMinigameIntro(room);
    } else {
      room.phase = 'BOARD_ROLL';
      this.onStateChange(room);
      this.checkBotTurn(room);
    }
  }

  // Comeback mechanic
  private applyComebackMechanic(room: RoomState) {
    const sorted = Object.values(room.players).sort((a, b) => a.currentRank - b.currentRank);
    const lastPlayer = sorted[sorted.length - 1];
    if (lastPlayer && lastPlayer.currentRank > 1) {
      lastPlayer.coins += 3;
      lastPlayer.totalCoinsEarned += 3;
      lastPlayer.luckyDayActive = true; // next roll is minimum 4!
    }
  }

  // Check if current turn is a bot and auto-roll
  private checkBotTurn(room: RoomState) {
    if (room.phase !== 'BOARD_ROLL') return;
    const currentId = room.playerOrder[room.currentPlayerIndex];
    const player = room.players[currentId];
    if (player && player.isBot) {
      this.safeTimeout(() => {
        if (room.phase !== 'BOARD_ROLL') return;
        this.rollDice(room, player.id);
      }, 1500);
    }
  }

  // Trigger one of the 27 random chaos events
  public triggerRandomChaosEvent(room: RoomState, specificEventId?: string) {
    const event = specificEventId 
      ? CHAOS_EVENTS.find(e => e.id === specificEventId) || CHAOS_EVENTS[0]
      : CHAOS_EVENTS[Math.floor(Math.random() * CHAOS_EVENTS.length)];

    let details = event.description;
    const playersList = Object.values(room.players);
    const sorted = [...playersList].sort((a, b) => a.currentRank - b.currentRank);
    const leader = sorted[0];
    const last = sorted[sorted.length - 1];

    switch (event.id) {
      case 'coin_storm':
        playersList.forEach(p => { p.coins += 5; p.totalCoinsEarned += 5; });
        break;
      case 'tax_time':
        if (leader) leader.coins = Math.max(0, leader.coins - 10);
        break;
      case 'robin_hood':
        if (leader && last && leader.id !== last.id) {
          const amount = Math.min(leader.coins, 6);
          leader.coins -= amount;
          last.coins += amount;
          last.totalCoinsEarned += amount;
        }
        break;
      case 'swap':
        if (playersList.length >= 2) {
          const p1 = playersList[Math.floor(Math.random() * playersList.length)];
          const others = playersList.filter(p => p.id !== p1.id);
          const p2 = others[Math.floor(Math.random() * others.length)];
          const temp = p1.boardPosition;
          p1.boardPosition = p2.boardPosition;
          p2.boardPosition = temp;
          details = `${p1.name} és ${p2.name} helyet cseréltek a pályán!`;
        }
        break;
      case 'bank_error':
        const lucky = playersList[Math.floor(Math.random() * playersList.length)];
        if (lucky) { lucky.coins += 15; lucky.totalCoinsEarned += 15; lucky.positiveEvents++; details = `${lucky.name} kapott +15 érmét!`; }
        break;
      case 'bad_luck':
        const unlucky = playersList[Math.floor(Math.random() * playersList.length)];
        if (unlucky) { unlucky.coins = Math.max(0, unlucky.coins - 8); details = `${unlucky.name} veszített 8 érmét!`; }
        break;
      case 'teleport':
        const tpPlayer = playersList[Math.floor(Math.random() * playersList.length)];
        if (tpPlayer) { tpPlayer.boardPosition = Math.floor(Math.random() * BOARD_TILES.length); }
        break;
      case 'crown_panic':
        this.relocateCrownShop(room);
        details = `A Crown Shop átköltözött a(z) ${room.crownShopTileId}. mezőre!`;
        break;
      case 'lucky_day':
        const ldPlayer = playersList[Math.floor(Math.random() * playersList.length)];
        if (ldPlayer) ldPlayer.luckyDayActive = true;
        break;
      case 'slow_mode':
        const smPlayer = playersList[Math.floor(Math.random() * playersList.length)];
        if (smPlayer) smPlayer.slowModeActive = true;
        break;
      case 'speed_run':
        playersList.forEach(p => p.boardPosition = getNextTileId(getNextTileId(p.boardPosition)));
        break;
      case 'crown_gift':
        if (last) { last.coins += 12; last.totalCoinsEarned += 12; last.positiveEvents++; }
        break;
      case 'shield_blessing':
        const shielded = playersList[Math.floor(Math.random() * playersList.length)];
        if (shielded) shielded.shieldActive = true;
        break;
    }

    room.activeChaosEvent = { event, details };
    this.updateRankings(room);
    this.onStateChange(room);

    this.safeTimeout(() => {
      room.activeChaosEvent = null;
      this.onStateChange(room);
    }, 4500);
  }

  // Start Minigame Intro & Instructions (Waiting for all players to press READY)
  public startMinigameIntro(room: RoomState, specificMinigameId?: string) {
    // In random party mode, only select games marked READY
    const readyMinigameKeys = Object.keys(MINIGAMES).filter(k => MINIGAMES[k]?.status === 'READY');
    const availableKeys = readyMinigameKeys.length > 0 ? readyMinigameKeys : ['fruit-frenzy'];
    const chosenId = specificMinigameId || availableKeys[Math.floor(Math.random() * availableKeys.length)];
    const mgDef = MINIGAMES[chosenId] || MINIGAMES['fruit-frenzy'];

    // Reset minigame ready state & input state for every player in the room
    Object.values(room.players).forEach(p => {
      p.minigameReady = false;
      p.lastInputState = { up: false, down: false, left: false, right: false, a: false, b: false };
    });

    room.activeMinigame = {
      id: mgDef.id,
      name: mgDef.name,
      description: mgDef.description,
      duration: mgDef.duration,
      instructions: mgDef.instructions,
      timeRemaining: mgDef.duration,
      isPaused: false,
      controllerConfig: mgDef.controllerConfig,
      data: {}
    };

    room.phase = 'MINIGAME_INTRO';
    this.onStateChange(room);

    // Call game setup
    mgDef.setup(room);

    // Bot automation: bots simulate reading instructions and press ready after 1.5 - 2.8s
    Object.values(room.players).forEach(p => {
      if (p.isBot) {
        this.safeTimeout(() => {
          if (room.phase === 'MINIGAME_INTRO') {
            this.handleMinigameReady(room, p.id);
          }
        }, 1500 + Math.random() * 1300);
      }
    });
  }

  // Handle player pressing READY on mobile
  public handleMinigameReady(room: RoomState, playerId: string) {
    if (room.phase !== 'MINIGAME_INTRO') return;
    const player = room.players[playerId];
    if (!player || player.minigameReady) return;

    player.minigameReady = true;
    this.onStateChange(room);

    // Check if all active players are ready
    const activePlayers = Object.values(room.players).filter(p => p.connected || p.isBot);
    const allReady = activePlayers.length > 0 && activePlayers.every(p => p.minigameReady);

    if (allReady) {
      this.startMinigameCountdown(room);
    }
  }

  // Host override: "START ANYWAY" when at least 1 player is ready
  public forceStartMinigame(room: RoomState) {
    if (room.phase !== 'MINIGAME_INTRO') return;
    const anyReady = Object.values(room.players).some(p => p.minigameReady);
    if (anyReady) {
      this.startMinigameCountdown(room);
    }
  }

  // Countdown phase: 3... 2... 1... GO!
  public startMinigameCountdown(room: RoomState) {
    if (room.phase === 'MINIGAME_COUNTDOWN' || room.phase === 'MINIGAME_PLAY') return;
    room.phase = 'MINIGAME_COUNTDOWN';
    this.onStateChange(room);

    // 3.2s countdown on Host before active gameplay begins
    this.safeTimeout(() => {
      if (room.phase !== 'MINIGAME_COUNTDOWN') return;
      const mgDef = room.activeMinigame ? MINIGAMES[room.activeMinigame.id] : MINIGAMES['reaction-rush'];
      this.startMinigamePlay(room, mgDef);
    }, 3200);
  }

  // Active Minigame loop (20 Hz simulation tick for real-time arcade responsiveness)
  private startMinigamePlay(room: RoomState, mgDef: any) {
    room.phase = 'MINIGAME_PLAY';
    mgDef.start(room);
    this.onStateChange(room);

    if (this.minigameInterval) clearInterval(this.minigameInterval);

    const stepMs = 50; // 20 updates per second
    this.minigameInterval = setInterval(() => {
      if (room.isPaused) return;

      const dt = stepMs / 1000;
      if (room.activeMinigame) {
        room.activeMinigame.timeRemaining = Math.max(0, room.activeMinigame.timeRemaining - dt);
        const endedEarly = mgDef.update(room, dt);

        if (room.activeMinigame.timeRemaining <= 0 || endedEarly) {
          this.endMinigame(room, mgDef);
        } else {
          this.onStateChange(room);
        }
      }
    }, stepMs);
  }

  // Handle player inputs during minigames
  public handleMinigameInput(room: RoomState, playerId: string, data: any) {
    if (room.phase !== 'MINIGAME_PLAY' || !room.activeMinigame) return;
    const player = room.players[playerId];
    if (player && data && typeof data === 'object') {
      if ('up' in data || 'a' in data || 'left' in data || 'right' in data) {
        player.lastInputState = {
          up: Boolean(data.up),
          down: Boolean(data.down),
          left: Boolean(data.left),
          right: Boolean(data.right),
          a: Boolean(data.a),
          b: Boolean(data.b),
        };
      }
    }
    const mgDef = MINIGAMES[room.activeMinigame.id];
    if (mgDef) {
      mgDef.handleInput(room, playerId, data);
      this.onStateChange(room);
    }
  }

  // End active minigame and tally rewards
  public endMinigame(room: RoomState, mgDef: any) {
    if (this.minigameInterval) {
      clearInterval(this.minigameInterval);
      this.minigameInterval = null;
    }

    const results = mgDef.calculateResults(room);
    mgDef.cleanup(room);

    // Award coins and update win counters
    results.forEach((res: MinigameResultEntry) => {
      const player = room.players[res.playerId];
      if (player) {
        player.coins += res.coinsEarned;
        player.totalCoinsEarned += res.coinsEarned;
        if (res.rank === 1) {
          player.minigamesWon++;
        }
        // Reset single-round modifiers
        player.boostActive = false;
        player.trapActive = false;
      }
    });

    if (room.activeMinigame) {
      room.activeMinigame.results = results;
    }
    room.phase = 'MINIGAME_RESULTS';
    this.updateRankings(room);
    this.onStateChange(room);

    // After 6 seconds, transition to Round Summary or Finale
    this.safeTimeout(() => {
      if (room.phase !== 'MINIGAME_RESULTS') return;
      this.finishRound(room);
    }, 6000);
  }

  // Finish round and check if game ends
  private finishRound(room: RoomState) {
    if (room.currentRound >= room.totalRounds) {
      // Finale!
      this.startBonusCrowns(room);
    } else {
      room.currentRound++;
      room.currentPlayerIndex = 0;
      room.phase = 'ROUND_SUMMARY';
      this.onStateChange(room);

      // After 4s on summary, back to board rolling!
      this.safeTimeout(() => {
        if (room.phase !== 'ROUND_SUMMARY') return;
        room.phase = 'BOARD_ROLL';
        this.onStateChange(room);
        this.checkBotTurn(room);
      }, 4000);
    }
  }

  // Finale: Bonus crowns ceremony
  public startBonusCrowns(room: RoomState) {
    room.phase = 'BONUS_CROWNS';
    room.bonusCrowns = [];
    const playersList = Object.values(room.players);

    // Potential categories
    const categories = [
      {
        id: 'minigame_master',
        category: 'MINIGAME MASTER',
        title: 'A Minijátékok Királya',
        description: 'A legtöbb minijáték-győzelmet arató játékos!',
        getWinner: () => [...playersList].sort((a, b) => b.minigamesWon - a.minigamesWon)[0]
      },
      {
        id: 'coin_king',
        category: 'COIN KING',
        title: 'Pénzhegyek Ura',
        description: 'A játék során a legtöbb érmét felhalmozó játékos!',
        getWinner: () => [...playersList].sort((a, b) => b.totalCoinsEarned - a.totalCoinsEarned)[0]
      },
      {
        id: 'comeback_king',
        category: 'COMEBACK KING',
        title: 'Főnix Madár',
        description: 'A legmélyebbről a legmagasabbra kapaszkodó játékos!',
        getWinner: () => [...playersList].sort((a, b) => (b.initialRank || 1) - b.currentRank - ((a.initialRank || 1) - a.currentRank))[0]
      },
      {
        id: 'lucky_devil',
        category: 'LUCKY DEVIL',
        title: 'Fortuna Kedvence',
        description: 'A legtöbb pozitív meglepetést élvező játékos!',
        getWinner: () => [...playersList].sort((a, b) => b.positiveEvents - a.positiveEvents)[0]
      }
    ];

    // Pick 2 random bonus categories
    const shuffled = [...categories].sort(() => Math.random() - 0.5).slice(0, 2);
    shuffled.forEach(cat => {
      const winner = cat.getWinner();
      if (winner) {
        winner.crowns++;
        room.bonusCrowns.push({
          category: cat.category,
          title: cat.title,
          description: cat.description,
          winnerPlayerId: winner.id,
          winnerPlayerName: winner.name
        });
      }
    });

    this.updateRankings(room);
    this.onStateChange(room);

    // After 6 seconds, transition to PODIUM!
    this.safeTimeout(() => {
      if (room.phase !== 'BONUS_CROWNS') return;
      room.phase = 'PODIUM';
      this.onStateChange(room);
    }, 6000);
  }

  // Restart match cleanly
  public restartGame(room: RoomState, removeBots: boolean = true) {
    this.clearAllTimers();
    room.currentRound = 1;
    room.phase = 'LOBBY';
    room.isPaused = false;
    room.currentPlayerIndex = 0;
    room.crownShopTileId = 18;
    room.lastDiceRoll = null;
    room.currentTileEffect = null;
    room.activeMinigame = null;
    room.activeChaosEvent = null;
    room.activeForkChoice = null;
    room.movementPath = null;
    room.lastReconnectedPlayer = null;
    room.bonusCrowns = [];
    room.activePartyChallenge = null;

    if (removeBots) {
      Object.keys(room.players).forEach(id => {
        if (room.players[id].isBot) {
          delete room.players[id];
        }
      });
      room.playerOrder = Object.keys(room.players);
    }

    Object.values(room.players).forEach(p => {
      p.coins = 10;
      p.crowns = 0;
      p.boardPosition = 0;
      p.isReady = p.isBot ? true : false;
      p.minigameReady = false;
      p.totalCoinsEarned = 10;
      p.minigamesWon = 0;
      p.positiveEvents = 0;
      p.riskyDecisions = 0;
      p.boostActive = false;
      p.trapActive = false;
      p.luckyDayActive = false;
      p.slowModeActive = false;
      p.shieldActive = false;
      p.secretMission = null;
    });

    this.updateRankings(room);
    this.onStateChange(room);
  }
}
