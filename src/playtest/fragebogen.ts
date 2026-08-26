/**
 * PRE-/POST-TEST (KAPSEL 4.4) — der Fragebogen als prüfbare Daten.
 *
 * Warum im Code und nicht nur in docs/PLAYTEST.md? Weil dann ein Test erzwingen
 * kann, was sonst niemand kontrolliert:
 *
 *   • Jeder der fünf Vereinfachungsfehler aus KAPSEL 1.4 wird wirklich abgefragt.
 *     Streicht jemand später eine Frage, schlägt der Test an.
 *   • Jede Frage hat genau EINE richtige Antwort.
 *   • Jede Frage nennt ihr Lernziel — sonst weiß man bei einer falschen Antwort
 *     nicht, WAS im Spiel nachgebessert werden muss.
 *
 * Die Erhebung selbst läuft auf Papier (kein Personenbezug, siehe PLAYTEST.md).
 * Diese Datei ist die Quelle der Wahrheit für Inhalt und Auswertung.
 */

/**
 * Die fünf Vereinfachungsfehler aus KAPSEL 1.4 — die Stellen, an denen ein
 * Lernspiel fachlich Schaden anrichten kann. Jeder MUSS abgefragt werden.
 */
export const LERNZIELE = [
  'klartext-mitlesbar', // unverschlüsselt = auf dem Transportweg mitlesbar
  'vau-kein-tunnel', // VAU = Verarbeitungsraum, nicht Tunnel
  'signatur-vs-krypto', // Verschlüsselung ≠ Signatur
  'egk-schluessel', // eGK = Schlüssel, kein Datenspeicher
  'zero-trust', // Zero Trust = mehr Prüfung, nicht weniger Schutz
  'sitzung-laeuft-ab', // abgelaufene Sitzung schützt nicht
  'datenhoheit', // die versicherte Person entscheidet
] as const

export type Lernziel = (typeof LERNZIELE)[number]

export interface Frage {
  id: number
  lernziel: Lernziel
  text: string
  antworten: string[]
  /** Index der richtigen Antwort in `antworten`. */
  richtig: number
  /** Was zu tun ist, wenn diese Frage NACH dem Spielen falsch bleibt. */
  konsequenz: string
}

export const FRAGEN: Frage[] = [
  {
    id: 1,
    lernziel: 'klartext-mitlesbar',
    text: 'Ein unverschlüsseltes Dokument ist auf dem Transportweg …',
    antworten: ['… nur für den Empfänger lesbar', '… für Dritte mitlesbar', '… automatisch gelöscht'],
    richtig: 1,
    konsequenz: 'Kernaussage kommt nicht an — Lauscher-Sichtkegel deutlicher machen.',
  },
  {
    id: 2,
    lernziel: 'vau-kein-tunnel',
    text: 'In der VAU (Vertrauenswürdige Ausführungsumgebung) …',
    antworten: [
      '… sind Daten nur verschlüsselt vorhanden',
      '… wird im Klartext gearbeitet, ohne dass der Betreiber mitlesen kann',
      '… kann der Rechenzentrumsbetreiber die Daten lesen',
    ],
    richtig: 1,
    konsequenz: 'Häufigster Irrtum „VAU = Tunnel" — VAU-Feld optisch klarer vom Verschlüsselt-Zustand trennen.',
  },
  {
    id: 3,
    lernziel: 'signatur-vs-krypto',
    text: 'Verschlüsselung und Signatur …',
    antworten: [
      '… sind dasselbe',
      '… sind zwei verschiedene Dinge: Vertraulichkeit vs. Echtheit',
      '… schließen sich gegenseitig aus',
    ],
    richtig: 1,
    konsequenz: 'Signatur-Setpiece (stamp-exit) stärker von der Hülle abgrenzen.',
  },
  {
    id: 4,
    lernziel: 'egk-schluessel',
    text: 'Wozu dient die elektronische Gesundheitskarte beim E-Rezept?',
    antworten: [
      'Sie speichert das Rezept',
      'Sie ist der Schlüssel, der den Zugriff freigibt',
      'Sie bezahlt das Medikament',
    ],
    richtig: 1,
    konsequenz: 'Kartenstecken-Mechanik (Welt 2) fehlt noch — hier ist der Zuwachs erwartbar niedrig.',
  },
  {
    id: 5,
    lernziel: 'zero-trust',
    text: '„Zero Trust" bedeutet …',
    antworten: [
      '… es gibt keinen Schutz',
      '… jeder einzelne Zugriff wird geprüft, unabhängig vom Ort',
      '… nur das interne Netz wird geprüft',
    ],
    richtig: 1,
    konsequenz: 'Zero-Trust-Pforten (Welt 4) fehlen noch — Wert dient als Ausgangsmessung.',
  },
  {
    id: 6,
    lernziel: 'sitzung-laeuft-ab',
    text: 'Wenn eine Sitzung in der VAU abläuft, …',
    antworten: ['… bleiben die Daten geschützt', '… ist man wieder ungeschützt und sichtbar', '… wird das Spiel beendet'],
    richtig: 1,
    konsequenz: 'Kontextschlüssel-Anzeige (Balken) auffälliger machen.',
  },
  {
    id: 7,
    lernziel: 'datenhoheit',
    text: 'Wer entscheidet, wer in die elektronische Patientenakte sehen darf?',
    antworten: ['Die Krankenkasse', 'Die Arztpraxis', 'Die versicherte Person'],
    richtig: 2,
    konsequenz: 'Schlusspointe (Welt 5) fehlt noch — Wert dient als Ausgangsmessung.',
  },
]

