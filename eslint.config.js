// ESLint-Flat-Config — Statik-Check für Engine (src/) und Werkzeuge (tools/).
//
// Bewusst schlank: die empfohlenen Regelsätze von ESLint und typescript-eslint,
// ohne typgeprüfte Regeln (die übernimmt `tsc --noEmit` im Build) und ohne
// Format-Regeln (kein Prettier — das Repo bleibt diff-arm). Läuft in der CI
// direkt nach den Tests (npm run lint).
//
// GESCHÜTZTE DATEI: Änderungen nur durch Menschen (npm run guard).
import js from '@eslint/js'
import tseslint from 'typescript-eslint'

export default tseslint.config(
  // Generate, Abhängigkeiten und lokale Werkzeuge nie linten
  { ignores: ['dist', 'node_modules', 'public', '_to_delete', '.tools'] },
  {
    files: ['src/**/*.ts', 'tools/**/*.ts', 'vite.config.ts'],
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    rules: {
      // Projekt-Konvention: bewusst ungenutzte Parameter/Variablen tragen ein
      // führendes "_" (z. B. Mechanic.update(_time, _delta)).
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      // Phaser-Adapter mit Objekt-Literal-Gettern (GameScene.buildMechanicHost):
      // Getter haben ein eigenes `this`, der Szenen-Verweis braucht den Alias.
      '@typescript-eslint/no-this-alias': ['error', { allowedNames: ['self'] }],
    },
  },
)
