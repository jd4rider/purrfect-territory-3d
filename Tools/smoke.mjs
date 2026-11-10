/*
 * Browser smoke test for the exported Web build.
 *
 *   python3 -m http.server 4189 --directory web/play &
 *   node Tools/smoke.mjs http://127.0.0.1:4189/
 *
 * Boots the build in a portrait phone, checks the canvas fills the screen with
 * no bars, taps a real board square through the camera, solves the puzzle
 * through the game's own debug hook, then checks a landscape window shows the
 * rotate gate. Screenshots land in /tmp/pt-shots.
 */
import { createRequire } from 'node:module'
import { mkdirSync } from 'node:fs'

const require = createRequire(import.meta.url)
const { chromium } = require('../../starfall-squadron/node_modules/playwright')

const url = process.argv[2] || 'http://127.0.0.1:4189/'
const failures = []
const errors = []

mkdirSync('/tmp/pt-shots', { recursive: true })

async function stateOf(page) {
  try {
    return await page.evaluate(() => window.__purrfectState || null)
  } catch (error) {
    return null
  }
}

async function waitForState(page, predicate, timeout = 25000) {
  const start = Date.now()
  let last = null
  while (Date.now() - start < timeout) {
    last = await stateOf(page)
    if (last && predicate(last)) return last
    await page.waitForTimeout(200)
  }
  return last
}

async function command(page, value) {
  await page.evaluate((text) => {
    window.__purrfectCommand = text
  }, value)
}

const browser = await chromium.launch()

const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2,
  hasTouch: true,
  isMobile: true,
})
const page = await context.newPage()
page.on('pageerror', (error) => errors.push(`phone: ${error.message}`))
page.on('console', (message) => {
  if (message.type() === 'error') errors.push(`console: ${message.text()}`)
})

await page.goto(url, { waitUntil: 'domcontentloaded' })
await page.waitForSelector('#canvas', { timeout: 60000 })
await page.waitForTimeout(6000)

const layout = await page.evaluate(() => {
  const canvas = document.querySelector('#canvas')
  const rect = canvas ? canvas.getBoundingClientRect() : null
  const gate = document.querySelector('#lja-rotate')
  return {
    canvas: rect ? {
      w: Math.round(rect.width),
      h: Math.round(rect.height),
      top: Math.round(rect.top),
      left: Math.round(rect.left),
    } : null,
    window: { w: innerWidth, h: innerHeight },
    bridge: window.PurrfectTerritory ? window.PurrfectTerritory.version : null,
    client: typeof window.LittleJoyArcade === 'object',
    gate: gate ? getComputedStyle(gate).display !== 'none' : false,
  }
})
console.log('layout', JSON.stringify(layout))
if (!layout.canvas) failures.push('phone: no canvas')
if (!layout.bridge) failures.push('phone: arcade bridge missing')
if (!layout.client) failures.push('phone: arcade client missing')
if (layout.canvas && layout.canvas.h < layout.window.h * 0.99) {
  failures.push(`phone: canvas is ${layout.canvas.h}px tall in a ${layout.window.h}px window`)
}
if (layout.canvas && layout.canvas.w < layout.window.w * 0.99) {
  failures.push(`phone: canvas is ${layout.canvas.w}px wide in a ${layout.window.w}px window`)
}
if (layout.gate) failures.push('phone: the portrait gate must be hidden in portrait')

let state = await waitForState(page, (s) => s.screen === 'title', 25000)
console.log('title state', JSON.stringify(state))
if (!state || state.screen !== 'title') failures.push('phone: title screen did not boot')
if (state && !state.board) failures.push('phone: the title showcase board is missing')
await page.screenshot({ path: '/tmp/pt-shots/title.png' })

await command(page, 'start:campaign:1')
state = await waitForState(page, (s) => s.screen === 'game' && s.board, 25000)
console.log('game state', JSON.stringify(state))
if (!state || state.screen !== 'game') failures.push('phone: could not start level one')
if (state && state.n !== 4) failures.push(`phone: level one should be 4x4 (got ${state.n})`)
await page.screenshot({ path: '/tmp/pt-shots/game.png' })

