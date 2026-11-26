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
- Marke, Primäraktion, Fortschritt: Orange 500 #FD5108 (Text darauf Weiß)
- Aufforderung, Hervorhebung, aktiver Zustand, Links: Orange 300 #FFAA72
  (auf dunklem Grund statt Orange, dort besser lesbar)
- Auszeichnung, Bestwert: Tangerine 400 #FFC21B · Erfolg: Success 400 #18AE80 · Info: Blue 300 #6797FF
- Fehler, „verweigert": Red 400 #ED4242 · Warnung: Warning 300 #E9B01F — nie dekorativ
- Sekundärfarbe für Illustration und Piktogramme: Tangerine 500 #FF9F00
- Neutral (Grey): 1000 #111113, 975 #202124, 950 #303236, 800 #4C5056, 700 #787E8A, 600 #8E95A2,
  300 #CBD1D6, 50 #F5F7F8, Weiß #FFFFFF
- Verteilung 60/30/10: neutrale Fläche, dunkle Struktur, ein scharfer Orange-Akzent.
  Eine dominante Farbe, ein Akzent — kein Regenbogen, kein „bunt".
- Flächen: Grey 975 #202124 auf Grund Grey 1000, 1-px-Kante Grey 700, Ecken eckig (höchstens 2 px).
  Helle Variante: Grund Weiß/Grey 50, Text Grey 1000, Akzent Orange 500. Kein Glas-Effekt.

SCHRIFT — zwei Familien, sonst nichts
- Überschriften: ITC Charter Bold (Serif). Groß, enge Zeilenhöhe, leichte Laufweite.
- Lesetext: Helvetica Neue Roman. Eyebrows, Pillen, Tastenkappen, Schilder:
  Helvetica Neue Medium in normaler Groß-/Kleinschreibung (keine Versalien). Stempel, Knöpfe, Alarm: Helvetica Neue
  Bold/Heavy.
- Kontrast statt Einheitsbrei: Charter groß gegen Helvetica klein, Light gegen Heavy,
  nicht 400 gegen 600.
- Technischer Fallback nur deklarieren, nie gestalten: Georgia für Charter,
  Helvetica/Arial für Helvetica Neue. Kein Inter, Roboto, Space Grotesk, keine Systemschrift.

LAYOUT UND BAUSTEINE
- Hierarchie pro Screen: Eyebrow (Orange 300, klein, keine Versalien), darunter
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
PwC-Look (Digital Colour System, Dark mode). Farben nur: Orange 500 #FD5108 (Primär),
Orange 300 #FFAA72 (Akzent auf dunkel), Tangerine 400 #FFC21B (Auszeichnung), Success #18AE80,
Info #6797FF, Warning #E9B01F, Error #ED4242, Grey #111113 #202124 #303236 #787E8A #CBD1D6
#F5F7F8. 60/30/10, ein Akzent. Flächen Grey 975, Kante Grey 700, Ecken eckig. Keine Versalien. Schrift: ITC Charter Bold für Überschriften, Helvetica Neue Roman für Text,
Medium für Eyebrows/Pillen, Bold/Heavy für Knöpfe. Verboten: Verläufe,
Inter/Roboto/Arial, Emojis als Icons, drei gleiche Karten, Karte in Karte, Glassmorphism,
Blinken über 3 Hz, rotes Kreuz. Tokens zuerst, Komponenten nur aus Tokens.
```

## Full prompt (English, for v0 / Lovable / Bolt)

```text
Design [APP] for [AUDIENCE] in the PwC visual identity. Follow these rules strictly.

COLOURS — only these values, no ad-hoc hex codes, no decorative gradients
- Brand, primary action, progress: Orange 500 #FD5108 (white text on it)
- Call to action, highlight, active state, links: Orange 300 #FFAA72 (use instead of
  Orange on dark backgrounds)
- Award, best score: Tangerine 400 #FFC21B · Success 400 #18AE80 · Info Blue 300 #6797FF
- Error, "denied": Red 400 #ED4242 · Warning 300 #E9B01F — never decorative
- Secondary colour for illustration and pictograms: Tangerine 500 #FF9F00
- Neutrals (Grey): #111113 #202124 #303236 #4C5056 #787E8A #8E95A2 #CBD1D6 #F5F7F8 #FFFFFF
- 60/30/10: neutral ground, dark structure, one sharp orange accent. One dominant colour,
  one accent, never a rainbow.
- Surfaces: Grey 975 #202124 on Grey 1000, 1 px border Grey 700, square corners (2 px max).
  Light variant: ground white/Grey 50, text Grey 1000, accent Orange 500. No glassmorphism.

TYPE — two families, nothing else
- Headlines: ITC Charter Bold (serif), large, tight leading, slight tracking.
- Body: Helvetica Neue Roman. Eyebrows, pills, keycaps, signs: Helvetica Neue Medium,
  sentence case (never all caps). Stamps, buttons, alerts: Helvetica Neue Bold/Heavy.
- Contrast over sameness: Charter large against Helvetica small, Light against Heavy.
- Declare technical fallbacks only (Georgia; Helvetica, Arial). Never Inter, Roboto,
  Space Grotesk or system fonts as a design choice.

LAYOUT AND COMPONENTS
- Per screen: eyebrow (Orange 300, small, never all caps), large Charter headline,
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
