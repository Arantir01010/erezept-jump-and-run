/**
 * RECHT & MARKE + ZUGRIFFSPROTOKOLL (KAPSEL 4.5 und 2.7/3.2).
 *
 * Warum als Test und nicht als Merkzettel? Der Markenleitfaden verbietet die
 * VERÄNDERUNG der Marke „E-Rezept" (auch Form/Farbe). Eine Schreibweise wie
 * „eRezept" rutscht beim Tippen durch und wäre genau so eine Veränderung.
 * Diese Suite prüft deshalb alle sichtbaren Texte des Spiels — Configs, Level,
 * README — und den Pflicht-Disclaimer.
 */
import { suite, test, assertTrue, assertFalse, assertEqual, assertSome } from './harness'
import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  nenntUnabhaengigkeit,
  findeMarken,
  findeMarkenVarianten,
  markenSchreibweiseOk,
  GESCHUETZTE_MARKEN,
  MARKEN_VARIANTEN,
} from '../../src/legal'
import { Protokoll } from '../../src/state/Protokoll'
import { bildeBilanz, formatZeile, formatSumme } from '../../src/state/siegelReport'
import { GameConfigSchema } from '../../src/level/schema'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const lies = (rel: string): string => readFileSync(join(ROOT, rel), 'utf-8')

/** Alle spielerseitig sichtbaren Texte einsammeln (Configs + Level). */
function alleSpieltexte(): { quelle: string; text: string }[] {
  const out: { quelle: string; text: string }[] = []
  out.push({ quelle: 'game-config.json', text: lies('public/config/game-config.json') })
  const dir = join(ROOT, 'design', 'levels')
  for (const eintrag of readdirSync(dir, { withFileTypes: true })) {
    if (!eintrag.isDirectory()) continue
    const datei = join(dir, eintrag.name, 'level.json')
    if (existsSync(datei)) {
      out.push({ quelle: `design/levels/${eintrag.name}/level.json`, text: readFileSync(datei, 'utf-8') })
    }
  }
  return out
}

