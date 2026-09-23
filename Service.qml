import QtQuick

// Omarchy injects a detached, read-only widget catalogue into third-party
// service entry points. Tray.qml retrieves this service through its scoped
// shell facade so hosted bar widgets continue to render on Omarchy 4+.
QtObject {
  property var barWidgetRegistry: null
}
