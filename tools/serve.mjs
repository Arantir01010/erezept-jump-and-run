/**
 * Minimaler Offline-Static-Server für den Messebetrieb (dist/ auf Port 8080).
 * Bewusst ohne Abhängigkeiten — läuft mit der portablen Node aus .tools/node.
 */
import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
import { join, extname, normalize } from 'node:path'
import { fileURLToPath } from 'node:url'

const DIST = join(fileURLToPath(new URL('.', import.meta.url)), '..', 'dist')
const PORT = 8080

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.tmj': 'application/json',
  '.png': 'image/png',
  '.ogg': 'audio/ogg',
  '.svg': 'image/svg+xml',
}

createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', 'http://localhost')
    let path = normalize(decodeURIComponent(url.pathname)).replace(/^([/\\])+/, '')
    if (path === '' || path === '.') path = 'index.html'
    const file = join(DIST, path)
    if (!file.startsWith(DIST)) throw new Error('forbidden')
    const data = await readFile(file)
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] ?? 'application/octet-stream' })
    res.end(data)
  } catch {
    res.writeHead(404)
    res.end('not found')
  }
}).listen(PORT, '127.0.0.1', () => {
  console.log(`e-Rezept-Spiel: http://127.0.0.1:${PORT}/?kiosk=1`)
})
