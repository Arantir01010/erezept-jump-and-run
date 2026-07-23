import Phaser from 'phaser'
import type { Theme, Themes } from '../level/schema'

/**
 * Prozedurale Platzhalter-Pixel-Art: Der Prototyp braucht keine Binär-Assets.
 * Custom-Art im PwC/gematik-Look ersetzt später nur die Texturen —
 * Schlüssel und Rastermaße sind hier dokumentiert (siehe docs/KONZEPT.md, Asset-Pipeline).
 */

const PX = 2 // ein Pattern-Zeichen = 2×2 Bildschirmpixel (bei 640×360 intern)

type ColorMap = Record<string, string>

function drawPattern(
  scene: Phaser.Scene,
  key: string,
  pattern: string[],
  colors: ColorMap,
  pixelSize = PX,
): void {
  if (scene.textures.exists(key)) return
  const g = scene.add.graphics()
  pattern.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) {
      const ch = row[x]
      if (ch === '.' || ch === ' ') continue
      const color = colors[ch]
      if (!color) continue
      g.fillStyle(Phaser.Display.Color.HexStringToColor(color).color, 1)
      g.fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize)
    }
  })
  g.generateTexture(key, pattern[0].length * pixelSize, pattern.length * pixelSize)
  g.destroy()
}

// ---------------------------------------------------------------- Paul

const PAUL_COLORS: ColorMap = {
  H: '#4a3120', // Haar
  S: '#e8b48a', // Haut
  B: '#2f6fd0', // Hemd
  R: '#d04a3a', // Hemd (Hurt-Frame)
  D: '#20242e', // Hose
  W: '#e8e8ee', // Schuhe
}

const PAUL_HEAD = ['....HHHH....', '...HSSSSH...', '...SSSSSS...', '....SSSS....']

function paulFrame(body: string[]): string[] {
  return [...PAUL_HEAD, ...body]
}

const PAUL_FRAMES: Record<string, string[]> = {
  'player-idle0': paulFrame([
    '...BBBBBB...',
    '..BBBBBBBB..',
    '..S.BBBB.S..',
    '...DDDDDD...',
    '...DD..DD...',
    '...DD..DD...',
    '...WW..WW...',
    '............',
  ]),
  'player-idle1': paulFrame([
    '...BBBBBB...',
    '..BBBBBBBB..',
    '..S.BBBB.S..',
    '...DDDDDD...',
    '...DD..DD...',
    '...DD..DD...',
    '............',
    '...WW..WW...',
  ]),
  'player-run0': paulFrame([
    '...BBBBBB...',
    '..BBBBBBBB..',
    '..S.BBBB.S..',
    '...DDDDDD...',
    '..DD....DD..',
    '.DD......DD.',
    '.WW......WW.',
    '............',
  ]),
  'player-run1': paulFrame([
    '...BBBBBB...',
    '..BBBBBBBB..',
    '...SBBBBS...',
    '...DDDDDD...',
    '...DDDDD....',
    '....DDDD....',
    '....WWWW....',
    '............',
  ]),
  'player-run2': paulFrame([
    '...BBBBBB...',
    '..BBBBBBBB..',
    '..S.BBBB.S..',
    '...DDDDDD...',
    '..DD...DD...',
    '..DD....DD..',
    '..WW....WW..',
    '............',
  ]),
  'player-run3': paulFrame([
    '...BBBBBB...',
    '..BBBBBBBB..',
    '...SBBBBS...',
    '...DDDDDD...',
    '....DDDD....',
    '...DD..DD...',
    '...WW..WW...',
    '............',
  ]),
  'player-jump': paulFrame([
    '...BBBBBB...',
    '..SBBBBBBS..',
    '..BBBBBBBB..',
    '...DDDDDD...',
    '..DD....DD..',
    '..WW....WW..',
    '............',
    '............',
  ]),
  'player-fall': paulFrame([
    '..SBBBBBBS..',
    '..BBBBBBBB..',
    '...BBBBBB...',
    '...DDDDDD...',
    '...DD.DD....',
    '...WW.WW....',
    '............',
    '............',
  ]),
  'player-hurt': [
    '....HHHH....',
    '...HSSSSH...',
    '...SSSSSS...',
    '....SSSS....',
    '...RRRRRR...',
    '..RRRRRRRR..',
    '..S.RRRR.S..',
    '...DDDDDD...',
    '...DD..DD...',
    '...DD..DD...',
    '...WW..WW...',
    '............',
  ],
  // Duck: eigene, niedrige Silhouette (Hitbox wird im Player halbiert)
  'player-duck': [
    '............',
    '............',
    '............',
    '............',
    '....HHHH....',
    '...HSSSSH...',
    '...SSSSSS...',
    '..BBBBBBBB..',
    '.SBBBBBBBBS.',
    '..DDDDDDDD..',
    '..WW....WW..',
    '............',
  ],
}

