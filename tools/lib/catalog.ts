/**
 * OBJEKTKATALOG — Single Source of Truth für den Level-Baukasten.
 *
 * Hier ist ALLES definiert, was ein Level benutzen darf:
 *   - welche Zeichen im layout.txt erlaubt sind (Gelände + Marker),
 *   - welche Objekt-Typen es gibt und welche Parameter sie akzeptieren
 *     (strikte zod-Schemas: unbekannte Felder = Fehler mit Korrekturvorschlag),
 *   - welche Werte für mechanics-Abschnitte, Siegel, Deko-Sprites gelten.
 *
 * Level-KIs lesen design/LEVELBAU.md — diese Datei hier ist die technische
 * Durchsetzung derselben Regeln. Beide müssen synchron bleiben.
 * GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
 */
import { z } from 'zod'
import { LTextSchema } from '../../src/level/schema'

export const TILE = 16
export const GRID_HEIGHT = 23
export const GRID_WIDTH_MIN = 40
export const GRID_WIDTH_MAX = 240

// ------------------------------------------------------------------ Gelände

/** GIDs des Tilesets „ti-tiles" (siehe src/gfx/TextureFactory.ts, makeTileset). */
export const GID = {
  LUFT: 0,
  BODEN_FUELLUNG: 1,
  BODEN_OBERKANTE: 2,
  PLATTFORM: 3,
  GOLD_PAD: 4,
  AKZENT: 5,
  GLAS: 6,
  DUNKEL: 7,
  STREBE: 8, // einzige NICHT-solide Kachel (GameScene: setCollisionByExclusion [-1, 0, 8])
} as const

export interface TileDef {
  gid: number
  solid: boolean
  name: string
}

/** Gelände-Zeichen im layout.txt. `#` bekommt seine Oberkante automatisch. */
export const TILE_CHARS: Record<string, TileDef> = {
  '.': { gid: GID.LUFT, solid: false, name: 'Luft' },
  ' ': { gid: GID.LUFT, solid: false, name: 'Luft' },
  '#': { gid: GID.BODEN_FUELLUNG, solid: true, name: 'Boden/Wand (Oberkante automatisch)' },
  '=': { gid: GID.PLATTFORM, solid: true, name: 'Plattform' },
  G: { gid: GID.GOLD_PAD, solid: true, name: 'Gold-Pad (markiert Aktions-Stellen)' },
  A: { gid: GID.AKZENT, solid: true, name: 'Akzentblock' },
  '~': { gid: GID.GLAS, solid: true, name: 'Glas (Tunnelwand)' },
  '%': { gid: GID.DUNKEL, solid: true, name: 'Dunkle Füllung (Außenraum)' },
  '|': { gid: GID.STREBE, solid: false, name: 'Deko-Strebe (NICHT solide)' },
}

/** Marker-Zeichen im layout.txt: einfache 1-Kachel-Objekte. */
export const MARKER_CHARS: Record<string, string> = {
  P: 'spawn',
  o: 'collectible',
  C: 'checkpoint',
  D: 'door-exit',
}

/** Diese Objekt-Typen dürfen NUR als Marker im layout.txt stehen (nie im JSON). */
export const MARKER_ONLY_TYPES = new Set(Object.values(MARKER_CHARS))

// ------------------------------------------------------------------ Objekte

const gateNameSchema = z
  .string()
  .regex(/^[a-z0-9-]+$/, 'Tor-Namen: nur Kleinbuchstaben, Ziffern, Bindestriche')

const baseFields = {
  tx: z.number().min(0, 'tx darf nicht negativ sein'),
  ty: z.number().min(0).max(GRID_HEIGHT, `ty muss zwischen 0 und ${GRID_HEIGHT} liegen`),
  tw: z.number().positive().max(60).optional(),
  th: z.number().positive().max(GRID_HEIGHT).optional(),
}

