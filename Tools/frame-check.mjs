/*
 * Reproduces the Little Joy Arcade iframe: the same build, but in a viewport
 * that is shorter than a full phone screen because the portal keeps a header
 * and a footer around it.
 *
 *   node Tools/frame-check.mjs https://littlejoyarcade.site/games/purrfect-territory-3d/
 */
import { createRequire } from 'node:module'
import { mkdirSync } from 'node:fs'

const require = createRequire(import.meta.url)
const { chromium } = require('../../starfall-squadron/node_modules/playwright')

const url = process.argv[2] || 'http://127.0.0.1:4189/'
mkdirSync('/tmp/pt-frame', { recursive: true })

const browser = await chromium.launch()
const sizes = [
  ['tab', 390, 844],
  ['arcade', 390, 660],
  ['arcade-small', 360, 600],
]

for (const [name, width, height] of sizes) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 2, isMobile: true, hasTouch: true })
  const errors = []
  page.on('pageerror', (error) => errors.push(String(error)))
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text())
  })
  await page.goto(url, { waitUntil: 'load' })
  await page.waitForFunction(() => Boolean(window.__purrfectState), null, { timeout: 40000 }).catch(() => {})
  await page.evaluate(() => {
    window.__purrfectCommand = 'start:campaign:1'
  })
  await page.waitForTimeout(4000)
  const info = await page.evaluate(() => {
    const canvas = document.getElementById('canvas')
    const rect = canvas ? canvas.getBoundingClientRect() : null
    return {
      viewport: [window.innerWidth, window.innerHeight],
      dpr: window.devicePixelRatio,
      canvasCss: rect ? [Math.round(rect.width), Math.round(rect.height)] : null,
      canvasPixels: canvas ? [canvas.width, canvas.height] : null,
      state: window.__purrfectState || null,
    }
  })
  console.log(name, width + 'x' + height, JSON.stringify(info))
  if (errors.length) console.log('  errors:', errors.slice(0, 4))
  await page.screenshot({ path: `/tmp/pt-frame/${name}.png` })
	await page.screenshot({
		path: `/tmp/pt-frame/${name}-controls.png`,
		clip: { x: 0, y: Math.max(0, height - 260), width, height: Math.min(260, height) },
	})
  await page.close()
}

await browser.close()