// ---------------------------------------------------------------- REZI

const REZI_COLORS: ColorMap = {
  M: '#bff0dc', // Körper mint
  O: '#4a9b7d', // Rand
  E: '#ffffff', // Auge
  P: '#20242e', // Pupille
  C: '#d04a3a', // Rezept-Kreuz
  W: '#e8fff4', // Glanz/Flügel
}

const REZI_FRAMES: Record<string, string[]> = {
  'rezi-0': [
    '..OOOOOOOO..',
    '.OMMMMMMMMO.',
    'WOMEEMMEEMO.',
    '.OMEPMMEPMO.',
    '.OMMMMMMMMO.',
    '.OMMCCCCMMO.',
    '.OMMMCCMMMO.',
    '.OMMMCCMMMO.',
    '.OMMMMMMMMO.',
    '..OOOOOOOO..',
  ],
  'rezi-1': [
    '..OOOOOOOO..',
    '.OMMMMMMMMO.',
    '.OMEEMMEEMO.',
    'WOMEPMMEPMO.',
    '.OMMMMMMMMO.',
    '.OMMCCCCMMO.',
    '.OMMMCCMMMO.',
    '.OMMMCCMMMO.',
    '.OMMMMMMMMO.',
    '..OOOOOOOO..',
  ],
}

// ---------------------------------------------------------------- Gegner & Objekte

const KRALLE_COLORS: ColorMap = { K: '#5a5f6e', D: '#2e323e', R: '#c04040' }
const KRALLE_FRAMES: Record<string, string[]> = {
  'kralle-open': [
    'DDKK......K.',
    '..KKKKK..K..',
    '..KKKKKKK...',
    '..KKKKKKK...',
    '..KKKKK..K..',
    'DDKK......K.',
  ],
  'kralle-closed': [
    'DDKK........',
    '..KKKKK.KK..',
    '..KKKKKKKK..',
    '..KKKKKKKK..',
    '..KKKKK.KK..',
    'DDKK........',
  ],
}

const KRAKE_COLORS: ColorMap = { K: '#7a4fd0', D: '#4a2f8a', E: '#ffffff', P: '#20242e' }
const KRAKE_FRAMES: Record<string, string[]> = {
  'krake-0': [
    '...KKKKKK...',
    '..KKKKKKKK..',
    '.KKEEKKEEKK.',
    '.KKEPKKEPKK.',
    '.KKKKKKKKKK.',
    '..KKKKKKKK..',
    '.K.KK.KK.K..',
    'K..K...K..K.',
  ],
  'krake-1': [
    '...KKKKKK...',
    '..KKKKKKKK..',
    '.KKEEKKEEKK.',
    '.KKEPKKEPKK.',
    '.KKKKKKKKKK.',
    '..KKKKKKKK..',
    '..K.KK.KK.K.',
    '.K..K...K..K',
  ],
}