export interface ObjectTypeDef {
  /** Strikte Prüfung aller Felder (unbekanntes Feld = Fehler). */
  schema: z.ZodType<Record<string, unknown>>
  /** Standardgröße in Kacheln, wenn tw/th fehlen. */
  defaults: { tw: number; th: number }
  /** Objekt öffnet über das Pflichtfeld `gate` ein benanntes Tor. */
  opensGate?: boolean
  /** Objekt beendet das Level (jedes Level braucht genau einen Ausgang). */
  isExit?: boolean
  /** Objekt erzeugt eine begehbare Plattform (für den Spielbarkeits-Check). */
  makesPlatform?: boolean
  /** Spieler muss die Zone betreten können (Spielbarkeits-Check). */
  needsStandableInZone?: boolean
  /** Kurzbeschreibung für Fehlermeldungen. */
  doc: string
}

/**
 * Alle Objekt-Typen, die ein Level im `objects`-Array verwenden darf.
 * (spawn / collectible / checkpoint / door-exit sind Marker im layout.txt.)
 */
export const OBJECT_TYPES: Record<string, ObjectTypeDef> = {
  gate: {
    schema: z.strictObject({
      type: z.literal('gate'),
      name: gateNameSchema,
      ...baseFields,
    }),
    defaults: { tw: 0.5, th: 6 },
    doc: 'Benanntes Tor — blockiert, bis eine Sicherheits-Mechanik mit gate:"<name>" es öffnet',
  },
  'timing-gate': {
    schema: z.strictObject({
      type: z.literal('timing-gate'),
      gate: gateNameSchema,
      steps: z.number().int().min(2).max(8).optional(),
      stepMs: z.number().min(300).max(3000).optional(),
      ...baseFields,
    }),
    defaults: { tw: 8, th: 5 },
    opensGate: true,
    needsStandableInZone: true,
    doc: 'PIN-Schleuse: blauer Knopf im Takt der Lichter → öffnet das verknüpfte Tor',
  },
  'stillstand-podest': {
    schema: z.strictObject({
      type: z.literal('stillstand-podest'),
      gate: gateNameSchema,
      scanMs: z.number().min(400).max(4000).optional(),
      ...baseFields,
    }),
    defaults: { tw: 3, th: 0.4 },
    opensGate: true,
    makesPlatform: true,
    doc: 'Prüf-Podest: stillstehen bis der Scan durch ist → öffnet das verknüpfte Tor',
  },
  'krypto-dusche': {
    schema: z.strictObject({
      type: z.literal('krypto-dusche'),
      gate: gateNameSchema,
      ...baseFields,
    }),
    defaults: { tw: 5, th: 6 },
    opensGate: true,
    needsStandableInZone: true,
    doc: 'Verschlüsselungs-Dusche: TI-Aktion drücken → Schutz-Optik + Tor öffnet',
  },
  'deny-enemy': {
    schema: z.strictObject({
      type: z.literal('deny-enemy'),
      fromRight: z.boolean().optional(),
      reach: z.number().min(8).max(120).optional(),
      grabsBeforeBlock: z.number().int().min(1).max(5).optional(),
      activationRange: z.number().min(60).max(600).optional(),
      idleMs: z.number().min(400).max(4000).optional(),
      ...baseFields,
    }),
    defaults: { tw: 1.4, th: 0.4 },
    doc: 'Skimming-Kralle: greift rhythmisch, Spieler duckt sich — die TI blockt sie nach N Griffen',
  },
  'stamp-exit': {
    schema: z.strictObject({
      type: z.literal('stamp-exit'),
      ...baseFields,
    }),
    defaults: { tw: 6, th: 6 },
    isExit: true,
    needsStandableInZone: true,
    doc: 'Signatur-Stempel-Finale: blauer Knopf, wenn der Stempel oben wartet → Level geschafft',
  },
  'info-sign': {
    schema: z.strictObject({
      type: z.literal('info-sign'),
      textDe: z.string().min(1, 'textDe (deutscher Hinweistext) ist Pflicht'),
      textEn: z.string().optional(),
      ...baseFields,
    }),
    defaults: { tw: 2.5, th: 4 },
    doc: 'Unsichtbare Zone: REZI sagt den Text, wenn der Spieler hindurchläuft',
  },
  'moving-platform': {
    schema: z.strictObject({
      type: z.literal('moving-platform'),
      range: z.number().min(16).max(200).optional(),
      speed: z.number().min(10).max(120).optional(),
      ...baseFields,
    }),
    defaults: { tw: 2, th: 0.4 },
    makesPlatform: true,
    doc: 'Bewegliche Plattform: pendelt von Startposition um `range` Pixel nach rechts',
  },
  hazard: {
    schema: z.strictObject({
      type: z.literal('hazard'),
      ...baseFields,
    }),
    defaults: { tw: 1, th: 1 },
    doc: 'Schadenszone (kostet Datenbits). In Tube-Leveln VERBOTEN (geschützter Tunnel)',
  },
  deco: {
    schema: z.strictObject({
      type: z.literal('deco'),
      sprite: z.string().optional(),
      anim: z.string().optional(),
      drift: z.number().min(0).max(20).optional(),
      ...baseFields,
    }),
    defaults: { tw: 1.5, th: 1.5 },
    doc: 'Reine Kulisse ohne Physik (z. B. Datenkraken außen am Glas)',
  },
}

