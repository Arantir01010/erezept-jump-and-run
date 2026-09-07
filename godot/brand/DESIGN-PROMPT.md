# Design-Prompt: PwC-Erscheinungsbild ohne KI-Einheitslook

Vorlage für KI-Werkzeuge (Claude, v0, Lovable, Bolt, Cursor), damit Oberflächen im
PwC-Look entstehen statt im Trainingsdaten-Durchschnitt (Violett-Verlauf, Inter, drei
Karten in einer Reihe). Werte und Schriften stammen aus `src/core/Brand.gd` und
`brand/README.md`. Den Block **Kurzfassung** in den Projektkontext legen (CLAUDE.md,
v0 „Knowledge", Lovable „Custom Knowledge"), den **Vollprompt** für neue Screens nutzen.

## Vollprompt (Deutsch)

```text
Du gestaltest [ANWENDUNG] für [ZIELGRUPPE] im Erscheinungsbild von PwC. Halte dich strikt an
diese Vorgaben; weiche nur ab, wenn ich es ausdrücklich verlange.

FARBEN — nur diese Werte, keine freien Hex-Codes, keine Verläufe als Dekoration
- Marke, Primäraktion, Fortschritt: Orange #D04A02
- Aufforderung, Hervorhebung, aktiver Zustand, Links: Tangerine #EB8C00
  (auf dunklem Grund statt Orange, dort besser lesbar)
- Erfolg, Auszeichnung, Bestwert: Yellow #FFB600
- Fehler, Warnung, „verweigert": Red #E0301E — nie dekorativ
- Zweitfarben sparsam: Rose #D93954, Maroon #822720
- Neutral: Schwarz #000000, Dunkelgrau #2D2D2D, Grau #464646, Mittelgrau #7D7D7D,
  Hellgrau #DEDEDE, Blassgrau #F2F2F2, Weiß #FFFFFF
- Verteilung 60/30/10: neutrale Fläche, dunkle Struktur, ein scharfer Orange-Akzent.
  Eine dominante Farbe, ein Akzent — kein Regenbogen, kein „bunt".
- Flächen: #2D2D2D mit 86 % Deckung, 1-px-Kante Weiß 16 %, Rundung 6 px.
  Helle Variante: Grund #F2F2F2, Text #2D2D2D, Akzent Orange. Kein Glas-Effekt.

SCHRIFT — zwei Familien, sonst nichts
- Überschriften: ITC Charter Bold (Serif). Groß, enge Zeilenhöhe, leichte Laufweite.
- Lesetext: Helvetica Neue Roman. Eyebrows, Pillen, Tastenkappen, Schilder:
  Helvetica Neue Medium in Versalien, gesperrt. Stempel, Knöpfe, Alarm: Helvetica Neue
  Bold/Heavy.
- Kontrast statt Einheitsbrei: Charter groß gegen Helvetica klein, Light gegen Heavy,
  nicht 400 gegen 600.
- Technischer Fallback nur deklarieren, nie gestalten: Georgia für Charter,
  Helvetica/Arial für Helvetica Neue. Kein Inter, Roboto, Space Grotesk, keine Systemschrift.

LAYOUT UND BAUSTEINE
- Hierarchie pro Screen: Eyebrow (Versalien, Tangerine oder Yellow, gesperrt), darunter
  eine große Charter-Überschrift, darunter ein Satz in Helvetica.
- Primärknopf: Orange gefüllt, weiße Schrift. Sekundär: transparent mit Kante.
  Segment-Schalter: ein Rahmen, das aktive Feld orange gefüllt.
- Pillen und Karten mit 18/6 px Innenabstand; Breiten folgen dem Text, nicht festen Maßen.
- Piktogramme nur aus dem PwC-Werte-Set (care, act with integrity, make a difference,
  work together, reimagine the possible) in Weiß oder Schwarz. Keine Emojis als Icons.
- Bewegung: ein orchestrierter Moment (gestaffeltes Einblenden beim Laden oder eine
  schräge Blende mit orangefarbenem Saum), sonst Ruhe. Nichts blinkt schneller als 3 Hz.
- Struktur trägt Bedeutung: Nummern nur bei echten Reihenfolgen, Linien nur bei
  Inhaltswechsel, Rundung und Abstand nach Gewicht des Elements, nicht überall gleich.

VERBOTEN (typische KI-Optik)
- Violett-, Indigo- oder Blau-Verläufe; Verläufe als Dekoration überhaupt
- Inter, Roboto, Arial, eine Schrift für alles
- drei identische Feature-Karten nebeneinander, Karte in Karte, überall 16 px Rundung
- Emojis als Icons, Stockfoto-Platzhalter, Neon-Kanten, Glassmorphism, große weiche Schatten
- generische Überschriften („Skalieren ohne Grenzen"), alles zentriert, Hover-Hüpfer
- rotes Kreuz als Symbol (geschützt)

ARBEITSWEISE
1. Lege zuerst die Tokens an (--pwc-orange, --pwc-tangerine, --pwc-yellow, --pwc-red,
   --surface, --surface-solid, --border, --text, --text-dim, --text-muted, --radius: 6px)
   und ein Beispiel-Bauteil. Zeig mir das, bevor du den Rest baust.
2. Komponenten nur aus Tokens, keine freien Werte.
3. Wenn eine Wahl auf jeder beliebigen App sitzen könnte, ist sie falsch. Triff eine
   Entscheidung, die zu [THEMA] passt, und begründe sie in einem Satz.
4. Du neigst zu generischen, „on distribution"-Ergebnissen. Vermeide das bewusst.
```