const OBJECT_FRAMES: { key: string; pattern: string[]; colors: ColorMap }[] = [
  {
    key: 'datenbit',
    pattern: ['..C..', '.CCC.', 'CCWCC', '.CCC.', '..C..'],
    colors: { C: '#4de3ff', W: '#ffffff' },
  },
  {
    key: 'portal-0',
    pattern: [
      '...AAAAAA...',
      '..A......A..',
      '.A..BBBB..A.',
      '.A.B....B.A.',
      '.A.B.WW.B.A.',
      '.A.B.WW.B.A.',
      '.A.B....B.A.',
      '.A..BBBB..A.',
      '..A......A..',
      '...AAAAAA...',
    ],
    colors: { A: '#4de3ff', B: '#7a5cff', W: '#ffffff' },
  },
  {
    key: 'portal-1',
    pattern: [
      '...BBBBBB...',
      '..B......B..',
      '.B..AAAA..B.',
      '.B.A....A.B.',
      '.B.A.WW.A.B.',
      '.B.A.WW.A.B.',
      '.B.A....A.B.',
      '.B..AAAA..B.',
      '..B......B..',
      '...BBBBBB...',
    ],
    colors: { A: '#4de3ff', B: '#7a5cff', W: '#ffffff' },
  },
  {
    key: 'gate',
    pattern: [
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'G..G',
      'GGGG',
      'GGGG',
    ],
    colors: { G: '#8a93a8' },
  },
  {
    key: 'stempel',
    pattern: [
      '.....HH.....',
      '.....HH.....',
      '.....HH.....',
      '..GGGGGGGG..',
      '.GGGGGGGGGG.',
      '.GGGGGGGGGG.',
      '.GGGGGGGGGG.',
      '..GGGGGGGG..',
    ],
    colors: { H: '#5a5f6e', G: '#ffd75e' },
  },
  {
    key: 'podest',
    pattern: ['AAAAAAAAAAAA', 'ADDDDDDDDDDA', 'AAAAAAAAAAAA'],
    colors: { A: '#4de3ff', D: '#16255c' },
  },
  {
    key: 'checkpoint',
    pattern: ['F....', 'FFF..', 'FFFFF', 'FFF..', 'F....', 'F....', 'F....', 'F....'],
    colors: { F: '#7fd07f' },
  },
  {
    key: 'door',
    pattern: [
      'DDDDDDDDDD',
      'D........D',
      'D.AAAAAA.D',
      'D.A....A.D',
      'D.A.WW.A.D',
      'D.A.WW.A.D',
      'D.A....A.D',
      'D.AAAAAA.D',
      'D........D',
      'DDDDDDDDDD',
      'DDDDDDDDDD',
      'DDDDDDDDDD',
    ],
    colors: { D: '#3a4152', A: '#ffd75e', W: '#ffffff' },
  },
  {
    key: 'dusche',
    pattern: ['..KKKKKK..', '.KKKKKKKK.', 'KKKKKKKKKK', '.A.A.A.A.A'],
    colors: { K: '#7a5cff', A: '#4de3ff' },
  },
  {
    key: 'siegel-blende',
    pattern: [
      '.GGGGGGGGGG.',
      'GGWWGGGGWWGG',
      'GGGGGGGGGGGG',
      'GG.GGGGGG.GG',
      'GGG.GGGG.GGG',
      'GGGG.WW.GGGG',
      '.GGGGWWGGGG.',
      '..GGGGGGGG..',
      '...GGGGGG...',
      '....GGGG....',
    ],
    colors: { G: '#ffd75e', W: '#ffffff' },
  },
  {
    key: 'seal-egk',
    pattern: [
      'GGGGGGGG',
      'GWWGGGGG',
      'GWWGGGGG',
      'GGGGGGGG',
      'GGGGDDDG',
      'GGGGGGGG',
    ],
    colors: { G: '#7fd07f', W: '#ffd75e', D: '#2e6e3e' },
  },
  {
    key: 'seal-vpn',
    pattern: [
      '.CCCCCC.',
      'CCCCCCCC',
      'CC.WW.CC',
      'CC.WW.CC',
      '.CCCCCC.',
      '..CCCC..',
      '...CC...',
    ],
    colors: { C: '#4de3ff', W: '#ffffff' },
  },
  {
    key: 'seal-generic',
    pattern: [
      '...GG...',
      '..GGGG..',
      '.GGWWGG.',
      'GGGWWGGG',
      '.GGWWGG.',
      '..GGGG..',
      '...GG...',
    ],
    colors: { G: '#ffd75e', W: '#ffffff' },
  },
]

// ---------------------------------------------------------------- Avatar-Icons (Highscore)

const AVATAR_BASES = [
  '#d04a3a',
  '#2f6fd0',
  '#7fd07f',
  '#ffd75e',
  '#7a5cff',
  '#4de3ff',
  '#e88ab6',
  '#e8934a',
  '#4a9b7d',
  '#8a93a8',
  '#c9a53a',
  '#bff0dc',
]

function makeAvatars(scene: Phaser.Scene): void {
  AVATAR_BASES.forEach((base, i) => {
    const eyes = i % 2 === 0 ? ['..P..P..', '........'] : ['.PP..PP.', '........']
    const mouth = i % 3 === 0 ? '..PPPP..' : i % 3 === 1 ? '...PP...' : '.P....P.'
    drawPattern(
      scene,
      `avatar-${i}`,
      ['.AAAAAA.', 'AAAAAAAA', ...eyes.map((r) => r.replace(/\./g, 'A').replace(/P/g, 'P')), 'AAAAAAAA', mouth.replace(/\./g, 'A'), 'AAAAAAAA', '.AAAAAA.'],
      { A: base, P: '#20242e' },
    )
  })
}

