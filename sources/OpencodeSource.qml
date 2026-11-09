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

  // Warmth = PRESENCE: the agent has to be open right now. A running
  // opencode binary counts for that lane; a window whose title mentions
  // hermes counts for that one. Every few seconds a single shell probe
  // re-checks; lastWarm keeps the stamps so a poll gap never flickers.
  property var lastWarm: ({})
  readonly property int warmMs: 90000
  property int probeSeconds: 6

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

  Timer {
    interval: opencode.probeSeconds * 1000
    repeat: true
    running: opencode.on
    triggeredOnStart: true
    onTriggered: if (!presenceProbe.running) presenceProbe.running = true
  }

  Process {
    id: presenceProbe
    // Presence = a WINDOW open with the TUI alive in it. Both halves are
    // checked (the compositor's client list for the window, the process
    // list for a live TUI binary that isn't the tailnet's `serve`), so a
    // lingering terminal title or an orphaned TUI can't fake presence
    // after opencode is closed. Hermes is answered by its window only.
    command: ["bash", "-c",
      "hyprctl -j clients 2>/dev/null | python3 -c \"\n"
      + "import json, sys, re, subprocess\n"
      + "try:\n    cs = json.load(sys.stdin)\nexcept Exception:\n    cs = []\n"
      + "if not isinstance(cs, list): cs = []\n"
      + "t = ' '.join((c.get('title') or '') + ' ' + (c.get('class') or '') for c in cs)\n"
      + "if 'hermes' in t.lower(): print('hermes')\n"
      + "ps = subprocess.run(['ps', '-eo', 'args'], capture_output=True).stdout.decode()\n"
      + "tui = [l for l in ps.splitlines() if re.search(r'(^|/)opencode(\\.exe)?$', l.strip())]\n"
      + "if re.search(r'\\bOC[ |]', t) and tui: print('opencode')\n\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; ++i) {
          var id = lines[i].trim()
          if (id !== "") opencode.noteWarm(id)
        }
      }
    }
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
    // Growth is no longer the warm signal — presence is (the 6-second
    // probe above). The record itself stays regardless.
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
      todayTokens: Model.abbrevTokens(d.todayTotalTokens)
    }
  }

  property int revision: 0
  function bumpLane() { revision++ }

  function recountShelf() { return revision }
}
