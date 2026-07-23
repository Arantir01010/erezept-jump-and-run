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
  idleResetSeconds: z.number().positive().default(60),
  softAutopilotSeconds: z.number().positive().default(240),
})

export const ThemeSchema = z.object({
  skyTop: z.string(),
  skyBottom: z.string(),
  ground: z.string(),
  groundTop: z.string(),
  accent: z.string(),
  detail: z.string(),
})

export const ThemesSchema = z.record(ThemeSchema)

export const BindingsSchema = z.object({
  gamepad: z.object({
    axisDeadzone: z.number().min(0).max(0.9).default(0.4),
    jumpButtons: z.array(z.number().int().min(0)),
    actionButtons: z.array(z.number().int().min(0)),
    useDpad: z.boolean().default(true),
  }),
  keyboard: z.object({
    left: z.array(z.string()),
    right: z.array(z.string()),
    up: z.array(z.string()),
    down: z.array(z.string()),
    jump: z.array(z.string()),
    action: z.array(z.string()),
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
