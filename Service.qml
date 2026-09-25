import QtQuick
import Quickshell
import Quickshell.Io
import "TrayModel.js" as TrayModel

// The tray's companion service. Omarchy injects the detached widget catalogue
// here, and this is the tray's ONLY layout writer: the bar-widget facade
// refuses layout mutation for non-bar plugins, so every move between the bar
// and the drawer is applied here, straight to shell.json.
//
// Callers pass plain values only: the tray widget may be destroyed by the
// very rebuild its drop triggers, so nothing here may call back into it.
QtObject {
  id: service
  property var barWidgetRegistry: null

  // Pull a bar widget into the tray's drawer; `order` is the drawer's new
  // token order (null keeps the current one).
  function capture(trayId, widgetId, order) {
    enqueue(function(config) { return TrayModel.captureIntoTray(config, trayId, widgetId, order) })
  }

  // Put a hosted widget back into the bar layout, before `beforeName` in
  // `region` ("" = end of region).
  function release(trayId, widgetId, region, beforeName) {
    enqueue(function(config) { return TrayModel.dragOutOfTray(config, trayId, widgetId, region, beforeName) })
  }

  // Writes are asynchronous, and a drag-in races the bar's own write for the
  // same gesture (it moves the widget next to the tray). Rather than guess
  // the order, each edit is idempotent and is re-applied to every version of
  // shell.json seen during a short settle window, so the last write always
  // carries it.
  property var pending: []

  function enqueue(edit) {
    pending = pending.concat([edit])
    settle.restart()
    Qt.callLater(service.reloadConfig)
  }

  function reloadConfig() {
    shellConfigFile.reload()
  }

  function apply() {
    if (!pending.length) return
    var config
    try {
      config = JSON.parse(shellConfigFile.text())
    } catch (e) {
      return // mid-write; the next change notification retries
    }
    var changed = false
    for (var i = 0; i < pending.length; i++) changed = pending[i](config) || changed
    if (changed) shellConfigFile.setText(JSON.stringify(config, null, 2) + "\n")
  }

  property Timer settle: Timer {
    interval: 1500
    onTriggered: service.pending = []
  }

  property FileView shellConfigFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: if (service.pending.length) reload()
    onLoaded: service.apply()
    onLoadFailed: function(error) {
      console.warn("Tray: could not load shell.json:", error)
    }
  }
}
