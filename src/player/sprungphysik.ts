/**
 * SPRUNGKURVE & KANTEN-KORREKTUR — die „unsichtbaren" Feel-Mechaniken
 * der Celeste/Mario-Schule, Phaser-frei und unter Node getestet
 * (tools/test/sprungfeel.test.ts).
 *
 * Drei Regeln, alle als Faktor auf die Grundgravitation ausgedrückt:
 *   1. Variable Sprunghöhe: Taste im Steigen losgelassen → schwerere
 *      Gravitation beendet den Sprung früher. Kurz tippen = Hüpfer,
 *      halten = voller Sprung. Der VOLLE Sprung bleibt jederzeit abrufbar —
 *      deshalb bleibt die Erreichbarkeits-Simulation des Level-Compilers
 *      ohne Änderung gültig.
 *   2. Scheitel-Schweben: um den Sprungscheitel (|vy| klein) gilt bei
 *      gehaltener Taste halbierte Gravitation — Zeit zum Zielen.
 *   3. Asymmetrisches Fallen: abwärts zieht die Gravitation stärker.
 *      Das VERKÜRZT reale Sprungweiten — die MAX_DX-Konstanten in
 *      tools/lib/compile.ts sind dagegen nachgerechnet, und der Test
 *      sprungfeel.test.ts schlägt an, wenn jemand Faktor oder Konstanten
 *      auseinanderlaufen lässt.
 *
 * WICHTIG (Hülle): Die Kurve ist in ALLEN Hülle-Zuständen identisch —
 * die Hülle wirkt ausschließlich aufs Lauftempo (HuelleState.ts).
 */

export interface SprungTuning {
  lowJumpGravityFactor: number
  apexGravityFactor: number
  apexWindow: number
  fallGravityFactor: number
}

/**
 * Gravitationsfaktor für den aktuellen Frame (1 = Grundgravitation).
 * vy < 0 heißt steigen (Phaser-Y wächst nach unten).
 */
export function gravitationsFaktor(
  vy: number,
  sprungGehalten: boolean,
  amBoden: boolean,
  t: SprungTuning,
): number {
  if (amBoden) return 1
  // Scheitel-Schweben: nur solange die Taste gehalten wird
  if (sprungGehalten && Math.abs(vy) < t.apexWindow) return t.apexGravityFactor
  if (vy < 0) return sprungGehalten ? 1 : t.lowJumpGravityFactor
  return t.fallGravityFactor
}

/**
 * Kanten-Korrektur beim Kopf-Bonk: Blockt nur EINE der beiden Kopfecken an
 * einer Kachel und ragt sie höchstens `maxPx` hinein, wird Paul seitlich um
 * die Kante geschoben statt den Sprung zu töten. Liefert die horizontale
 * Verschiebung in px (0 = keine Korrektur möglich).
 */
export function eckKorrektur(
  kopfLinks: number,
  kopfRechts: number,
  tileW: number,
  solideUeberLinks: boolean,
  solideUeberRechts: boolean,
  maxPx: number,
): number {
  if (solideUeberLinks === solideUeberRechts) return 0 // frei oder voll gedeckt
  if (solideUeberLinks) {
    // linke Ecke ragt in die Kachel — wie weit bis zu deren rechter Kante?
    const kante = (Math.floor(kopfLinks / tileW) + 1) * tileW
    const ueberlapp = kante - kopfLinks
    return ueberlapp <= maxPx ? ueberlapp + 0.5 : 0
  }
  const kante = Math.floor(kopfRechts / tileW) * tileW
  const ueberlapp = kopfRechts - kante
  return ueberlapp <= maxPx ? -(ueberlapp + 0.5) : 0
}

/**
 * Reale maximale Sprungweite in px (Kachelmitte-zu-Mitte-Logik übernimmt der
 * Compiler): voller Sprung mit Anlauf `speed`, Steigen unter Grundgravitation,
 * Fallen unter fallGravityFactor, plus Coyote-Bonus. Das Scheitel-Schweben
 * wird bewusst IGNORIERT (es macht real mehr möglich — die Rechnung bleibt
 * die strengere Instanz). Grundlage der MAX_DX-Deckungsprüfung im Test.
 */
export function maxSprungweitePx(
  steigHoehePx: number,
  speed: number,
  jumpVelocity: number,
  gravityY: number,
  fallGravityFactor: number,
  coyoteMs: number,
): number {
  const scheitel = (jumpVelocity * jumpVelocity) / (2 * gravityY)
  if (steigHoehePx > scheitel) return 0 // unerreichbar hoch
  const steigZeit = jumpVelocity / gravityY
  const fallHoehe = scheitel - steigHoehePx
  const fallZeit = Math.sqrt((2 * fallHoehe) / (gravityY * fallGravityFactor))
  return speed * (steigZeit + fallZeit) + speed * (coyoteMs / 1000)
}