/** Sicherheits-Mechaniken, die Tore öffnen können. */
export const GATE_OPENER_TYPES = Object.entries(OBJECT_TYPES)
  .filter(([, def]) => def.opensGate)
  .map(([type]) => type)

/** Noch nicht spielbare Module (Stubs) — im Baukasten GESPERRT. */
export const FORBIDDEN_TYPES: Record<string, string> = {
  'pruef-scanner': 'Ausbaustufe — noch nicht spielbar (Stub). Nutze timing-gate oder stillstand-podest.',
  'rechte-tueren': 'Ausbaustufe — noch nicht spielbar (Stub).',
  'finale-sprint': 'Ausbaustufe — noch nicht spielbar (Stub). Nutze stamp-exit oder Tür-Ausgang (D).',
  vervollstaendigen: 'Ausbaustufe (Stub). Sammelziel geht heute so: Datenbits (o) + collectible.countRequired + Tür (D).',
  'tube-scroll': 'tube-scroll ist KEIN Objekt — Tempo gehört als mechanics["tube-scroll"].speed ins level.json.',
  spawn: 'spawn wird als Marker "P" im layout.txt gesetzt, nicht im objects-Array.',
  collectible: 'Datenbits werden als Marker "o" im layout.txt gesetzt, nicht im objects-Array.',
  checkpoint: 'Checkpoints werden als Marker "C" im layout.txt gesetzt, nicht im objects-Array.',
  'door-exit': 'Der Tür-Ausgang wird als Marker "D" im layout.txt gesetzt, nicht im objects-Array.',
}

// ------------------------------------------------- mechanics-Abschnitt (level.json)

/** Erlaubte Parameter je mechanics-Abschnitt — strikt, Texte immer {de, en?}. */
export const MECHANICS_SCHEMAS: Record<string, z.ZodType<Record<string, unknown>>> = {
  'timing-gate': z.strictObject({
    steps: z.number().int().min(2).max(8).optional(),
    stepMs: z.number().min(300).max(3000).optional(),
    hint: LTextSchema.optional(),
    failHint: LTextSchema.optional(),
    gateHint: LTextSchema.optional(),
  }),
  'stamp-exit': z.strictObject({
    hint: LTextSchema.optional(),
    failHint: LTextSchema.optional(),
  }),
  'stillstand-podest': z.strictObject({
    scanMs: z.number().min(400).max(4000).optional(),
    hint: LTextSchema.optional(),
    stillHint: LTextSchema.optional(),
    gateHint: LTextSchema.optional(),
    denyText: LTextSchema.optional(),
  }),
  'krypto-dusche': z.strictObject({
    hint: LTextSchema.optional(),
    gateHint: LTextSchema.optional(),
  }),
  'deny-enemy': z.strictObject({
    grabsBeforeBlock: z.number().int().min(1).max(5).optional(),
    reach: z.number().min(8).max(120).optional(),
    idleMs: z.number().min(400).max(4000).optional(),
    activationRange: z.number().min(60).max(600).optional(),
    denyText: LTextSchema.optional(),
    duckHint: LTextSchema.optional(),
  }),
  'tube-scroll': z.strictObject({
    speed: z.number().min(30).max(90).optional(),
  }),
  gate: z.strictObject({
    bumpHint: LTextSchema.optional(),
  }),
  'info-sign': z.strictObject({
    text: LTextSchema.optional(),
  }),
  'moving-platform': z.strictObject({
    range: z.number().min(16).max(200).optional(),
    speed: z.number().min(10).max(120).optional(),
  }),
}

