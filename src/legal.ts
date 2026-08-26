/**
 * RECHT & MARKE (KAPSEL 4.5) — als prüfbarer Code, nicht als Merkzettel.
 *
 * Ausgangslage laut KAPSEL: „E-Rezept" ist eine Produktmarke der gematik.
 * Unveränderte Nutzung zur Aufklärung ist ohne Genehmigung erlaubt; eine
 * VERÄNDERUNG oder Nachahmung (z. B. Form oder Farben) ist nicht gestattet,
 * werbliche Nutzung nur mit schriftlicher Genehmigung. Logos dürfen nicht ins
 * Branding.
 *
 * Daraus folgen drei Dinge, die dieses Modul durchsetzbar macht:
 *   1. Der Disclaimer „inoffiziell / kein Produkt der gematik" muss sichtbar
 *      sein — auf dem Startbildschirm UND auf dem Endscreen.
 *   2. Marken müssen unverändert geschrieben werden. Varianten wie „eRezept"
 *      oder „E Rezept" sind Veränderungen und damit riskant.
 *   3. Es dürfen keine Binär-Assets ins Repo, die ein Logo sein könnten.
 *
 * Phaser-frei → unter Node testbar (tools/test/recht.test.ts).
 */

/** Geschützte bzw. markenrechtlich sensible Begriffe (KAPSEL 4.5). */
export const GESCHUETZTE_MARKEN = ['E-Rezept', 'gematik', 'GesundheitsID'] as const

/**
 * Korrekte Schreibweisen und ihre riskanten Varianten.
 * Links die unveränderte Marke, rechts Schreibweisen, die als Veränderung
 * gelesen werden könnten.
 */
export const MARKEN_VARIANTEN: Record<string, string[]> = {
  'E-Rezept': ['eRezept', 'E Rezept', 'ERezept', 'e_rezept', 'E-REZEPT'],
  gematik: ['Gematik', 'GEMATIK'],
  GesundheitsID: ['Gesundheits-ID', 'Gesundheits ID'],
}

/** Begriffe, die ein tragfähiger Disclaimer enthalten muss. */
export const DISCLAIMER_PFLICHT = ['kein Produkt der gematik']

/**
 * Nennt der Text die Unabhängigkeit von der gematik klar?
 * Bewusst streng: Ein „inoffiziell" allein genügt nicht — es muss ausgesprochen
 * werden, dass es kein gematik-Produkt ist.
 */
export function nenntUnabhaengigkeit(text: string): boolean {
  const t = text.toLowerCase()
  return DISCLAIMER_PFLICHT.every((pflicht) => t.includes(pflicht.toLowerCase()))
}

/** Welche geschützten Marken kommen im Text vor (korrekt geschrieben)? */
export function findeMarken(text: string): string[] {
  return GESCHUETZTE_MARKEN.filter((m) => text.includes(m))
}

/**
 * Riskante Marken-Varianten im Text finden (Veränderung der Marke).
 * Liefert Paare „gefundene Variante → korrekte Schreibweise".
 */
export function findeMarkenVarianten(text: string): { gefunden: string; korrekt: string }[] {
  const treffer: { gefunden: string; korrekt: string }[] = []
  for (const [korrekt, varianten] of Object.entries(MARKEN_VARIANTEN)) {
    for (const v of varianten) {
      if (text.includes(v)) treffer.push({ gefunden: v, korrekt })
    }
  }
  return treffer
}

/**
 * Ist der Text markenrechtlich unbedenklich?
 * Kriterium: keine veränderte Schreibweise einer geschützten Marke.
 */
export function markenSchreibweiseOk(text: string): boolean {
  return findeMarkenVarianten(text).length === 0
}
