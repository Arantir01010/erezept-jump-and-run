import { z } from 'zod'

/**
 * Single Source of Truth für alle datengetriebenen Konfigurationen.
 * Diese Datei ist bewusst Phaser-frei, damit tools/validate-levels.ts sie
 * unter Node (tsx) ohne Browser-Umgebung nutzen kann.
 */

export const LTextSchema = z.object({
  de: z.string().min(1),
  en: z.string().optional(),
})

export const CameraModeSchema = z.enum(['horizontal', 'vertical', 'tube', 'chamber', 'sprint'])

export const LevelSchema = z.object({
  id: z.string().regex(/^[a-z0-9-]+$/, 'Level-IDs: nur Kleinbuchstaben, Ziffern, Bindestriche'),
  station: z.object({
    name: LTextSchema,
    portalText: LTextSchema,
    reziText: LTextSchema,
    stampText: LTextSchema,
    badge: z.string(),
  }),
  siegelIcon: z.string(),
  cityAnchor: z.object({
    facade: z.string(),
    label: LTextSchema,
  }),
  cameraMode: CameraModeSchema,
  theme: z.string(),
  enemySkin: z.string(),
  tilemap: z.string().endsWith('.tmj'),
  collectible: z.object({
    type: z.string(),
    countRequired: z.number().int().min(0),
    label: LTextSchema,
  }),
  mechanics: z.record(z.record(z.unknown())).default({}),
  /**
   * Hülle-Kernmechanik (KAPSEL 2.1). Fehlt der Block, ist sie im Level aus —
   * die drei Messe-Level bleiben damit unverändert spielbar.
   */
  huelle: z
    .object({
      enabled: z.boolean().default(false),
      start: z.enum(['klartext', 'verschluesselt']).default('klartext'),
      toggleCooldownMs: z.number().min(0).max(1000).default(150),
    })
    .default({ enabled: false, start: 'klartext', toggleCooldownMs: 150 }),
  parTimeSeconds: z.number().positive(),
  /** Optionaler Generaltipp bei Festhängen (Default nennt die Grundsteuerung). */
  stuckHint: LTextSchema.optional(),
})

export const GameConfigSchema = z.object({
  event: z.string(),
  language: z.enum(['de', 'en']).default('de'),
  titleScreen: z.object({
    headline: LTextSchema,
    subline: LTextSchema,
    pressStart: LTextSchema,
    pressStartKeyboard: LTextSchema.default({ de: 'Drück LEERTASTE!', en: 'Press SPACE!' }),
  }),
  levelOrder: z.array(z.string()).min(1),
  ending: z.object({
    type: z.enum(['static', 'generated']),
    staticPayload: z.string().default('EREZEPT-GEWINN'),
    rewardScreenSeconds: z.number().positive().default(45),
    minQrSeconds: z.number().positive().default(10),
  }),
  /**
   * Rechtlicher Hinweis (KAPSEL 4.5). Muss die Unabhängigkeit von der gematik
   * aussprechen — src/legal.ts prüft das, tools/test/recht.test.ts erzwingt es.
   */
  disclaimer: LTextSchema.default({
    de: 'Inoffizielles Lernspiel — kein Produkt der gematik. Dient der Wissensvermittlung.',
    en: 'Unofficial educational game — not a gematik product. For knowledge transfer only.',
  }),
  /** Telemetrie (KAPSEL 4.4): im Playtest an, im reinen Messebetrieb abschaltbar. */
  telemetrie: z.boolean().default(true),
  /** Synthetisierte Spielklänge (src/audio/klang.ts) — laute Messestände: false. */
  audio: z.boolean().default(true),
  idleResetSeconds: z.number().positive().default(60),
  softAutopilotSeconds: z.number().positive().default(240),
})

/**
 * TI-Zone einer Farbwelt — erscheint als Umgebungstext im Hintergrund.
 * Wissensvermittlung im Vorbeigehen (KAPSEL 2.6): Der Spieler liest die echte
 * Zonen-Gliederung der TI aus der Kulisse, nicht aus einer Textwand.
 */
export const ZoneSchema = z.object({
  name: LTextSchema,
  fakt: LTextSchema.optional(),
})

export const ThemeSchema = z.object({
  skyTop: z.string(),
  skyBottom: z.string(),
  ground: z.string(),
  groundTop: z.string(),
  accent: z.string(),
  detail: z.string(),
  /**
   * Silhouetten-Motiv des Hintergrunds (Default: stadt). Die Kulisse erzählt
   * die echte TI-Reise: Praxis → Netz → Rechenzentrum → Aktenarchiv.
   */
  motiv: z.enum(['stadt', 'praxis', 'netz', 'rechenzentrum', 'archiv']).optional(),
  /** Echte TI-Zone dieser Farbwelt (siehe ZoneSchema). */
  zone: ZoneSchema.optional(),
})

export const ThemesSchema = z.record(ThemeSchema)

export const BindingsSchema = z.object({
  gamepad: z.object({
    axisDeadzone: z.number().min(0).max(0.9).default(0.4),
    jumpButtons: z.array(z.number().int().min(0)),
    actionButtons: z.array(z.number().int().min(0)),
    /** Optionaler dritter Button (falls die Hardware einen hat). */
    toggleButtons: z.array(z.number().int().min(0)).default([]),
    /** Joystick HOCH schaltet die Hülle — Standard auf 2-Button-Hardware. */
    toggleOnUp: z.boolean().default(true),
    useDpad: z.boolean().default(true),
  }),
  keyboard: z.object({
    left: z.array(z.string()),
    right: z.array(z.string()),
    up: z.array(z.string()),
    down: z.array(z.string()),
    jump: z.array(z.string()),
    action: z.array(z.string()),
    /** Hülle wechseln — Default Shift/Q (Messe: Joystick hoch). */
    toggle: z.array(z.string()).default(['SHIFT', 'Q']),
  }),
})

export type LevelConfig = z.infer<typeof LevelSchema>
export type GameConfig = z.infer<typeof GameConfigSchema>
export type Theme = z.infer<typeof ThemeSchema>
export type Themes = z.infer<typeof ThemesSchema>
export type Bindings = z.infer<typeof BindingsSchema>
export type CameraMode = z.infer<typeof CameraModeSchema>

/** Formatiert einen zod-Fehler menschenlesbar (für Redakteure). */
export function formatZodError(file: string, error: z.ZodError): string {
  const lines = error.issues.map((i) => `  • ${i.path.join('.') || '(Wurzel)'}: ${i.message}`)
  return `Konfigurationsfehler in ${file}:\n${lines.join('\n')}`
}
