import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// The agent lane, sourced from the same records the shell's agent-usage
// collectors maintain (`omarchy-opencode-go` and friends write one JSON per
// provider under the agents usage directory every fifteen minutes). The
// island only reads: the bubble shows the rate-limit meters studio the
// provider authenticated against and today's token total, without opening
// or collecting anything on its own.
//
// When no collector wrote a record for the chosen provider yet — plugin off,
// never logged in — the bubble simply stays retired.
Item {
  id: opencode
  property var island: null
  property bool on: true
  // Which provider record the lane reads from the usage directory. Agents
  // are identified by their collector id: "opencode", "opencode-go",
  // "claude", … Change it in the island's settings if you run another one.
  readonly property string usageProvider: String(island && island.setting ? island.setting("opencodeProvider", "opencode") : "opencode")
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
    + "/omarchy/agents/usage"

  onOnChanged: if (on) recordFile.reload()

  // A one-shot delayed reload, like the weather source: the first read can
  // race shell startup and miss a completed record.
  Timer { interval: 2500; running: true; onTriggered: recordFile.reload() }

  FileView {
    id: recordFile
    path: opencode.usageDir + "/" + opencode.usageProvider + ".json"
    watchChanges: true
    printErrors: false
    onLoaded: opencode.apply(JSON.parse(text()))
    onFileChanged: recordFile.reload()
    onLoadFailed: {
      // No record (no collector, nothing logged in): the bubble rests.
      if (opencode.island) opencode.island.opencodeData = null
    }
  }

  function apply(rawJson) {
    if (!island) return
    var d = null
    try { d = rawJson } catch (e) {}
    if (!d || d.ready !== true) {
      island.opencodeData = null
      return
    }
    var limits = []
    var ls = d.limits || []
    for (var i = 0; i < ls.length && limits.length < 3; ++i) {
      var l = ls[i]
      if (!l || typeof l.percent !== "number") continue
      limits.push({
        label: String(l.label || ""),
        pct: Math.max(0, Math.min(1, Number(l.percent))),
        resetsAt: String(l.resetsAt || "")
      })
    }
    island.opencodeData = {
      name: String(d.name || island.usageProvider),
      tier: String(d.tierLabel || ""),
      status: String(d.usageStatusText || ""),
      limits: limits,
      // The lane's ring reads the tightest live meter (they arrive from the
      // widest scope down: rolling, weekly, monthly).
      ring: limits.length > 0 ? limits[0].pct : null,
      resetsAt: limits.length > 0 ? limits[0].resetsAt : "",
      todayPrompts: Number(d.todayPrompts || 0),
      todayTokens: Model.abbrevTokens(d.todayTotalTokens)
    }
  }
}
