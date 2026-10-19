pragma Singleton
import QtQuick
import Quickshell.Io

// Batch and cache outline measurements; no polling, persistent helper or images.
QtObject {
  id: root
  property var cache: ({})
  property var queued: []
  property var pending: ({})
  property bool unavailable: false

  function rect(family, pixels, text, fallback) {
    if (!text || text.length > 128 || unavailable) return fallback
    var row = [family, Math.max(1, Math.round(pixels)), text]
    var key = JSON.stringify(row)
    if (cache[key] !== undefined) return cache[key]
    if (!pending[key]) {
      pending[key] = true
      queued.push(row)
      flush.restart()
    }
    return fallback
  }
  function startBatch() {
    if (worker.running || queued.length === 0 || unavailable) return
    var batch = queued
    queued = []
    worker.stdinEnabled = true
    worker.running = true
    worker.write(JSON.stringify(batch))
    worker.stdinEnabled = false
  }
  property Timer flush: Timer { interval: 0; onTriggered: root.startBatch() }
  property Process worker: Process {
    command: ["strata-font-ink"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var next = Object.assign({}, root.cache)
          for (var row of JSON.parse(text)) {
            var key = JSON.stringify(row.slice(0, 3))
            next[key] = Qt.rect(row[3], row[4], row[5], row[6])
            delete root.pending[key]
          }
          // Keep only recent entries after extensive theme/font switching.
          var keys = Object.keys(next)
          if (keys.length > 512) for (var key of keys.slice(0, keys.length - 256)) delete next[key]
          root.cache = next
        } catch (error) { root.unavailable = true }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.unavailable = true
      flush.restart()
    }
  }
}
