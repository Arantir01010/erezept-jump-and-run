/**
 * VERDRAHTUNGS-TEST — prüft die Verbindungen, die kein Unit-Test sieht.
 *
 * Die Hülle besteht aus vielen kleinen, einzeln getesteten Teilen. Was dabei
 * kaputtgehen kann, ist die VERBINDUNG: Die Szene liest die Level-Einstellung
 * nicht, das HUD fragt den falschen Spieler, der Toggle wird nie abgefragt.
 * Solche Fehler sieht man erst im Browser — oder hier.
 *
 * Der Test liest die Quelldateien und prüft, dass die tragenden Verbindungen
 * vorhanden sind. Bewusst textbasiert: Ein echter Phaser-Lauf bräuchte WebGL.
 * Jede Prüfung nennt die Stelle, damit ein Fehlschlag sofort auffindbar ist.
 */
import { suite, test, assertTrue, assertFalse } from './harness'
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const lies = (rel: string): string => readFileSync(join(ROOT, rel), 'utf-8')

export function run(): void {
  suite('Verdrahtung — GameScene', () => {
    const scene = lies('src/scenes/GameScene.ts')

    test('liest huelle.enabled aus dem Level (nicht hart verdrahtet)', () => {
      assertTrue(scene.includes('this.level.huelle'), 'Level-Einstellung wird nicht gelesen')
      assertTrue(scene.includes('huelleEnabled = huelleCfg.enabled'), 'Schalter kommt nicht am Spieler an')
    })

    test('setzt den Startzustand aus dem Level', () => {
      assertTrue(scene.includes("huelleCfg.start === 'verschluesselt'"), 'start wird ignoriert')
      assertTrue(scene.includes('huelle.reset('), 'Zustand wird nicht initialisiert')
    })

    test('übernimmt die Abklingzeit aus dem Level', () => {
      assertTrue(scene.includes('toggleCooldownMs = huelleCfg.toggleCooldownMs'))
    })

    test('fragt den Toggle jeden Frame ab', () => {
      assertTrue(scene.includes('justPressed(GameAction.Toggle)'), 'Toggle wird nie abgefragt')
      assertTrue(scene.includes('tryToggleHuelle()'), 'Umschalten wird nicht ausgelöst')
    })

    test('lässt die Sitzungsuhr laufen (sonst läuft die VAU nie ab)', () => {
      assertTrue(scene.includes('tickHuelle(delta)'), 'tickHuelle fehlt im update')
    })

    test('Hülle wird VOR der Spielerlogik aktualisiert', () => {
      const iTick = scene.indexOf('tickHuelle(delta)')
      const iUpdate = scene.indexOf('this.player.update()')
      assertTrue(iTick > 0 && iUpdate > 0, 'Aufrufe nicht gefunden')
      assertTrue(iTick < iUpdate, 'Sitzungsablauf muss im gleichen Frame wirken')
    })

    test('nach Levelende wird nicht mehr umgeschaltet', () => {
      assertTrue(scene.includes('!this.completed'), 'Toggle im Abschluss-Setpiece nicht gesperrt')
    })

    test('trägt den Levelabschluss ins Protokoll ein', () => {
      assertTrue(scene.includes('protokoll.markAbgeschlossen'), 'ohne Eintrag gibt es keine Siegel')
    })

    test('HUD wird bei jedem Zustandswechsel benachrichtigt', () => {
      assertTrue(scene.includes("huelle.onChange"), 'HUD erfährt nichts von Wechseln')
    })
  })

  suite('Verdrahtung — HUD (UIScene)', () => {
    const ui = lies('src/scenes/UIScene.ts')

    test('nutzt die getestete Badge-Zuordnung statt eigener Farben', () => {
      assertTrue(ui.includes("from '../gfx/huelleBadge'"), 'HUD malt eigene Farben')
      assertTrue(ui.includes('badgeSpec('), 'Zuordnung wird nicht benutzt')
    })

    test('zeigt Form UND Text (nicht nur Farbe)', () => {
      assertTrue(ui.includes('badgePoints('), 'Form fehlt')
      assertTrue(ui.includes('spec.label'), 'Text fehlt')
    })

    test('blendet das Badge in Leveln ohne Hülle aus', () => {
      assertTrue(ui.includes('huelleEnabled'), 'Sichtbarkeit nicht an die Mechanik gekoppelt')
      assertTrue(ui.includes('setVisible(false)'), 'wird nie ausgeblendet')
    })

    test('aktualisiert sich pro Frame UND bei hud:update', () => {
      const treffer = ui.split('refreshHuelle()').length - 1
      assertTrue(treffer >= 3, `refreshHuelle nur ${treffer}x verwendet (Definition + refresh + update)`)
    })

    test('nennt die Umschalt-Taste passend zur Hardware', () => {
      assertTrue(ui.includes('toggleHinweis('), 'Hinweis fehlt — Besucher sucht den dritten Knopf')
      assertTrue(ui.includes('inputManager.hasGamepad()'), 'Hardware wird nicht erkannt')
    })
  })

  suite('Verdrahtung — Spieler', () => {
    const player = lies('src/player/Player.ts')

    test('Tempo hängt an der Hülle', () => {
      assertTrue(player.includes('huelle.speedFactor'), 'Hülle wirkt nicht aufs Tempo')
    })

    test('Sprungkraft bleibt unberührt (Level-Validierung hängt daran)', () => {
      const sprung = player.slice(player.indexOf('--- Springen'), player.indexOf('--- Zustand'))
      assertFalse(sprung.includes('huelle'), 'Sprung darf NICHT von der Hülle abhängen')
    })

    test('Sichtbarkeit ohne Hülle-Level ist immer true (Alt-Level unberührt)', () => {
      assertTrue(
        player.includes('this.huelleEnabled ? this.huelle.sichtbar : true'),
        'Rückwärtskompatibilität der Sichtbarkeit fehlt',
      )
    })

    test('Umschalten ist während Setpieces gesperrt', () => {
      const fn = player.slice(player.indexOf('tryToggleHuelle'), player.indexOf('istSichtbar'))
      assertTrue(fn.includes('controlsLocked'), 'Toggle in Cutscenes nicht gesperrt')
    })
  })

  suite('Verdrahtung — Bausteine nutzen den Spieler korrekt', () => {
    test('Lauscher fragt die Sichtbarkeit ab, nicht den Zustand direkt', () => {
      const l = lies('src/mechanics/Lauscher.ts')
      assertTrue(l.includes('player.istSichtbar'), 'umgeht die Spieler-Schnittstelle')
      assertTrue(l.includes('protokoll.markGesehen'), 'Vorfall landet nicht im Protokoll')
    })

    test('Andock-Plattform fragt die Andockfähigkeit ab', () => {
      const a = lies('src/mechanics/AndockPlattform.ts')
      assertTrue(a.includes('istAndockfaehig'), 'prüft den falschen Zustand')
      assertTrue(a.includes('body.enable'), 'schaltet die Kollision nicht um')
    })

    test('VAU-Feld betritt und verlässt die Sitzung sauber', () => {
      const v = lies('src/mechanics/VauFeld.ts')
      assertTrue(v.includes('enterVau('), 'Betreten fehlt')
      assertTrue(v.includes('leaveVau('), 'Verlassen fehlt — Zustand würde kleben')
      assertTrue(v.includes('vauRatio'), 'Frische-Anzeige fehlt')
    })

    test('Kontext-Anker frischt nur laufende Sitzungen auf', () => {
      const k = lies('src/mechanics/KontextAnker.ts')
      assertTrue(k.includes('vauExpires'), 'würde auch ohne Sitzung reagieren')
      assertTrue(k.includes('refreshSession('))
    })
  })

  suite('Verdrahtung — Durchlauf-Zustand', () => {
    test('Attract-Mode leert das Protokoll (kein Übertrag zum nächsten Besucher)', () => {
      const a = lies('src/scenes/AttractScene.ts')
      assertTrue(a.includes('protokoll.reset()'), 'Siegel würden vom Vorgänger stammen')
    })

    test('alle Hülle-Bausteine sind im Baukasten importiert', () => {
      const idx = lies('src/mechanics/index.ts')
      for (const f of ['Lauscher', 'AndockPlattform', 'VauFeld', 'KontextAnker']) {
        assertTrue(idx.includes(`import './${f}'`), `${f} fehlt in index.ts`)
      }
    })
  })

  suite('Verdrahtung — Telemetrie (KAPSEL 4.4)', () => {
    const boot = lies('src/scenes/BootScene.ts')
    const game = lies('src/scenes/GameScene.ts')
    const attract = lies('src/scenes/AttractScene.ts')
    const reward = lies('src/scenes/RewardScene.ts')
    const watchdog = lies('src/kiosk/IdleWatchdog.ts')
    const ui = lies('src/scenes/UIScene.ts')

    test('die Erfassung folgt der Config (im Messebetrieb abschaltbar)', () => {
      assertTrue(boot.includes('telemetry.aktiv = configService.gameConfig.telemetrie'))
    })

    test('jedes Level meldet Start und Ende', () => {
      assertTrue(game.includes("telemetry.setLevel(this.level.id)"), 'Level-Zuordnung fehlt')
      assertTrue(game.includes("telemetry.note('level-start'"), 'Start fehlt')
      assertTrue(game.includes("telemetry.note('level-ende'"), 'Ende fehlt')
    })

    test('der Hülle-Wechsel meldet den ZIELZUSTAND (sonst ist proaktiv/reaktiv nicht messbar)', () => {
      assertTrue(
        game.includes("telemetry.note('huelle-wechsel', this.time.now, c.to)"),
        'ohne c.to lässt sich ein Schutzwechsel nicht erkennen',
      )
    })

    test('nur echte Tastendrücke zählen als Wechsel, nicht VAU-Automatik', () => {
      assertTrue(game.includes("c.reason === 'toggle'"), 'sonst würde enterVau als Wechsel zählen')
    })

    test('VAU-Nutzung und Sitzungsablauf werden getrennt erfasst', () => {
      assertTrue(game.includes("'vau-betreten'"))
      assertTrue(game.includes("'vau-abgelaufen'"))
    })

    test('der Lauscher meldet Treffer UND nötige Tipps', () => {
      const l = lies('src/mechanics/Lauscher.ts')
      assertTrue(l.includes("telemetry.note('gesehen'"), 'Treffer fehlt')
      assertTrue(l.includes("telemetry.note('tipp'"), 'Tipp = Verständnisproblem, muss gezählt werden')
    })

    test('Sammeln und Checkpoints werden erfasst', () => {
      const b = lies('src/mechanics/basics.ts')
      assertTrue(b.includes("telemetry.note('gesammelt'"))
      assertTrue(b.includes("telemetry.note('checkpoint'"))
    })

    test('der Idle-Reset hält den Abbruchpunkt fest', () => {
      assertTrue(watchdog.includes("telemetry.note('level-abbruch'"), 'Abbruchpunkte gingen verloren')
    })

    test('REIHENFOLGE: sichern VOR dem Stoppen der Szenen', () => {
      const iSichern = watchdog.indexOf('speichereSitzung')
      const iStoppen = watchdog.indexOf('sm.stop')
      assertTrue(iSichern > 0 && iStoppen > 0, 'Aufrufe nicht gefunden')
      assertTrue(iSichern < iStoppen, 'nach dem Stoppen wäre die Beobachtung verloren')
    })

    test('REIHENFOLGE: sichern VOR neueSitzung (sonst ist der Durchlauf weg)', () => {
      const iSichern = attract.indexOf('speichereSitzung')
      const iNeu = attract.indexOf('telemetry.neueSitzung')
      assertTrue(iSichern > 0 && iNeu > 0, 'Aufrufe nicht gefunden')
      assertTrue(iSichern < iNeu, 'neueSitzung() verwirft die Ereignisse')
    })

    test('auch der erfolgreiche Durchlauf wird gesichert', () => {
      assertTrue(reward.includes('speichereSitzung'), 'gewonnene Läufe fehlten in der Statistik')
    })

    test('F9 zeigt die Auswertung und exportiert (für das Standpersonal)', () => {
      assertTrue(ui.includes("keydown-F9"), 'kein Zugriff für das Standpersonal')
      assertTrue(ui.includes('benchmark('), 'Quote wird nicht berechnet')
      assertTrue(ui.includes('exportiereDatei('), 'Export fehlt')
    })

    test('die Auswertung wertet nur Level MIT Hülle (sonst verzerrt Level 1 die Quote)', () => {
      assertTrue(ui.includes('l.huelle.enabled'), 'Filterung auf Hülle-Level fehlt')
    })
  })
}
