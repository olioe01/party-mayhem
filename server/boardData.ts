import { BoardTile } from '../shared/types';

// 36-Tile Winding Board with Forks, Shortcuts, and Danger Zones
export const BOARD_TILES: BoardTile[] = [
  // Start Area
  { id: 0, type: 'BLUE', x: 10, y: 85, label: 'START', description: 'Rajt mező! Minden áthaladás után szerencse vár!' },
  { id: 1, type: 'BLUE', x: 18, y: 85, label: '+3 COIN', description: '+3 Érme a pénztárcádba!' },
  { id: 2, type: 'GOLD', x: 26, y: 85, label: '+8 COIN', description: 'Aranybánya! +8 Érme!' },
  { id: 3, type: 'SECRET', x: 34, y: 82, label: 'TITOK', description: 'Titkos esemény csak a telefonodon!' },
  { id: 4, type: 'BLUE', x: 42, y: 80, label: '+3 COIN', description: '+3 Érme!' },
  { id: 5, type: 'STEAL', x: 50, y: 80, label: 'LOPÁS', description: 'Lopj 3-8 érmét egy választott ellenféltől!' },
  { id: 6, type: 'RED', x: 58, y: 82, label: '-5 COIN', description: 'Jaj! -5 Érme veszteség!' },
  { id: 7, type: 'BOOST', x: 66, y: 85, label: 'BOOST', description: 'Következő minijáték pontjaid +50%!' },
  
  // Fork 1: Main branch or Risky Shortcut
  { id: 8, type: 'CHAOS', x: 74, y: 85, label: 'ELÁGAZÁS', description: 'Választási pont! Shortcut vagy biztonságos út?', branchesTo: [9, 13] },
  
  // Risky Shortcut (Tiles 9-12)
  { id: 9, type: 'TRAP', x: 78, y: 72, label: 'CSAPDA', description: 'Veszélyes rövidítés! Hátrány a következő minijátékban!', isShortcut: true, isDangerous: true },
  { id: 10, type: 'RED', x: 80, y: 60, label: '-5 COIN', description: 'Balszerencse zóna!', isShortcut: true, isDangerous: true },
  { id: 11, type: 'JACKPOT', x: 80, y: 48, label: 'JACKPOT', description: 'Kockáztattál és nyertél! +20 Érme!', isShortcut: true },
  { id: 12, type: 'BLUE', x: 78, y: 36, label: '+3 COIN', description: 'Kijutottál a rövidítésből!', isShortcut: true },

  // Safe scenic loop (Tiles 13-17)
  { id: 13, type: 'BLUE', x: 84, y: 85, label: '+3 COIN', description: 'Biztonságos útvonal.' },
  { id: 14, type: 'GOLD', x: 90, y: 75, label: '+8 COIN', description: 'Arany mező a biztonságos úton!' },
  { id: 15, type: 'SWAP', x: 92, y: 60, label: 'HELYCSERE', description: 'Helycsere egy véletlenszerű játékossal!' },
  { id: 16, type: 'BLUE', x: 90, y: 45, label: '+3 COIN', description: '+3 Érme!' },
  { id: 17, type: 'DUEL', x: 84, y: 35, label: 'PÁRBAJ', description: 'Hívj ki valakit egy gyors érmepárbajra!' },

  // Convergence at Upper Area (Tile 18) - Initial Crown Shop spot!
  { id: 18, type: 'GOLD', x: 72, y: 30, label: 'SHOP', description: 'KORONA BOLT! 1 Korona = 25 Érme!' },
  { id: 19, type: 'BLUE', x: 62, y: 28, label: '+3 COIN', description: '+3 Érme!' },
  { id: 20, type: 'TELEPORT', x: 52, y: 26, label: 'TELEPORT', description: 'Térugrás a pálya egy másik pontjára!' },
  { id: 21, type: 'RED', x: 42, y: 26, label: '-5 COIN', description: 'Láva mező! -5 Érme!' },
  { id: 22, type: 'CHAOS', x: 32, y: 28, label: 'KAOSZ', description: 'Azonnali kaotikus világméretű esemény!' },
  
  // Upper-left fork
  { id: 23, type: 'BLUE', x: 22, y: 32, label: '+3 COIN', description: '+3 Érme!', branchesTo: [24, 27] },
  
  // Left shortcut (Tiles 24-26)
  { id: 24, type: 'SECRET', x: 18, y: 44, label: 'TITOK', description: 'Titkos küldetés aktiválás!', isShortcut: true },
  { id: 25, type: 'TRAP', x: 14, y: 56, label: 'CSAPDA', description: 'Csapda!', isShortcut: true, isDangerous: true },
  { id: 26, type: 'GOLD', x: 16, y: 68, label: '+8 COIN', description: 'Bátor vagy, itt az arany!', isShortcut: true },

  // Outer scenic loop (Tiles 27-31)
  { id: 27, type: 'BLUE', x: 12, y: 26, label: '+3 COIN', description: 'Külső kör.' },
  { id: 28, type: 'STEAL', x: 6, y: 35, label: 'LOPÁS', description: 'Lopj érmét!' },
  { id: 29, type: 'BLUE', x: 6, y: 50, label: '+3 COIN', description: '+3 Érme!' },
  { id: 30, type: 'DUEL', x: 6, y: 65, label: 'PÁRBAJ', description: 'Párbaj zóna!' },
  { id: 31, type: 'BOOST', x: 8, y: 75, label: 'BOOST', description: 'Minijáték pont bónusz!' },

  // Final stretch back to Start
  { id: 32, type: 'SWAP', x: 22, y: 65, label: 'HELYCSERE', description: 'Kavarodás a finis előtt!' },
  { id: 33, type: 'BLUE', x: 32, y: 65, label: '+3 COIN', description: '+3 Érme!' },
  { id: 34, type: 'CHAOS', x: 42, y: 65, label: 'KAOSZ', description: 'Káosz esemény!' },
  { id: 35, type: 'GOLD', x: 52, y: 65, label: '+8 COIN', description: 'Arany az utolsó egyenesben!' }
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
  if (currentId === 12) return 18; // risky shortcut rejoins at 18
  if (currentId === 17) return 18; // safe route rejoins at 18
  if (currentId === 26) return 32; // left shortcut rejoins at 32
  if (currentId === 31) return 32; // outer loop rejoins at 32
  if (currentId === 35) return 0;  // loop back to start

  return (currentId + 1) % BOARD_TILES.length;
}
