import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// A ticker glance with the machine's vital signs: CPU and GPU temperature
// (read off sysfs hwmon chips by name, so it works on desktop CPUs with
// k10temp and GPUs on amdgpu) plus the busiest GPU's busy-percent. Refreshed
// every few seconds; probably worth it when nothing else is drawing.
Item {
  id: stats

  property bool on: true
  property var statsData: null
  readonly property bool ready: statsData !== null && (statsData.cpuTemp !== null || statsData.gpuTemp !== null || statsData.gpuBusy !== null)
  property int refreshSeconds: 8

  Process {
    id: probe
    command: ["bash", "-c",
      "for d in /sys/class/hwmon/hwmon*; do "
      + "echo \"$(cat \"$d/name\" 2>/dev/null) $(cat \"$d/temp1_input\" 2>/dev/null)\"; done; "
      + "for c in /sys/class/drm/card*/device/gpu_busy_percent; do cat \"$c\" 2>/dev/null; done"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: stats.statsData = Model.hardwareStats(String(text || ""))
    }
  }

  Timer {
    interval: stats.refreshSeconds * 1000
    repeat: true
    running: stats.on
    triggeredOnStart: true
    onTriggered: if (!probe.running) probe.running = true
  }
}
