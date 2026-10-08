// Shared Types for PARTY MAYHEM

export type AvatarId = 
  | 'fox'
  | 'shark'
  | 'frog'
  | 'panda'
  | 'octopus'
  | 'cat'
  | 'robot'
  | 'ghost'
  | 'chicken'
  | 'dino';

export interface AvatarInfo {
  id: AvatarId;
  name: string;
  emoji: string;
  color: string;
  badge: string;
  description: string;
}

export type PartyMode = 'quick' | 'normal' | 'chaos';

export type TileType = 
  | 'BLUE'
  | 'GOLD'
  | 'RED'
  | 'DUEL'
  | 'STEAL'
  | 'SWAP'
  | 'CHAOS'
  | 'SECRET'
  | 'BOOST'
  | 'TRAP'
  | 'TELEPORT'
  | 'JACKPOT';

export interface BoardTile {
  id: number;
  type: TileType;
  x: number; // percentage coordinates 0-100 on board canvas (2D fallback)
  y: number;
  position3D?: [number, number, number]; // [x, y, z] in 3D world
  label: string;
  description: string;
  branchesTo?: number[]; // fork targets
  isShortcut?: boolean;
  isDangerous?: boolean;
}

export type HatId = 
  | 'none'
  | 'top-hat'
  | 'cap'
  | 'crown'
  | 'cowboy'
  | 'grad-cap'
  | 'party-hat'
  | 'frog-hat'
  | 'sun-hat';

export interface CosmeticHat {
  id: HatId;
  name: string;
  emoji: string;
  description: string;
}

export interface SecretMission {
  id: string;
  title: string;
  description: string;
  targetPlayerId?: string;
  rewardCoins: number;
  conditionType: 'beat_player' | 'top_two' | 'roll_even' | 'land_special' | 'leader_loses';
  completed?: boolean;
}

export interface Player {
  id: string; // Persistent UUID (NOT socket.id!)
  socketId?: string; // Transient socket ID
  playerToken: string; // Cryptographic UUID token stored in localStorage
  name: string;
  avatar: AvatarId;
  color: string;
  cosmetic: HatId;
  isReady: boolean;
  isBot: boolean;
  connected: boolean;
  disconnectedAt?: number | null;
  coins: number;
  crowns: number;
  boardPosition: number;
  
  // Stats for Bonus Crowns & Comeback
  totalCoinsEarned: number;
  minigamesWon: number;
  positiveEvents: number;
  riskyDecisions: number;
  initialRank?: number;
  currentRank: number;

  // Modifiers
  boostActive: boolean; // +50% next minigame
  trapActive: boolean; // next minigame penalty
  luckyDayActive: boolean; // min roll 4
  slowModeActive: boolean; // max roll 3
  shieldActive: boolean; // protected from negative event
  
  // Secret Mission
  secretMission?: SecretMission | null;

  // Minigame ready state
  minigameReady?: boolean;
}

export type GamePhase =
  | 'LOBBY'
  | 'BOARD_ROLL'
  | 'BOARD_ROLLING'
  | 'BOARD_MOVE'
  | 'BOARD_ACTION'
  | 'SHOP_DECISION'
  | 'RANDOM_EVENT'
  | 'MINIGAME_INTRO'
  | 'MINIGAME_COUNTDOWN'
  | 'MINIGAME_PLAY'
  | 'MINIGAME_RESULTS'
  | 'ROUND_SUMMARY'
  | 'BONUS_CROWNS'
  | 'PODIUM';

export interface MinigameResultEntry {
  playerId: string;
  score: number;
  rank: number;
  coinsEarned: number;
  extraInfo?: string;
}

export interface MinigameState {
  id: string;
  name: string;
  description: string;
  duration: number; // seconds
  instructions: string;
  timeRemaining: number;
  isPaused: boolean;
  data: Record<string, any>; // minigame specific state
  results?: MinigameResultEntry[];
}

export interface ChaosEvent {
  id: string;
  name: string;
  description: string;
  icon: string;
  affectType: 'all' | 'leader' | 'last' | 'random' | 'chosen' | 'board' | 'shop';
}

export interface BonusCrownAward {
  category: string;
  title: string;
  description: string;
  winnerPlayerId: string;
  winnerPlayerName: string;
}

export interface RoomState {
  roomCode: string;
  hostSocketId?: string;
  partyMode: PartyMode;
  totalRounds: number;
  currentRound: number;
  phase: GamePhase;
  isPaused: boolean;
  partyChallengeEnabled: boolean;
  
  players: Record<string, Player>;
  playerOrder: string[];
  currentPlayerIndex: number;
  
  // Board state
  crownShopTileId: number;
  lastDiceRoll: number | null;
  currentTileEffect: {
    tileId: number;
    type: TileType;
    message: string;
    details?: any;
  } | null;

  // Active Minigame
  activeMinigame: MinigameState | null;

  // Active Random Chaos Event
  activeChaosEvent: {
    event: ChaosEvent;
    details: string;
  } | null;

  // Active Fork Choice for active player
  activeForkChoice: {
    playerId: string;
    currentTileId: number;
    branches: number[];
  } | null;

  // Active step-by-step movement path for animated hopping
  movementPath?: {
    playerId: string;
    path: number[];
    targetTileId: number;
    remainingSteps?: number;
  } | null;

  // Reconnection banner announcement
  lastReconnectedPlayer: {
    name: string;
    timestamp: number;
  } | null;

  // Server LAN connectivity info broadcasted to clients
  serverLanIp?: string;
  serverPort?: number;
  serverLanUrl?: string;

  // Bonus Crowns at finale
  bonusCrowns: BonusCrownAward[];

  // Active party challenge (if party mode enabled)
  activePartyChallenge: string | null;

  // Dev mode flag
  isDevMode: boolean;
}

export interface HealthResponse {
  status: 'ok';
  server: string;
  time: number;
  lanIp: string;
  port: number;
  uptime: number;
}

