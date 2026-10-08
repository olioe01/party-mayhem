import { BoardTile } from './types';

// 36-Tile Winding Board with Forks, Shortcuts, and Danger Zones
export const BOARD_TILES: BoardTile[] = [
  // Start Area (Party Beach)
  { id: 0, type: 'BLUE', x: 10, y: 85, position3D: [-7.0, 0.4, 7.0], label: 'START', description: 'Rajt mező! Minden áthaladás után szerencse vár!' },
  { id: 1, type: 'BLUE', x: 18, y: 85, position3D: [-4.0, 0.4, 7.5], label: '+3 COIN', description: '+3 Érme a pénztárcádba!' },
  { id: 2, type: 'GOLD', x: 26, y: 85, position3D: [-1.0, 0.4, 7.8], label: '+8 COIN', description: 'Aranybánya! +8 Érme!' },
  { id: 3, type: 'SECRET', x: 34, y: 82, position3D: [2.0, 0.4, 7.6], label: 'TITOK', description: 'Titkos esemény csak a telefonodon!' },
  { id: 4, type: 'BLUE', x: 42, y: 80, position3D: [5.0, 0.4, 7.2], label: '+3 COIN', description: '+3 Érme!' },
  { id: 5, type: 'STEAL', x: 50, y: 80, position3D: [7.5, 0.4, 6.2], label: 'LOPÁS', description: 'Lopj 3-8 érmét egy választott ellenféltől!' },
  { id: 6, type: 'RED', x: 58, y: 82, position3D: [9.2, 0.4, 4.8], label: '-5 COIN', description: 'Jaj! -5 Érme veszteség!' },
  { id: 7, type: 'BOOST', x: 66, y: 85, position3D: [10.5, 0.5, 3.0], label: 'BOOST', description: 'Következő minijáték pontjaid +50%!' },
  
  // Fork 1: Main branch or Risky Shortcut (Forest Fork)
  { id: 8, type: 'CHAOS', x: 74, y: 85, position3D: [11.0, 0.5, 1.0], label: 'ELÁGAZÁS', description: 'Választási pont! Shortcut vagy biztonságos út?', branchesTo: [9, 13] },
  
  // Risky Shortcut (Tiles 9-12 - Chaos Cave)
  { id: 9, type: 'TRAP', x: 78, y: 72, position3D: [9.0, 0.8, 0.0], label: 'CSAPDA', description: 'Veszélyes rövidítés! Hátrány a következő minijátékban!', isShortcut: true, isDangerous: true },
  { id: 10, type: 'RED', x: 80, y: 60, position3D: [8.0, 1.0, -1.5], label: '-5 COIN', description: 'Balszerencse zóna!', isShortcut: true, isDangerous: true },
  { id: 11, type: 'JACKPOT', x: 80, y: 48, position3D: [7.5, 1.1, -3.0], label: 'JACKPOT', description: 'Kockáztattál és nyertél! +20 Érme!', isShortcut: true },
  { id: 12, type: 'BLUE', x: 78, y: 36, position3D: [7.0, 0.9, -4.5], label: '+3 COIN', description: 'Kijutottál a rövidítésből!', isShortcut: true },

  // Safe scenic loop (Tiles 13-17 - Lake & Wooden Bridge)
  { id: 13, type: 'BLUE', x: 84, y: 85, position3D: [11.8, 0.4, -0.8], label: '+3 COIN', description: 'Biztonságos útvonal.' },
  { id: 14, type: 'GOLD', x: 90, y: 75, position3D: [12.0, 0.4, -2.8], label: '+8 COIN', description: 'Arany mező a biztonságos úton!' },
  { id: 15, type: 'SWAP', x: 92, y: 60, position3D: [11.2, 0.5, -4.6], label: 'HELYCSERE', description: 'Helycsere egy véletlenszerű játékossal!' },
  { id: 16, type: 'BLUE', x: 90, y: 45, position3D: [9.8, 0.6, -6.0], label: '+3 COIN', description: '+3 Érme!' },
  { id: 17, type: 'DUEL', x: 84, y: 35, position3D: [8.2, 0.7, -6.8], label: 'PÁRBAJ', description: 'Hívj ki valakit egy gyors érmepárbajra!' },

  // Convergence at Upper Area (Tile 18) - Crown Temple spot!
  { id: 18, type: 'GOLD', x: 72, y: 30, position3D: [6.0, 1.2, -7.0], label: 'SHOP', description: 'KORONA BOLT! 1 Korona = 25 Érme!' },
  { id: 19, type: 'BLUE', x: 62, y: 28, position3D: [4.0, 1.0, -7.2], label: '+3 COIN', description: '+3 Érme!' },
  { id: 20, type: 'TELEPORT', x: 52, y: 26, position3D: [2.0, 0.9, -7.4], label: 'TELEPORT', description: 'Térugrás a pálya egy másik pontjára!' },
  { id: 21, type: 'RED', x: 42, y: 26, position3D: [-0.5, 0.8, -7.5], label: '-5 COIN', description: 'Láva mező! -5 Érme!' },
  { id: 22, type: 'CHAOS', x: 32, y: 28, position3D: [-3.0, 0.7, -7.2], label: 'KAOSZ', description: 'Azonnali kaotikus világméretű esemény!' },
  
  // Upper-left fork (Neon / Mystery Forest fork)
  { id: 23, type: 'BLUE', x: 22, y: 32, position3D: [-5.5, 0.6, -6.8], label: '+3 COIN', description: '+3 Érme!', branchesTo: [24, 27] },
  
  // Left shortcut (Tiles 24-26 - Secret Cave)
  { id: 24, type: 'SECRET', x: 18, y: 44, position3D: [-5.8, 0.7, -4.5], label: 'TITOK', description: 'Titkos küldetés aktiválás!', isShortcut: true },
  { id: 25, type: 'TRAP', x: 14, y: 56, position3D: [-5.6, 0.6, -2.5], label: 'CSAPDA', description: 'Csapda!', isShortcut: true, isDangerous: true },
  { id: 26, type: 'GOLD', x: 16, y: 68, position3D: [-6.0, 0.5, -0.5], label: '+8 COIN', description: 'Bátor vagy, itt az arany!', isShortcut: true },

  // Outer scenic loop (Tiles 27-31 - Neon District)
  { id: 27, type: 'BLUE', x: 12, y: 26, position3D: [-7.8, 0.5, -6.5], label: '+3 COIN', description: 'Külső kör.' },
  { id: 28, type: 'STEAL', x: 6, y: 35, position3D: [-9.6, 0.4, -5.0], label: 'LOPÁS', description: 'Lopj érmét!' },
  { id: 29, type: 'BLUE', x: 6, y: 50, position3D: [-10.8, 0.4, -3.0], label: '+3 COIN', description: '+3 Érme!' },
  { id: 30, type: 'DUEL', x: 6, y: 65, position3D: [-11.0, 0.4, -0.8], label: 'PÁRBAJ', description: 'Párbaj zóna!' },
  { id: 31, type: 'BOOST', x: 8, y: 75, position3D: [-10.2, 0.4, 1.5], label: 'BOOST', description: 'Minijáték pont bónusz!' },

  // Final stretch back to Start (Party Boardwalk)
  { id: 32, type: 'SWAP', x: 22, y: 65, position3D: [-8.5, 0.4, 2.8], label: 'HELYCSERE', description: 'Kavarodás a finis előtt!' },
  { id: 33, type: 'BLUE', x: 32, y: 65, position3D: [-7.5, 0.4, 4.5], label: '+3 COIN', description: '+3 Érme!' },
  { id: 34, type: 'CHAOS', x: 42, y: 65, position3D: [-6.5, 0.4, 5.8], label: 'KAOSZ', description: 'Káosz esemény!' },
  { id: 35, type: 'GOLD', x: 52, y: 65, position3D: [-7.0, 0.4, 6.6], label: '+8 COIN', description: 'Arany az utolsó egyenesben!' }
];

// Helper to calculate the next tile for linear movement or branching
export function getNextTileId(currentId: number, chosenBranch?: number): number {
  const currentTile = BOARD_TILES.find(t => t.id === currentId);
  if (!currentTile) return (currentId + 1) % BOARD_TILES.length;

  if (currentTile.branchesTo && currentTile.branchesTo.length > 0) {
    if (chosenBranch !== undefined && currentTile.branchesTo.includes(chosenBranch)) {
      return chosenBranch;
    }
    return currentTile.branchesTo[0];
  }

  // Handle convergence after shortcuts
  if (currentId === 12) return 18;
  if (currentId === 17) return 18;
  if (currentId === 26) return 32;
  if (currentId === 31) return 32;
  if (currentId === 35) return 0;

  return (currentId + 1) % BOARD_TILES.length;
}