/** Ein ausgefüllter Bogen: je Frage der gewählte Antwortindex (-1 = keine Angabe). */
export type Antwortbogen = number[]

export function bewerte(bogen: Antwortbogen): number {
  return FRAGEN.reduce((n, f, i) => n + (bogen[i] === f.richtig ? 1 : 0), 0)
}

export interface Auswertung {
  vorher: number
  nachher: number
  /** Lernzuwachs (kann negativ sein — das wäre ein Warnsignal). */
  zuwachs: number
  gesamt: number
  /** Lernziele, die NACH dem Spielen noch falsch sind → dort nachbessern. */
  offeneLernziele: Lernziel[]
}

export function werteAus(vorher: Antwortbogen, nachher: Antwortbogen): Auswertung {
  const v = bewerte(vorher)
  const n = bewerte(nachher)
  return {
    vorher: v,
    nachher: n,
    zuwachs: n - v,
    gesamt: FRAGEN.length,
    offeneLernziele: FRAGEN.filter((f, i) => nachher[i] !== f.richtig).map((f) => f.lernziel),
  }
}

/**
 * Gruppenbilanz über mehrere Bögen. `mittlererZuwachs` ist die Kennzahl für den
 * Bericht; `problemLernziele` zeigt, wo das Spiel nachbessern muss (mehr als die
 * Hälfte der Gruppe hat es hinterher noch falsch).
 */
export function gruppenBilanz(paare: { vorher: Antwortbogen; nachher: Antwortbogen }[]): {
  n: number
  mittlerVorher: number
  mittlerNachher: number
  mittlererZuwachs: number
  problemLernziele: Lernziel[]
} {
  const n = paare.length
  if (n === 0) {
    return { n: 0, mittlerVorher: 0, mittlerNachher: 0, mittlererZuwachs: 0, problemLernziele: [] }
  }
  const einzeln = paare.map((p) => werteAus(p.vorher, p.nachher))
  const mittel = (werte: number[]): number => Math.round((werte.reduce((a, b) => a + b, 0) / n) * 10) / 10
  const falschJe: Record<string, number> = {}
  for (const a of einzeln) {
    for (const z of a.offeneLernziele) falschJe[z] = (falschJe[z] ?? 0) + 1
  }
  return {
    n,
    mittlerVorher: mittel(einzeln.map((a) => a.vorher)),
    mittlerNachher: mittel(einzeln.map((a) => a.nachher)),
    mittlererZuwachs: mittel(einzeln.map((a) => a.zuwachs)),
    problemLernziele: LERNZIELE.filter((z) => (falschJe[z] ?? 0) > n / 2),
  }
}
