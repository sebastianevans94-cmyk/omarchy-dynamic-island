import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../IslandModel.js" as Model

// Bluetooth devices connecting and disconnecting: headphones, speakers,
// keyboards, mice, controllers, phones — anything BlueZ knows about. The
// island shows the device, and its battery when the device reports one.
Item {
  id: devices

  property var island: null
  readonly property var list: Bluetooth.devices ? Bluetooth.devices.values : []

  // Devices already connected when the shell starts are not news.
  property bool ready: false
  Timer { interval: 4000; running: true; onTriggered: devices.ready = true }

  function batteryFraction(device) {
    var b = Number(device.battery)
    if (!isFinite(b)) return -1
    return b > 1 ? b / 100 : b
  }

  function announce(device) {
    if (!ready || !island || island.setting("bluetooth", true) === false) return
    var name = String(device.name || device.deviceName || "Bluetooth device")
    if (device.connected) {
      // Battery often arrives a moment after the connection; wait for it.
      // Devices connecting within that window join a queue instead of
      // overwriting each other in the single pending slot.
      queue.push(device)
      if (!batteryWait.running) batteryWait.restart()
    } else {
      island.showHud({
        key: "device",
        layout: "label",
        label: name,
        icon: "󰂲",
        valueText: "Disconnected",
        color: island.fgDim,
        duration: 2200
      })
    }
  }

  property var queue: []

  Timer {
    id: batteryWait
    interval: 1200
    onTriggered: devices.flush()
  }

  // Show one queued connect per pass; the HUD is a single slot, so the
  // next device goes up right after the current one's duration expires.
  // Devices that disconnected while waiting are skipped.
  function flush() {
    var device = queue.shift()
    while (device && !device.connected) device = queue.shift()
    if (!device) return
    var battery = device.batteryAvailable ? devices.batteryFraction(device) : -1
    island.showHud({
      key: "device",
      layout: "label",
      label: String(device.name || device.deviceName || "Bluetooth device"),
      icon: Model.deviceGlyph(device.icon),
      valueText: battery >= 0 ? Math.round(battery * 100) + "%" : "Connected",
      color: battery >= 0 && battery <= 0.2 ? island.urgentColor : island.greenColor,
      duration: 3000
    })
    if (queue.length > 0) {
      nextFlush.interval = 3200
      nextFlush.restart()
    }
  }

  Timer { id: nextFlush; onTriggered: devices.flush() }

  Instantiator {
    model: devices.list
    delegate: Connections {
      required property var modelData
      target: modelData
      function onConnectedChanged() { devices.announce(modelData) }
    }
  }
}
