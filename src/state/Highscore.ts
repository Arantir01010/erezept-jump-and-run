/**
 * Tages-Highscore: localStorage mit Tages-Wipe, kein Personenbezug —
 * statt Namen wählen Spieler eines von 12 Pixel-Avatar-Icons.
 */

export interface HighscoreEntry {
  avatar: number // Index 0..11
  score: number
}

const KEY = 'erezept-highscore'
const MAX_ENTRIES = 5

interface Stored {
  day: string
  entries: HighscoreEntry[]
}

function today(): string {
  return new Date().toISOString().slice(0, 10)
}

function loadStored(): Stored {
  try {
    const raw = localStorage.getItem(KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as Stored
      if (parsed.day === today() && Array.isArray(parsed.entries)) return parsed
    }
  } catch {
    // korrupter Eintrag → Tages-Wipe
  }
  return { day: today(), entries: [] }
}

export function getHighscores(): HighscoreEntry[] {
  return loadStored().entries
}

/** true, wenn der Score in die Tages-Top-5 kommt. */
export function qualifies(score: number): boolean {
  if (score <= 0) return false
  const entries = loadStored().entries
  return entries.length < MAX_ENTRIES || entries.some((e) => score > e.score)
}

export function addHighscore(entry: HighscoreEntry): void {
  const stored = loadStored()
  stored.entries.push(entry)
  stored.entries.sort((a, b) => b.score - a.score)
  stored.entries = stored.entries.slice(0, MAX_ENTRIES)
  try {
    localStorage.setItem(KEY, JSON.stringify(stored))
  } catch {
    // localStorage voll/gesperrt → Highscore ist verzichtbar, Spiel läuft weiter
  }
}