## Kurzfassung für den Projektkontext

```text
PwC-Look. Farben nur: Orange #D04A02 (Primär), Tangerine #EB8C00 (Akzent auf dunkel),
Yellow #FFB600 (Erfolg), Red #E0301E (Fehler), Neutral #000000 #2D2D2D #464646 #7D7D7D
#DEDEDE #F2F2F2 #FFFFFF. 60/30/10, ein Akzent. Flächen #2D2D2D 86 %, Kante Weiß 16 %,
Rundung 6 px. Schrift: ITC Charter Bold für Überschriften, Helvetica Neue Roman für Text,
Medium versal gesperrt für Eyebrows/Pillen, Bold/Heavy für Knöpfe. Verboten: Verläufe,
Inter/Roboto/Arial, Emojis als Icons, drei gleiche Karten, Karte in Karte, Glassmorphism,
Blinken über 3 Hz, rotes Kreuz. Tokens zuerst, Komponenten nur aus Tokens.
```

## Full prompt (English, for v0 / Lovable / Bolt)

```text
Design [APP] for [AUDIENCE] in the PwC visual identity. Follow these rules strictly.

COLOURS — only these values, no ad-hoc hex codes, no decorative gradients
- Brand, primary action, progress: Orange #D04A02
- Call to action, highlight, active state, links: Tangerine #EB8C00 (use instead of
  Orange on dark backgrounds)
- Success, award, best score: Yellow #FFB600
- Error, warning, "denied": Red #E0301E — never decorative
- Secondary, sparingly: Rose #D93954, Maroon #822720
- Neutrals: #000000 #2D2D2D #464646 #7D7D7D #DEDEDE #F2F2F2 #FFFFFF
- 60/30/10: neutral ground, dark structure, one sharp orange accent. One dominant colour,
  one accent, never a rainbow.
- Surfaces: #2D2D2D at 86 % opacity, 1 px border white 16 %, radius 6 px. Light variant:
  ground #F2F2F2, text #2D2D2D, accent Orange. No glassmorphism.

TYPE — two families, nothing else
- Headlines: ITC Charter Bold (serif), large, tight leading, slight tracking.
- Body: Helvetica Neue Roman. Eyebrows, pills, keycaps, signs: Helvetica Neue Medium,
  uppercase, tracked. Stamps, buttons, alerts: Helvetica Neue Bold/Heavy.
- Contrast over sameness: Charter large against Helvetica small, Light against Heavy.
- Declare technical fallbacks only (Georgia; Helvetica, Arial). Never Inter, Roboto,
  Space Grotesk or system fonts as a design choice.

LAYOUT AND COMPONENTS
- Per screen: eyebrow (uppercase, Tangerine or Yellow, tracked), large Charter headline,
  one Helvetica sentence.
- Primary button: filled Orange, white text. Secondary: transparent with border.
  Segmented control: one frame, active segment filled Orange.
- Pills and cards: 18/6 px padding, widths follow the text.
- Pictograms only from the PwC values set (care, act with integrity, make a difference,
  work together, reimagine the possible), white or black. No emoji icons.
- Motion: one orchestrated moment (staggered reveal on load or a slanted wipe with an
  orange edge), calm otherwise. Nothing flashes above 3 Hz.
- Structure carries meaning: numbers only for real sequences, dividers only where content
  changes, radius and spacing by weight of the element, not uniform.

FORBIDDEN (typical AI look)
- purple/indigo/blue gradients, decorative gradients of any kind
- Inter, Roboto, Arial, one font for everything
- three identical feature cards in a row, cards inside cards, 16 px radius everywhere
- emoji as icons, stock-photo placeholders, neon edges, glassmorphism, big soft shadows
- generic headlines ("Scale without limits"), everything centred, hover bounce
- a red cross as a symbol (protected)

WORKFLOW
1. Define the tokens first (--pwc-orange, --pwc-tangerine, --pwc-yellow, --pwc-red,
   --surface, --surface-solid, --border, --text, --text-dim, --text-muted, --radius: 6px)
   plus one example component; show me those before building the rest.
2. Components use tokens only, no arbitrary values.
3. If a choice could sit on any app, it is wrong. Decide something that fits [TOPIC] and
   justify it in one sentence.
4. You tend to converge on generic, on-distribution output. Actively avoid it.
```

## Was der Prompt bewusst nicht regelt

Spielinhalte bleiben Inhalt: Welten-Paletten, Paul, REZI, das Nacht-Blau des Hauptmenüs
und die fachlichen Hülle-Farben (warm = offen, kühl = verschlüsselt, violett = VAU) sind
keine Markenfarben und dürfen nicht „auf PwC" umgefärbt werden.

## Herkunft der Regeln

Negativliste und „Tokens zuerst" nach Anthropic (Cookbook „Prompting for frontend
aesthetics"), Braingrid (Design-System-Tokens für KI-Coding), Mania Design („Spot the
Slop") und Battlecat AI; Farbwerte, Rollen und Schriften aus `src/core/Brand.gd`.
