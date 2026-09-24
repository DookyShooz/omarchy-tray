import QtQuick
import Quickshell
import Quickshell.Io
import "TrayModel.js" as TrayModel

// Omarchy injects a detached widget catalogue into third-party services.
// The bar-widget facade cannot mutate the layout on Omarchy 4, so this service
// also performs the tray's drag-in writes after the bar finishes its drop.
QtObject {
  id: service
  property var barWidgetRegistry: null
  property var pendingCaptures: []

  function captureWidget(trayId, widgetId, order) {
    pendingCaptures = pendingCaptures.concat([{ trayId: trayId, widgetId: widgetId, order: order }])
    shellConfigFile.reload()
  }

  function flushCaptures() {
    if (!pendingCaptures.length) return
    var config
    try {
      config = JSON.parse(shellConfigFile.text())
    } catch (e) {
      console.warn("Tray: could not read shell.json for widget capture:", e)
      pendingCaptures = []
      return
    }
    var captures = pendingCaptures
    pendingCaptures = []
    var changed = false
    for (var i = 0; i < captures.length; i++) {
      var drop = captures[i]
      changed = TrayModel.captureIntoTray(config, drop.trayId, drop.widgetId, drop.order) || changed
    }
    if (changed) shellConfigFile.setText(JSON.stringify(config, null, 2) + "\n")
  }

  property FileView shellConfigFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    atomicWrites: true
    printErrors: false
    onLoaded: service.flushCaptures()
    onLoadFailed: function(error) {
      console.warn("Tray: could not load shell.json for widget capture:", error)
      service.pendingCaptures = []
    }
  }
}