// ------------------------------------------------------------------ Level-Metadaten

/** Kameramodi, die heute wirklich spielbar sind (Rest = Ausbaustufe). */
export const PLAYABLE_CAMERA_MODES = ['horizontal', 'tube'] as const

/** Siegel mit eigener Grafik; alles andere fällt im Spiel auf seal-generic zurück. */
export const KNOWN_SEAL_ICONS = ['seal-vsdm', 'seal-egk', 'seal-vpn', 'seal-generic']

/** Sprites/Animationen, die deco benutzen darf (prozedural erzeugt, TextureFactory). */
export const KNOWN_DECO_SPRITES = ['krake-0', 'krake-1', 'kralle-open', 'kralle-closed']
export const KNOWN_DECO_ANIMS = ['krake-swim']

/** Gegner-Skins laut Konzept (rein kosmetische Kennung, Freitext erlaubt). */
export const KNOWN_ENEMY_SKINS = [
  'skimming-kralle',
  'datenkrake',
  'lauscher-auge',
  'manipulator-bot',
  'neugier-geist',
  'glitch-gremlin',
]

/** design/levels/<id>/level.json — wie das Laufzeit-Schema, aber ohne id/tilemap, plus objects[]. */
export const DesignLevelSchema = z.strictObject({
  station: z.strictObject({
    name: LTextSchema,
    portalText: LTextSchema,
    reziText: LTextSchema,
    stampText: LTextSchema,
    badge: z.string(),
  }),
  siegelIcon: z.string(),
  cityAnchor: z.strictObject({
    facade: z.string(),
    label: LTextSchema,
  }),
  cameraMode: z.enum(PLAYABLE_CAMERA_MODES, {
    errorMap: () => ({
      message: `Im Baukasten erlaubt: ${PLAYABLE_CAMERA_MODES.join(', ')} (vertical/chamber/sprint sind Ausbaustufe)`,
    }),
  }),
  theme: z.string(),
  enemySkin: z.string(),
  collectible: z.strictObject({
    type: z.literal('datenbit'),
    countRequired: z.number().int().min(0).max(40),
    label: LTextSchema,
  }),
  mechanics: z.record(z.record(z.unknown())).default({}),
  parTimeSeconds: z.number().min(10).max(120),
  stuckHint: LTextSchema.optional(),
  objects: z.array(z.record(z.unknown())).default([]),
})

export type DesignLevel = z.infer<typeof DesignLevelSchema>

/** Level-IDs: zweistellige Nummer + Kleinbuchstaben-Name, z. B. "04-fachdienst". */
export const LEVEL_ID_PATTERN = /^[0-9]{2}-[a-z0-9-]+$/

// ------------------------------------------------------------------ Helfer

/** Levenshtein-Distanz für „Meintest du …?"-Vorschläge. */
export function editDistance(a: string, b: string): number {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array<number>(b.length).fill(0)])
  for (let j = 0; j <= b.length; j++) dp[0][j] = j
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      )
    }
  }
  return dp[a.length][b.length]
}

/** Nächstliegender bekannter Begriff (nur wenn plausibel nah). */
export function suggest(unknown: string, known: string[]): string {
  let best = ''
  let bestDist = Infinity
  for (const k of known) {
    const d = editDistance(unknown.toLowerCase(), k.toLowerCase())
    if (d < bestDist) {
      bestDist = d
      best = k
    }
  }
  return bestDist <= Math.max(2, Math.floor(unknown.length / 3)) ? ` — meintest du "${best}"?` : ''
}