export function run(): void {
  suite('Recht — Disclaimer ist Pflicht', () => {
    const cfgRaw = JSON.parse(lies('public/config/game-config.json')) as Record<string, unknown>

    test('game-config.json enthält einen Disclaimer', () => {
      assertTrue(cfgRaw.disclaimer !== undefined, 'disclaimer fehlt in der Config')
    })

    test('der Disclaimer nennt die Unabhängigkeit von der gematik', () => {
      const d = cfgRaw.disclaimer as { de?: string }
      assertTrue(
        nenntUnabhaengigkeit(d.de ?? ''),
        'Der Text muss aussprechen, dass es kein Produkt der gematik ist',
      )
    })

    test('das Schema setzt notfalls einen Default (kein Level ohne Hinweis)', () => {
      const ohne = { ...cfgRaw }
      delete ohne.disclaimer
      const r = GameConfigSchema.safeParse(ohne)
      assertTrue(r.success, 'Config ohne Disclaimer muss trotzdem laden')
      if (r.success) {
        assertTrue(nenntUnabhaengigkeit(r.data.disclaimer.de), 'Default muss tragfähig sein')
      }
    })

    test('„inoffiziell" allein genügt nicht', () => {
      assertFalse(nenntUnabhaengigkeit('Ein inoffizielles Spiel.'), 'zu schwach formuliert')
      assertTrue(nenntUnabhaengigkeit('Inoffiziell — kein Produkt der gematik.'))
    })

    test('der Hinweis erscheint auf dem Startbildschirm', () => {
      assertTrue(lies('src/scenes/AttractScene.ts').includes('cfg.disclaimer'), 'Attract zeigt ihn nicht')
    })

    test('der Hinweis erscheint auf dem Endscreen (der wird abfotografiert)', () => {
      assertTrue(lies('src/scenes/RewardScene.ts').includes('cfg.disclaimer'), 'Reward zeigt ihn nicht')
    })
  })

  suite('Recht — Marken werden unverändert geschrieben', () => {
    test('die Erkennung findet korrekte Marken', () => {
      assertEqual(findeMarken('Das E-Rezept der gematik').length, 2)
    })

    test('veränderte Schreibweisen werden erkannt', () => {
      const t = findeMarkenVarianten('Hol dir dein eRezept!')
      assertEqual(t.length, 1)
      assertEqual(t[0].korrekt, 'E-Rezept', 'Meldung nennt die richtige Form')
    })

    test('jede geschützte Marke hat eine Variantenliste', () => {
      for (const m of GESCHUETZTE_MARKEN) {
        assertTrue((MARKEN_VARIANTEN[m] ?? []).length > 0, `${m} ohne Variantenprüfung`)
      }
    })

    test('ALLE Spieltexte halten die Schreibweisen ein', () => {
      for (const { quelle, text } of alleSpieltexte()) {
        const treffer = findeMarkenVarianten(text)
        assertTrue(
          treffer.length === 0,
          `${quelle}: ${treffer.map((t) => `"${t.gefunden}" → "${t.korrekt}"`).join(', ')}`,
        )
      }
    })

    test('README und Levelbau-Doku ebenfalls', () => {
      for (const datei of ['README.md', 'design/LEVELBAU.md']) {
        assertTrue(markenSchreibweiseOk(lies(datei)), `${datei} verändert eine Marke`)
      }
    })

    test('keine Binär-Assets im Repo (Logo-Risiko)', () => {
      // Alle Grafiken werden prozedural erzeugt. Taucht hier eine PNG auf, ist
      // das ein Hinweis auf ein eingeschlepptes Logo — bewusst hart geprüft.
      const dir = join(ROOT, 'public', 'assets')
      const suche = (p: string): string[] => {
        if (!existsSync(p)) return []
        return readdirSync(p, { withFileTypes: true }).flatMap((e) =>
          e.isDirectory() ? suche(join(p, e.name)) : e.name.match(/\.(png|jpg|jpeg|svg|gif|webp)$/i) ? [e.name] : [],
        )
      }
      const bilder = suche(dir)
      assertEqual(bilder.length, 0, `Bilddateien gefunden: ${bilder.join(', ')}`)
    })
  })

  suite('Zugriffsprotokoll — Bilanz für den Endscreen', () => {
    const bilanzMit = (opts: { gesehen?: boolean; bits?: number }) => {
      const p = new Protokoll()
      p.markAbgeschlossen('01-a', 10)
      if (opts.gesehen) p.markGesehen('01-a', 5)
      return bildeBilanz(p, [{ levelId: '01-a', name: 'VSDM', bits: opts.bits ?? 3, bitsRequired: 3 }])
    }

    test('perfekter Durchlauf: drei von drei Siegeln', () => {
      const b = bilanzMit({})
      assertEqual(b.siegelErreicht, 3)
      assertEqual(b.siegelMoeglich, 3)
      assertTrue(b.lueckenlos)
    })

    test('gesehen worden kostet genau ein Siegel', () => {
      const b = bilanzMit({ gesehen: true })
      assertEqual(b.siegelErreicht, 2)
      assertFalse(b.lueckenlos)
    })

    test('Prüfsummen verpasst kostet genau ein Siegel (kein Alles-oder-nichts)', () => {
      const b = bilanzMit({ bits: 1 })
      assertEqual(b.siegelErreicht, 2, 'durchgespielt + lückenlos bleiben erreichbar')
      assertTrue(b.zeilen[0].siegel.lueckenlosesProtokoll, 'unabhängig vom Sammeln')
    })

    test('leere Bilanz stürzt nicht ab', () => {
      const b = bildeBilanz(new Protokoll(), [])
      assertEqual(b.siegelErreicht, 0)
      assertEqual(b.siegelMoeglich, 0)
    })

    test('mehrere Stationen werden aufsummiert', () => {
      const p = new Protokoll()
      p.markAbgeschlossen('01-a', 1)
      p.markAbgeschlossen('02-b', 2)
      p.markGesehen('02-b', 3)
      const b = bildeBilanz(p, [
        { levelId: '01-a', name: 'A', bits: 3, bitsRequired: 3 },
        { levelId: '02-b', name: 'B', bits: 0, bitsRequired: 3 },
      ])
      assertEqual(b.siegelMoeglich, 6)
      assertEqual(b.siegelErreicht, 4, '3 + 1')
    })

    test('die Anzeige nutzt Symbole, nicht nur Farbe (Barrierefreiheit)', () => {
      const b = bilanzMit({})
      const zeile = formatZeile(b.zeilen[0])
      assertTrue(zeile.includes('●'), 'gefüllte Marke fehlt')
      assertTrue(zeile.startsWith('VSDM'), 'Stationsname fehlt')
      const teil = formatZeile(bilanzMit({ gesehen: true }).zeilen[0])
      assertTrue(teil.includes('○'), 'offene Marke fehlt')
    })

    test('die Summenzeile lobt das lückenlose Protokoll', () => {
      assertSome([formatSumme(bilanzMit({}))], 'Lückenloses Protokoll')
      assertFalse(formatSumme(bilanzMit({ gesehen: true })).includes('Lückenloses'), 'darf nicht gelobt werden')
    })
  })
}
