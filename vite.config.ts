import { defineConfig } from 'vite'

// base './' => Build läuft offline aus jedem Ordner (Messe-PC, file:// oder lokaler Mini-Server)
export default defineConfig({
  base: './',
  build: {
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 1500,
  },
  server: {
    port: 5173,
    host: '127.0.0.1',
  },
})
