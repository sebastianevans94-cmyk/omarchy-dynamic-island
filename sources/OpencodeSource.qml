import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// The agent lane, sourced from the same records the shell's agent-usage
// collectors maintain (one JSON per provider under the agents usage
// directory, refreshed every fifteen minutes — or sooner on their own
// retry cadence). The island only reads; when a provider has no record,
// or none has authenticated meters, the bubble simply rests.
//
// Robust by design:
//   * every *.json in the directory is watched, not one file — opencode,
//     hermes, local, whatever their collectors publish;
//   * a bad or half-written read keeps the provider's LAST GOOD record
//     (sticky across the collector's rewrite races — this is what kept the
//     bubble from vanishing every time opencode closed and reopened);
//   * a provider disappears from the data only when its file asks for it
//     for good (record rewrites itself unusable, or is deleted).
Item {
  id: opencode

  property var island: null
  property bool on: true
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
    + "/omarchy/agents/usage"

  // ---
  // Discovery: the record ids on disk, rescanned now and then. Cheap even
  // at this cadence, because find is the only subprocess.
  // ---
  property var providerIds: []

  Timer {
    interval: 12000
    repeat: true
    running: opencode.on
    triggeredOnStart: true
    onTriggered: if (!listProc.running) listProc.running = true
  }

  Process {
    id: listProc
    command: ["/usr/bin/find", opencode.usageDir, "-maxdepth", "1", "-name", "*.json", "-printf", "%f\n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var ids = []
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
          var n = lines[i].trim()
          if (n.slice(-5) === ".json") ids.push(n.slice(0, -5))
        }
        ids.sort()
        // Same list, same objects: an identical assignment would tear down
        // every FileView for nothing.
        if (JSON.stringify(ids) === JSON.stringify(opencode.providerIds)) return
        opencode.providerIds = ids
      }
    }
  }

  Instantiator {
    id: watchers
    model: opencode.providerIds

    FileView {
      required property string modelData
      readonly property string providerId: modelData
      path: opencode.usageDir + "/" + providerId + ".json"
      watchChanges: true
      printErrors: false

      onLoaded: opencode.absorb(providerId, text())
      onFileChanged: if (opencode.on) this.reload()
      // A failed read (file rewritten mid-flight, briefly missing) leaves
      // the provider's last GOOD record standing, rather than blanking the
      // lane. One more is never forced: the next write heals it.
      onLoadFailed: { /* sticky */ }
    }

    onObjectAdded: opencode.recount()
    onObjectRemoved: opencode.recount()
  }

  // providerId -> last good record
  property var shelf: ({})

  // Warmth: agents in use lately. The collectors write every ~15 minutes, so
  // warmth reads two ways — a record whose usage GREW at its last rewrite,
  // and, for the local opencode database, opencode-cost's own view of the
  // session update time. lastWarm keeps epoch stamps; the island drops the
  // bubble when every stamp has gone cold.
  property var lastWarm: ({})
  readonly property int warmMs: 25 * 60 * 1000

  function warmIds() {
    var out = []
    var now = Date.now()
    for (var id in lastWarm)
      if (now - lastWarm[id] < warmMs) out.push(id)
    return out
  }

  function noteWarm(providerId) {
    lastWarm[providerId] = Date.now()
    bumpLane()
  }

  function absorb(providerId, raw) {
    var d = null
    try { d = JSON.parse(String(raw || "")) } catch (e) {
      // The collector is mid-write: keep the shelf as it stands.
      return
    }
    var rec = shapeRecord(d)
    if (rec === null) {
      // The record rewrote itself unusable, or is genuinely logged out:
      // letting it go is the point of this branch (sticky, not a fork
      // file). Everything else keeps its shelf.
      if (shelf[providerId] !== undefined) {
        delete shelf[providerId]
        bumpLane()
      }
      return
    }
    var prev = shelf[providerId]
    // Growth = recent use: today prompts/tokens went up since the last
    // rewrite of this record.
    if (prev && (Number(rec.todayPrompts) > Number(prev.todayPrompts || 0)
        || Number(rec.todayTokensNum) > Number(prev.todayTokensNum || 0)))
      noteWarm(providerId)
    shelf[providerId] = rec
    bumpLane()
  }

  function recount() {
    // A watcher left (file deleted): its shelf entry can't refresh anymore.
    for (var id in shelf)
      if (providerIds.indexOf(id) === -1) { delete shelf[id]; bumpLane(); return }
    bumpLane()
  }

  function shapeRecord(d) {
    if (!d || typeof d !== "object") return null
    var hasUse = (d.limits || []).length > 0 || Number(d.todayPrompts || 0) > 0
    if (!(d.ready === true || d.ready === undefined) && !hasUse) return null
    if (String(d.ready || "") === "" && !hasUse) return null
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
    var today = Number(d.todayPrompts || 0)
    if (limits.length === 0 && today === 0) return null
    return {
      name: String(d.name || ""),
      tier: String(d.tierLabel || ""),
      status: String(d.usageStatusText || ""),
      limits: limits,
      todayPrompts: today,
      todayTokens: Model.abbrevTokens(d.todayTotalTokens),
      todayTokensNum: Number(d.todayTotalTokens || 0)
    }
  }

  // The local opencode database knows "now" down to the minute, far
  // tighter than the fifteen-minute collector cadence, so the local
  // provider warms up the second a session touches it.
  readonly property string warmProbeProvider: String(island && island.setting ? island.setting("opencodeProvider", "opencode") : "opencode")
  Timer {
    interval: 30000
    repeat: true
    running: opencode.on
    triggeredOnStart: true
    onTriggered: if (!costProbe.running) costProbe.running = true
  }
  Process {
    id: costProbe
    command: ["opencode-cost", "current", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var s = null
        try {
          var d = JSON.parse(String(text || "{}"))
          s = d.session
        } catch (e) {}
        if (s && Number(s.time_updated || 0) > 0
            && Date.now() - Number(s.time_updated) < 150000)
          opencode.noteWarm(opencode.warmProbeProvider)
      }
    }
  }

  property int revision: 0
  function bumpLane() { revision++ }

  function recountShelf() { return revision }
}
