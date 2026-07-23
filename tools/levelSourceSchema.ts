import { z } from 'zod'
import { LTextSchema } from '../src/level/schema'

/**
 * Quellformat des Level-Baukastens (levels-src/<id>.level.json).
 *
 * Dieses Format ist die EINZIGE Schnittstelle, über die neue Level entstehen —
 * bewusst so einfach, dass auch schwache KI-Modelle es fehlerfrei schreiben
 * können: Metadaten als flaches JSON, die Geometrie als ASCII-Bild.
 * Der Compiler (tools/compile-levels.ts) erzeugt daraus die Runtime-Dateien
 * und lehnt alles ab, was nicht spielbar wäre.
 */

export const MAP_HEIGHT = 23 // Kachelzeilen — exakt eine Bildschirmhöhe (23 × 16 px)
export const MAP_MIN_WIDTH = 40
export const MAP_MAX_WIDTH = 220

/** Alle erlaubten Zeichen der ASCII-Karte (Legende siehe levels-src/ANLEITUNG.md). */
export const TERRAIN_CHARS = ['#', '=', 'G', 'A', '~', '-', '|', '.', ' '] as const
export const OBJECT_CHARS = ['P', 'b', 'c', 'i', 'K', 'x', 'M', 'H', 'p', 't', 'Q', 'S', 'D', '1', '2', '3', '4'] as const
export const ALL_CHARS = [...TERRAIN_CHARS, ...OBJECT_CHARS] as const

export const LevelSourceSchema = z.object({
  id: z
    .string()
    .regex(/^[a-z0-9-]+$/, 'Level-IDs: nur Kleinbuchstaben, Ziffern, Bindestriche (z. B. "04-fachdienst")'),
  station: z.object({
    name: LTextSchema,
    portalText: LTextSchema,
    reziText: LTextSchema,
    stampText: LTextSchema,
    badge: z.string().min(1),
  }),
  siegelIcon: z.string().default('seal-generic'),
  cityAnchor: z.object({
    facade: z.string().default('generic'),
    label: LTextSchema,
  }),
  cameraMode: z.enum(['horizontal', 'tube']).default('horizontal'),
  theme: z.string().min(1),
  enemySkin: z.string().default('skimming-kralle'),
  /** Wie viele Datenbits die Ausgangstür verlangt (0 = Tür immer offen). */
  collectibleCountRequired: z.number().int().min(0).default(0),
  parTimeSeconds: z.number().positive().default(30),
  /** Optionale Feineinstellungen je Mechanik-Typ (stepMs, scanMs, hint, …). */
  mechanics: z.record(z.record(z.unknown())).default({}),
  /** Texte der Info-Schilder (i) — Reihenfolge: von links nach rechts. */
  infoSchilder: z.array(LTextSchema).default([]),
  /** Die Karte: 23 Zeilen ASCII, alle gleich lang. Legende: ANLEITUNG.md. */
  map: z
    .array(z.string())
    .length(MAP_HEIGHT, `Die Karte braucht exakt ${MAP_HEIGHT} Zeilen (eine Bildschirmhöhe)`),
})

export type LevelSource = z.infer<typeof LevelSourceSchema>
