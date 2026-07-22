import {
  GameConfigSchema,
  ThemesSchema,
  BindingsSchema,
  LevelSchema,
  formatZodError,
  type GameConfig,
  type Themes,
  type Bindings,
  type LevelConfig,
  type Theme,
} from './schema'
import { setLang } from '../i18n'

/**
 * Lädt und validiert alle JSON-Konfigurationen aus public/config/.
 * Redakteure können diese Dateien ohne Rebuild austauschen —
 * Fehler werden hier mit lesbarer Meldung abgefangen.
 */
class ConfigService {
  gameConfig!: GameConfig
  themes!: Themes
  bindings!: Bindings
  levels: LevelConfig[] = []

  private async fetchJson(path: string): Promise<unknown> {
    const url = `${import.meta.env.BASE_URL}${path}`
    const res = await fetch(url)
    if (!res.ok) throw new Error(`Konnte ${path} nicht laden (HTTP ${res.status})`)
    try {
      return await res.json()
    } catch {
      throw new Error(`${path} ist kein gültiges JSON`)
    }
  }

  async load(): Promise<void> {
    const [gameRaw, themesRaw, bindingsRaw] = await Promise.all([
      this.fetchJson('config/game-config.json'),
      this.fetchJson('config/themes.json'),
      this.fetchJson('config/input-bindings.json'),
    ])

    const game = GameConfigSchema.safeParse(gameRaw)
    if (!game.success) throw new Error(formatZodError('config/game-config.json', game.error))
    this.gameConfig = game.data

    const themes = ThemesSchema.safeParse(themesRaw)
    if (!themes.success) throw new Error(formatZodError('config/themes.json', themes.error))
    this.themes = themes.data

    const bindings = BindingsSchema.safeParse(bindingsRaw)
    if (!bindings.success) throw new Error(formatZodError('config/input-bindings.json', bindings.error))
    this.bindings = bindings.data

    setLang(this.gameConfig.language)

    this.levels = []
    for (const id of this.gameConfig.levelOrder) {
      const raw = await this.fetchJson(`config/levels/${id}.json`)
      const parsed = LevelSchema.safeParse(raw)
      if (!parsed.success) throw new Error(formatZodError(`config/levels/${id}.json`, parsed.error))
      if (parsed.data.id !== id) {
        throw new Error(`config/levels/${id}.json: Feld "id" (${parsed.data.id}) muss dem Dateinamen entsprechen`)
      }
      if (!this.themes[parsed.data.theme]) {
        throw new Error(`config/levels/${id}.json: Theme "${parsed.data.theme}" fehlt in config/themes.json`)
      }
      this.levels.push(parsed.data)
    }
  }

  theme(key: string): Theme {
    const theme = this.themes[key]
    if (!theme) throw new Error(`Unbekanntes Theme: ${key}`)
    return theme
  }

  level(index: number): LevelConfig {
    const level = this.levels[index]
    if (!level) throw new Error(`Level-Index ${index} außerhalb der Playlist`)
    return level
  }
}

export const configService = new ConfigService()