// ---------------------------------------------------------------- Theme-Tilesets

export const TILESET_COLUMNS = 8
export const TILE_SIZE = 16

/**
 * Tileset-Textur pro Theme: 8 Kacheln à 16×16 in einer Reihe (128×16).
 * GIDs in den Tilemaps: 1=Boden, 2=Boden-Oberkante, 3=Plattform, 4=Gold-Pad,
 * 5=Akzentblock, 6=Glas (Tunnelwand), 7=dunkle Füllung, 8=Strebe.
 */
function makeTileset(scene: Phaser.Scene, themeKey: string, theme: Theme): void {
  const key = `tiles-${themeKey}`
  if (scene.textures.exists(key)) return
  const canvas = scene.textures.createCanvas(key, TILESET_COLUMNS * TILE_SIZE, TILE_SIZE)
  if (!canvas) return
  const ctx = canvas.context

  const fill = (i: number, color: string) => {
    ctx.fillStyle = color
    ctx.fillRect(i * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE)
  }
  const px = (i: number, x: number, y: number, w: number, h: number, color: string) => {
    ctx.fillStyle = color
    ctx.fillRect(i * TILE_SIZE + x, y, w, h)
  }

  // 0: Boden-Füllung mit Leiterbahn-Punkten (+ Speckle & leuchtende Knoten)
  fill(0, theme.ground)
  px(0, 3, 5, 2, 2, theme.detail)
  px(0, 10, 11, 2, 2, theme.detail)
  px(0, 7, 8, 6, 1, theme.detail)
  px(0, 12, 8, 1, 1, theme.accent) // Leiterbahn-Knoten „unter Strom"
  px(0, 1, 13, 1, 1, 'rgba(0,0,0,0.25)')
  px(0, 6, 2, 1, 1, 'rgba(0,0,0,0.2)')
  px(0, 14, 4, 1, 1, 'rgba(255,255,255,0.06)')
  // 1: Boden-Oberkante (+ 1-px-Kantenlicht — lässt Plattformkanten „gefasst" wirken)
  fill(1, theme.ground)
  px(1, 0, 0, 16, 4, theme.groundTop)
  px(1, 0, 0, 16, 1, 'rgba(255,255,255,0.22)')
  px(1, 2, 1, 2, 1, theme.accent)
  px(1, 11, 2, 2, 1, theme.accent)
  px(1, 5, 6, 1, 1, 'rgba(0,0,0,0.18)')
  // 2: Plattform (+ Kantenlicht)
  fill(2, theme.detail)
  px(2, 0, 0, 16, 2, theme.groundTop)
  px(2, 0, 0, 16, 1, 'rgba(255,255,255,0.2)')
  px(2, 0, 14, 16, 2, theme.skyTop)
  // 3: Gold-Pad (Kontaktfläche)
  fill(3, '#c9a53a')
  px(3, 0, 0, 16, 3, '#ffd75e')
  px(3, 4, 6, 3, 3, '#ffe9a0')
  // 4: Akzentblock
  fill(4, theme.skyBottom)
  px(4, 0, 0, 16, 1, theme.accent)
  px(4, 0, 15, 16, 1, theme.accent)
  px(4, 0, 0, 1, 16, theme.accent)
  px(4, 15, 0, 1, 16, theme.accent)
  // 5: Glas (Tunnelwand) — doppelter Lichtreflex wirkt „gläserner"
  ctx.fillStyle = 'rgba(140, 220, 255, 0.35)'
  ctx.fillRect(5 * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE)
  px(5, 0, 0, 16, 1, theme.accent)
  px(5, 0, 15, 16, 1, theme.accent)
  px(5, 3, 3, 1, 6, 'rgba(255,255,255,0.6)')
  px(5, 5, 2, 1, 3, 'rgba(255,255,255,0.3)')
  px(5, 11, 8, 1, 5, 'rgba(255,255,255,0.22)')
  // 6: dunkle Füllung
  fill(6, theme.skyTop)
  // 7: Strebe
  fill(7, theme.skyBottom)
  for (let d = 0; d < 16; d += 4) px(7, d, d, 2, 2, theme.detail)

  canvas.refresh()
}

// ---------------------------------------------------------------- Licht-/Effekt-Texturen

/**
 * Weiche Verlaufs-Texturen für Lichteffekte (Glows, Staub, Vignette).
 * Per Canvas-Gradient erzeugt und LINEAR gefiltert — bewusst NICHT pixelig:
 * Licht liegt als weiche Schicht ÜBER der knackigen Pixel-Art (moderner
 * Indie-Look à la „Pixel-Art + Soft Lighting").
 */
