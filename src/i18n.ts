/** Lokalisierte Texte: DE ist Pflicht, EN optional (wird nach Prototyp-Freigabe gefüllt). */
export interface LText {
  de: string
  en?: string
}

export type Lang = 'de' | 'en'

let currentLang: Lang = 'de'

export function setLang(lang: Lang): void {
  currentLang = lang
}

export function getLang(): Lang {
  return currentLang
}

/** Liefert den Text in der aktiven Sprache, fällt immer auf DE zurück. */
export function t(text: LText): string {
  return currentLang === 'en' && text.en ? text.en : text.de
}
