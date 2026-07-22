/** Übersetzt Redakteurs-Namen aus input-bindings.json in KeyboardEvent.code-Werte. */
const SPECIAL: Record<string, string> = {
  LEFT: 'ArrowLeft',
  RIGHT: 'ArrowRight',
  UP: 'ArrowUp',
  DOWN: 'ArrowDown',
  SPACE: 'Space',
  ENTER: 'Enter',
  SHIFT: 'ShiftLeft',
  CTRL: 'ControlLeft',
  ESC: 'Escape',
  TAB: 'Tab',
}

export function bindingNameToCode(name: string): string {
  const upper = name.toUpperCase()
  if (SPECIAL[upper]) return SPECIAL[upper]
  if (/^[A-Z]$/.test(upper)) return `Key${upper}`
  if (/^[0-9]$/.test(upper)) return `Digit${upper}`
  if (/^F([1-9]|1[0-2])$/.test(upper)) return upper
  // Unbekannter Name: unverändert durchreichen (z. B. bereits ein e.code)
  return name
}