function makeFxTextures(scene: Phaser.Scene): void {
  const makeRadial = (key: string, size: number, stops: [number, string][]): void => {
    if (scene.textures.exists(key)) return
    const canvas = scene.textures.createCanvas(key, size, size)
    if (!canvas) return
    const ctx = canvas.context
    const grd = ctx.createRadialGradient(size / 2, size / 2, size * 0.03, size / 2, size / 2, size / 2)
    for (const [pos, color] of stops) grd.addColorStop(pos, color)
    ctx.fillStyle = grd
    ctx.fillRect(0, 0, size, size)
    canvas.refresh()
    scene.textures.get(key).setFilter(Phaser.Textures.FilterMode.LINEAR)
  }

  // Punktlicht (ADD-Blend, per Tint eingefärbt)
  makeRadial('fx-glow', 64, [
    [0, 'rgba(255,255,255,1)'],
    [0.45, 'rgba(255,255,255,0.32)'],
    [1, 'rgba(255,255,255,0)'],
  ])
  // Staubkorn / Datenfunke
  makeRadial('fx-mote', 16, [
    [0, 'rgba(255,255,255,0.9)'],
    [0.5, 'rgba(255,255,255,0.35)'],
    [1, 'rgba(255,255,255,0)'],
  ])

  // Vignette: transparente Mitte, dunkle Ränder — Tiefe ohne Kosten
  if (!scene.textures.exists('fx-vignette')) {
    const w = 480
    const h = 270
    const canvas = scene.textures.createCanvas('fx-vignette', w, h)
    if (canvas) {
      const ctx = canvas.context
      const r = Math.hypot(w / 2, h / 2)
      const grd = ctx.createRadialGradient(w / 2, h / 2, r * 0.45, w / 2, h / 2, r * 1.02)
      grd.addColorStop(0, 'rgba(4,7,13,0)')
      grd.addColorStop(0.75, 'rgba(4,7,13,0.22)')
      grd.addColorStop(1, 'rgba(4,7,13,0.6)')
      ctx.fillStyle = grd
      ctx.fillRect(0, 0, w, h)
      canvas.refresh()
      scene.textures.get('fx-vignette').setFilter(Phaser.Textures.FilterMode.LINEAR)
    }
  }
}

// ---------------------------------------------------------------- Öffentliche API

export function generateAllTextures(scene: Phaser.Scene, themes: Themes): void {
  makeFxTextures(scene)
  for (const [key, pattern] of Object.entries(PAUL_FRAMES)) drawPattern(scene, key, pattern, PAUL_COLORS)
  for (const [key, pattern] of Object.entries(REZI_FRAMES)) drawPattern(scene, key, pattern, REZI_COLORS)
  for (const [key, pattern] of Object.entries(KRALLE_FRAMES)) drawPattern(scene, key, pattern, KRALLE_COLORS)
  for (const [key, pattern] of Object.entries(KRAKE_FRAMES)) drawPattern(scene, key, pattern, KRAKE_COLORS)
  for (const obj of OBJECT_FRAMES) drawPattern(scene, obj.key, obj.pattern, obj.colors)
  makeAvatars(scene)
  for (const [themeKey, theme] of Object.entries(themes)) makeTileset(scene, themeKey, theme)
}

export function sealTextureKey(scene: Phaser.Scene, sealId: string): string {
  return scene.textures.exists(sealId) ? sealId : 'seal-generic'
}

export function createAnimations(scene: Phaser.Scene): void {
  const anims = scene.anims
  const ensure = (key: string, frames: string[], frameRate: number, repeat: number) => {
    if (anims.exists(key)) return
    anims.create({ key, frames: frames.map((f) => ({ key: f })), frameRate, repeat })
  }
  ensure('player-idle', ['player-idle0', 'player-idle1'], 2, -1)
  ensure('player-run', ['player-run0', 'player-run1', 'player-run2', 'player-run3'], 10, -1)
  ensure('player-jump', ['player-jump'], 1, 0)
  ensure('player-fall', ['player-fall'], 1, 0)
  ensure('player-duck', ['player-duck'], 1, 0)
  ensure('player-hurt', ['player-hurt'], 1, 0)
  ensure('rezi-float', ['rezi-0', 'rezi-1'], 4, -1)
  ensure('krake-swim', ['krake-0', 'krake-1'], 3, -1)
  ensure('portal-spin', ['portal-0', 'portal-1'], 4, -1)
}
