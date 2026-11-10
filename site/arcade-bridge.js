/*
 * Purrfect Territory 3D — Little Joy Arcade bridge.
 *
 * Load this BEFORE arcade-client.js. It gives the Godot build a small, stable
 * surface (`window.PurrfectTerritory`) and teaches the arcade client where the
 * game's save lives, because Godot stores it in IndexedDB rather than
 * localStorage.
 *
 * Every call is defensive: outside the arcade, or if the client failed to load,
 * the game keeps saving locally and nothing throws.
 */
(function () {
  'use strict'

  var GAME_ID = 'purrfect-territory-3d'
  var SAVE_KEY = GAME_ID + '-save-v1'

  var lastPushed = null
  var restored = null

  function decodeBase64(value) {
    try {
      return decodeURIComponent(escape(window.atob(String(value))))
    } catch (error) {
      return ''
    }
  }

  function arcade() {
    return window.LittleJoyArcade || null
  }

  window.LJA_SNAPSHOT = function () {
    var snapshot = {}
    if (window.__purrfectSave) snapshot[SAVE_KEY] = window.__purrfectSave
    return Object.keys(snapshot).length ? snapshot : null
  }

  window.LJA_APPLY_SNAPSHOT = function (keys) {
    if (!keys || typeof keys !== 'object') return
    if (typeof keys[SAVE_KEY] === 'string' && keys[SAVE_KEY].length > 2) {
      restored = keys[SAVE_KEY]
      window.__purrfectPendingCloud = restored
    }
  }

  function displayName(user) {
    if (!user) return 'Guest'
    if (user.email) return String(user.email).split('@')[0]
    var meta = user.user_metadata || {}
    return meta.display_name || meta.name || 'Guest'
  }

  window.PurrfectTerritory = {
    version: 1,

    pushSave: function (base64) {
      var payload = decodeBase64(base64)
      if (!payload) return
      window.__purrfectSave = payload
      lastPushed = payload
      var client = arcade()
      if (client && typeof client.push === 'function') {
        // The game saves after every solve; the network can wait.
        window.clearTimeout(window.__purrfectPushTimer)
        window.__purrfectPushTimer = window.setTimeout(function () {
          client.push().catch(function () {})
        }, 2500)
      }
    },

    pullSave: function () {
      var value = restored || window.__purrfectPendingCloud || null
      restored = null
      window.__purrfectPendingCloud = null
      return value
    },

    identity: function () {
      var client = arcade()
      var user = client && typeof client.user === 'function' ? client.user() : null
      var state = client && typeof client.status === 'function' ? client.status() : null
      var signedIn = !!(state && state.signedIn)
      return {
        signedIn: signedIn,
        name: displayName(user),
        email: user && user.email ? user.email : '',
        status: !client ? 'local' : signedIn ? 'synced' : 'local',
        gameId: GAME_ID,
        saveKey: SAVE_KEY,
        lastPush: lastPushed ? lastPushed.length : 0
      }
    },

    status: function () {
      var client = arcade()
      if (!client) return 'local'
      var state = client && typeof client.status === 'function' ? client.status() : null
      if (!state || !state.signedIn) return 'local'
      return /cloud|saved/i.test(String(state.text || '')) ? 'synced' : 'syncing'
    },

    unlockAchievement: function (id) {
      var slug = String(id)
      window.__purrfectLastAchievement = slug
      if (window.console && window.console.debug) {
        window.console.debug('[purrfect] achievement', slug)
      }
    },

    track: function (base64) {
      var payload = decodeBase64(base64)
      if (!payload) return
      try {
        var event = JSON.parse(payload)
        if (window.console && window.console.debug) {
          window.console.debug('[purrfect]', event.name, event.props || {})
        }
      } catch (error) {
        /* analytics must never break a puzzle */
      }
    },

    signIn: function () {
      if (location.hash !== '#login') {
        location.hash = '#login'
        location.reload()
      }
    },

    openArcade: function () {
      window.open('https://littlejoyarcade.site/#/games', '_blank', 'noopener')
    }
  }

  window.__purrfectSave = window.__purrfectSave || null

  /* ------------------------------------------------------------------ */
  /* Portrait lock                                                       */
  /* ------------------------------------------------------------------ */
  function portraitGuard() {
    var shown = null
    var overlay = document.getElementById('lja-rotate')
    if (!overlay) {
      overlay = document.createElement('div')
      overlay.id = 'lja-rotate'
      overlay.style.cssText = [
        'position:fixed', 'inset:0', 'z-index:60', 'display:none',
        'align-items:center', 'justify-content:center', 'flex-direction:column',
        'gap:14px', 'background:#0b0710', 'color:#fbf3e6', 'text-align:center',
        'padding:32px', 'font:600 20px system-ui,sans-serif'
      ].join(';')
      overlay.innerHTML = '<div style="font-size:52px">\u21BB</div>' +
        '<div>Rotate to portrait</div>' +
        '<div style="font:400 15px/1.5 system-ui,sans-serif;color:#c3b3c9;max-width:22rem">Purrfect Territory 3D is portrait-only. Turn your phone upright, or make this window taller than it is wide.</div>'
      var host = document.body || document.documentElement
      host.appendChild(overlay)
    }

    var lock = function () {
      try {
        if (screen.orientation && screen.orientation.lock) {
          var attempt = screen.orientation.lock('portrait')
          if (attempt && attempt.catch) attempt.catch(function () {})
        }
      } catch (error) {
        /* Safari and plain http pages do not offer the lock */
      }
    }

    var update = function () {
      var blocked = window.innerWidth > window.innerHeight
      if (blocked === shown) return
      shown = blocked
      overlay.style.display = blocked ? 'flex' : 'none'
      document.documentElement.classList.toggle('pt-sideways', blocked)
    }

    lock()
    window.addEventListener('pointerdown', lock, { passive: true })
    window.addEventListener('click', lock, { passive: true })
    window.addEventListener('resize', update)
    window.addEventListener('orientationchange', update)
    if (screen.orientation && screen.orientation.addEventListener) {
      screen.orientation.addEventListener('change', update)
    }
    update()
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', portraitGuard)
  } else {
    portraitGuard()
  }
})()
