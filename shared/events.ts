// Socket.IO Client & Server Event Contracts

export const SOCKET_EVENTS = {
  // Connection / Lobby
  JOIN_ROOM: 'room:join',
  JOIN_HOST: 'room:join_host',
  ROOM_STATE: 'room:state',
  RECONNECT_PLAYER: 'player:reconnect',
  PLAYER_JOIN_SUCCESS: 'player:join_success',
  PLAYER_RECONNECT_SUCCESS: 'player:reconnect_success',
  SET_COSMETIC: 'player:set_cosmetic',
  TOGGLE_READY: 'player:toggle_ready',
  KICK_PLAYER: 'host:kick_player',
  SET_PARTY_MODE: 'host:set_party_mode',
  TOGGLE_PARTY_CHALLENGE: 'host:toggle_party_challenge',
  ADD_BOT: 'host:add_bot',
  REMOVE_BOT: 'host:remove_bot',
  DEV_SELECT_MINIGAME: 'host:dev_select_minigame',
  DEV_MODIFY_PLAYER: 'host:dev_modify_player',
  DEV_TRIGGER_EVENT: 'host:dev_trigger_event',
  START_GAME: 'host:start_game',
  PAUSE_GAME: 'host:pause_game',
  SKIP_MINIGAME: 'host:skip_minigame',
  RESTART_GAME: 'host:restart_game',

  // Board phase
  PLAYER_ROLL_DICE: 'player:roll_dice',
  DICE_ROLLED: 'board:dice_rolled',
  PLAYER_MOVED: 'board:player_moved',
  CHOOSE_FORK: 'player:choose_fork',
  DECIDE_SHOP: 'player:decide_shop',
  
  // Tile actions
  TILE_ACTION_TRIGGERED: 'board:tile_action',
  TILE_ACTION_COMPLETE: 'board:action_complete',
  
  // Random Event
  TRIGGER_RANDOM_EVENT: 'event:triggered',
  RESOLVE_RANDOM_EVENT: 'event:resolved',

  // Minigame
  MINIGAME_PREPARE: 'minigame:prepare',
  MINIGAME_READY: 'minigame:ready',
  MINIGAME_HOST_OVERRIDE: 'minigame:host_override',
  MINIGAME_START: 'minigame:start',
  MINIGAME_INPUT: 'minigame:input',
  MINIGAME_UPDATE: 'minigame:update',
  MINIGAME_FINISH: 'minigame:finish',

  // Social / Secret
  SECRET_MISSION_ASSIGNED: 'secret:assigned',
  SECRET_MISSION_RESULT: 'secret:result',
  PARTY_CHALLENGE_POPUP: 'party:challenge_popup',

  // Finale
  BONUS_CROWNS_START: 'finale:bonus_crowns',
  PODIUM_SHOW: 'finale:podium',

  // System & Network Diagnostics
  PING_CHECK: 'network:ping',
  PONG_CHECK: 'network:pong',
  ERROR: 'system:error'
} as const;
