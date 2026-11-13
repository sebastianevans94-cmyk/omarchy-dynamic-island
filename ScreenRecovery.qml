import QtQuick

// A compositor can close a layer surface when its output disappears without
// destroying the QML panel. Keep its state, but unmap until the output settles
// and then show it again. Merely rebinding window.screen does not reopen it.
Item {
  id: root

  required property var window
  required property var targetScreen
  property bool remapping: false
  readonly property bool ready: targetScreen !== null && !remapping

  visible: false

  function recover() {
    // A compositor can close the surface repeatedly while an output is
    // settling (onClosed → recover → remap → close …). The first few
    // retries settle in 200 ms; after that each settle backs off to 2 s,
    // so churn cannot turn into a tight remap loop. recoveryCount decays
    // over the period decayTimer so a healthy screen returns to fast.
    recoveryCount++
    remapping = true
    settleTimer.interval = recoveryCount > 5 ? 2000 : 200
    settleTimer.restart()
  }

  property int recoveryCount: 0

  onTargetScreenChanged: recover()

  Timer {
    id: settleTimer
    onTriggered: root.remapping = false
  }

  Timer {
    id: decayTimer
    interval: 30000
    repeat: true
    running: root.recoveryCount > 0
    onTriggered: root.recoveryCount = Math.max(0, root.recoveryCount - 1)
  }

  Connections {
    target: root.window
    // Reopening synchronously would race Quickshell's close/teardown path.
    function onClosed() { Qt.callLater(root.recover) }
  }

  Connections {
    target: root.targetScreen
    // A retained monitor can move when another display is unplugged. Remap
    // then too, so Hyprland places the layer surface at the new origin.
    function onXChanged() { root.recover() }
    function onYChanged() { root.recover() }
  }
}
