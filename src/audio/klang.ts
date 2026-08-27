/**
 * KLANG — die Audio-Seite des Game Feel, komplett synthetisiert (Web Audio),
 * ohne ein einziges Sample-Asset. Passt zur Vektor-Philosophie des Projekts:
 * keine Dateien, keine Ladezeit, überall dieselben Klänge.
 *
 * Sieben kurze Signale, alle unter 300 ms und bewusst leise abgemischt —
 * Rückmeldung, keine Musik:
 *   sprung    heller Chirp aufwärts
 *   landung   weicher Boden-Thump (gefiltertes Rauschen)
 *   sammeln   Zwei-Ton-Blip (das „Pling" der Datenbits)
 *   treffer   fallender Brumm — ZUGRIFF VERWEIGERT ohne Worte
 *   tor       aufsteigende Quinte (etwas öffnet sich)
 *   siegel    Stempel-Thunk mit Glanzton (der große Moment)
 *
 * Betrieb: über game-config.json `audio` abschaltbar (Messestand kann laut
 * sein — analog zum telemetrie-Schalter). Der AudioContext entsteht lazy
 * beim ersten Klang und wird bei Bedarf resumed — Browser geben Audio erst
 * nach der ersten Nutzergeste frei; die ist am Attract-Screen ohnehin der
 * erste Schritt. Jeder Aufruf ist crash-sicher (Kiosk!): Fehler werden
 * geschluckt, das Spiel läuft stumm weiter.
 */

const MASTER_VOLUME = 0.35

class Klang {
  /** Aus game-config.json (BootScene) — false = kein Context, keine Klänge. */
  aktiv = true
  private ctx: AudioContext | null = null
  private master: GainNode | null = null

  private get kontext(): AudioContext | null {
    if (!this.aktiv) return null
    try {
      if (!this.ctx) {
        this.ctx = new AudioContext()
        this.master = this.ctx.createGain()
        this.master.gain.value = MASTER_VOLUME
        this.master.connect(this.ctx.destination)
      }
      if (this.ctx.state === 'suspended') void this.ctx.resume()
      return this.ctx
    } catch {
      return null // kein Web Audio → stumm weiterspielen
    }
  }

  /** Ein Oszillator-Ton mit Frequenzfahrt und Ausklang. */
  private ton(
    von: number,
    nach: number,
    dauer: number,
    typ: OscillatorType,
    vol: number,
    delay = 0,
  ): void {
    const ctx = this.kontext
    if (!ctx || !this.master) return
    try {
      const t0 = ctx.currentTime + delay
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = typ
      osc.frequency.setValueAtTime(von, t0)
      osc.frequency.exponentialRampToValueAtTime(Math.max(20, nach), t0 + dauer)
      gain.gain.setValueAtTime(vol, t0)
      gain.gain.exponentialRampToValueAtTime(0.001, t0 + dauer)
      osc.connect(gain)
      gain.connect(this.master)
      osc.start(t0)
      osc.stop(t0 + dauer + 0.02)
    } catch {
      /* stumm bleiben statt crashen */
    }
  }

  /** Gefiltertes Rauschen (Thump/Impact). */
  private rauschen(dauer: number, cutoff: number, vol: number): void {
    const ctx = this.kontext
    if (!ctx || !this.master) return
    try {
      const laenge = Math.ceil(ctx.sampleRate * dauer)
      const buffer = ctx.createBuffer(1, laenge, ctx.sampleRate)
      const daten = buffer.getChannelData(0)
      for (let i = 0; i < laenge; i++) daten[i] = (Math.random() * 2 - 1) * (1 - i / laenge)
      const quelle = ctx.createBufferSource()
      quelle.buffer = buffer
      const filter = ctx.createBiquadFilter()
      filter.type = 'lowpass'
      filter.frequency.value = cutoff
      const gain = ctx.createGain()
      gain.gain.value = vol
      quelle.connect(filter)
      filter.connect(gain)
      gain.connect(this.master)
      quelle.start()
    } catch {
      /* stumm bleiben statt crashen */
    }
  }

  sprung(): void {
    this.ton(300, 560, 0.09, 'triangle', 0.5)
  }

  landung(): void {
    this.rauschen(0.06, 420, 0.55)
  }

  sammeln(): void {
    this.ton(880, 880, 0.055, 'sine', 0.5)
    this.ton(1320, 1320, 0.09, 'sine', 0.45, 0.055)
  }

  treffer(): void {
    this.ton(210, 70, 0.24, 'sawtooth', 0.5)
  }

  tor(): void {
    this.ton(392, 392, 0.09, 'triangle', 0.4)
    this.ton(587, 587, 0.16, 'triangle', 0.4, 0.09)
  }

  siegel(): void {
    this.rauschen(0.09, 300, 0.7)
    this.ton(523, 523, 0.12, 'triangle', 0.45, 0.06)
    this.ton(1046, 1046, 0.22, 'sine', 0.35, 0.14)
  }
}

export const klang = new Klang()