if (state && state.probe) {
  const { x, y, row, col } = state.probe
  // Probe coordinates come from the 3D camera in the canvas' internal
  // resolution (720x1558); touchscreen.tap expects CSS pixels.
  const canvasRect = await page.evaluate(() => {
    const r = document.querySelector('#canvas').getBoundingClientRect()
    return { left: r.left, top: r.top, width: r.width, height: r.height }
  })
  const tapX = canvasRect.left + (x / state.canvas.w) * canvasRect.width
  const tapY = canvasRect.top + (y / state.canvas.h) * canvasRect.height
  // A single tap only crosses the square out…
  await page.touchscreen.tap(tapX, tapY)
  state = await waitForState(
    page,
    (s) => Array.isArray(s.marks) && Array.isArray(s.marks[row]) && s.marks[row][col] === true,
    8000,
  )
  console.log('after single tap', JSON.stringify(state))
  if (!state || !state.marks[row][col]) {
    failures.push(`phone: one tap on (${row},${col}) at ${x},${y} must cross the square out`)
  }
  if (state && state.cats[row] === col) failures.push('phone: a single tap must not place a cat')
  await page.screenshot({ path: '/tmp/pt-shots/crossed.png' })

  // …and a quick double tap commits the cat.
  await page.waitForTimeout(600)
  const firstTap = Date.now()
  await page.touchscreen.tap(tapX, tapY)
  const secondTap = Date.now()
  await page.touchscreen.tap(tapX, tapY)
  console.log('double tap gap ms', Date.now() - firstTap, 'between taps', secondTap - firstTap)
  state = await waitForState(page, (s) => Array.isArray(s.cats) && s.cats[row] === col, 8000)
  console.log('after double tap', JSON.stringify(state))
  if (!state || state.cats[row] !== col) {
    failures.push(`phone: double-tapping board square (${row},${col}) did not place a cat`)
  }
  await page.screenshot({ path: '/tmp/pt-shots/placed.png' })
}

await command(page, 'hint')
state = await waitForState(page, (s) => s.hints >= 1, 8000)
if (!state || state.hints < 1) failures.push('phone: hint did not register')

await command(page, 'solve')
state = await waitForState(page, (s) => s.solved === true, 15000)
console.log('solved state', JSON.stringify(state))
if (!state || !state.solved) failures.push('phone: solving the board did not finish the level')
await page.waitForTimeout(900)
await page.screenshot({ path: '/tmp/pt-shots/win.png' })

await command(page, 'screen:chapters')
state = await waitForState(page, (s) => s.screen === 'chapters', 8000)
if (!state || state.screen !== 'chapters') failures.push('phone: chapters screen did not open')
await page.waitForTimeout(400)
await page.screenshot({ path: '/tmp/pt-shots/chapters.png' })

const wide = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 })
const widePage = await wide.newPage()
widePage.on('pageerror', (error) => errors.push(`desktop: ${error.message}`))
await widePage.goto(url, { waitUntil: 'domcontentloaded' })
await widePage.waitForSelector('#canvas', { timeout: 60000 })
await widePage.waitForTimeout(6000)
const wideLayout = await widePage.evaluate(() => {
  const canvas = document.querySelector('#canvas')
  const rect = canvas.getBoundingClientRect()
  const gate = document.querySelector('#lja-rotate')
  return {
    w: Math.round(rect.width),
    h: Math.round(rect.height),
    gate: gate ? getComputedStyle(gate).display !== 'none' : false,
    window: { w: innerWidth, h: innerHeight },
  }
})
console.log('desktop layout', JSON.stringify(wideLayout))
if (!wideLayout.gate) failures.push('desktop: a landscape window must show the portrait gate')
if (wideLayout.w < wideLayout.window.w * 0.99 || wideLayout.h < wideLayout.window.h * 0.99) {
  failures.push(`desktop: canvas ${wideLayout.w}x${wideLayout.h} must fill the window`)
}
await widePage.screenshot({ path: '/tmp/pt-shots/desktop.png' })

await browser.close()
console.log('errors', JSON.stringify(errors.slice(0, 12)))
if (errors.length) failures.push(`${errors.length} console/page error(s)`)

if (failures.length) {
  console.error('SMOKE FAILED')
  for (const failure of failures) console.error(' - ' + failure)
  process.exit(1)
}
console.log('SMOKE OK')
