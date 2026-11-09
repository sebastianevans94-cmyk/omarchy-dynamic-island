import QtQuick
import Quickshell
import Quickshell.Io
import "../IslandModel.js" as Model

// Weather for the island: the same two sources and the same location file
// the shell's weather panel uses, so both stay in sync. With coordinates
// one short open-meteo call (current + 3-day) answers everything; without
// them, wttr.in's own IP lookup answers first for now and names the place,
// which open-meteo then answers for following refreshes.
Item {
  id: weather

  property bool active: true
  property var weatherData: null            // normalized, see Model.weatherFrom*
  readonly property bool ready: weatherData !== null
  property string status: ""         // "", "fetching", "error"
  property int refreshMinutes: 15

  // The configured place: sha...
  property var configured: ({ name: "", latitude: null, longitude: null })
  // Last auto-detected place (wttr's report names one even with no config).
  property var detected: null

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"

  // How we ask right now: coordinates when known (configured or detected),
  // else the empty wttr query, which answers from this network's location.
  readonly property bool hasCoordinates: !!lat && !!lon
  readonly property string lat: configured.latitude !== null ? String(configured.latitude)
    : (detected && detected.latitude ? String(detected.latitude) : "")
  readonly property string lon: configured.longitude !== null ? String(configured.longitude)
    : (detected && detected.longitude ? String(detected.longitude) : "")
  // The place the label names: whatever the location file holds, or the
  // wttr-detected place name.
  readonly property string label: configured.name !== "" ? configured.name
    : (detected && detected.name ? detected.name : "")

  onActiveChanged: if (active) refresh()

  FileView {
    id: locationFile
    path: weather.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: locationFile.reload()
    onLoaded: {
      weather.configured = Model.weatherParseLocation(text())
      weather.refresh()
    }
    onLoadFailed: {
      weather.configured = { name: "", latitude: null, longitude: null }
      weather.refresh()
    }
  }

  // The first read can race shell startup (the panel self-corrects the same
  // way with a delayed reload; a no-op if the first read was fine).
  Timer {
    interval: 1500
    running: true
    onTriggered: locationFile.reload()
  }

  function refresh() {
    if (!active || meteoProc.running || wttrProc.running) return
    if (latestQuery !== null && latestQuery === locationQuery()) return
    latestQuery = locationQuery()
    status = "fetching"
    if (hasCoordinates) askOpenMeteo()
    else askWttr()
  }

  function locationQuery() {
    return hasCoordinates ? lat + "," + lon : ""
  }

  function askOpenMeteo() {
    meteoProc.command = ["curl", "-fsS", "--max-time", "10",
      "https://api.open-meteo.com/v1/forecast"
      + "?latitude=" + encodeURIComponent(lat)
      + "&longitude=" + encodeURIComponent(lon)
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
      + "&hourly=precipitation_probability"
      + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
      + "&forecast_days=3&timezone=auto"]
    meteoProc.running = true
  }

  function askWttr() {
    var nameQuery = encodeURIComponent(String(configured.name || "").replace(/^\s+|\s+$/g, ""))
    // No coordinates anywhere: wttr resolves this network's place itself.
    wttrProc.command = ["curl", "-fsS", "--max-time", "12",
      "https://wttr.in/" + nameQuery + "?format=j1"]
    wttrProc.running = true
  }

  Process {
    id: meteoProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) { weather.stallRetry(); return }
        try {
          weather.weatherData = Model.weatherFromOpenMeteo(JSON.parse(raw), weather.label)
          weather.status = ""
        } catch (e) { weather.stallRetry() }
      }
    }
  }

  Process {
    id: wttrProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) { weather.stallRetry(); return }
        try {
          var parsed = JSON.parse(raw)
          var w = Model.weatherFromWttr(parsed, weather.label)
          // wttr's IP answer names the place: seed the detection so later
          // refreshes use the fast open-meteo call with those coordinates.
          var area = parsed.nearest_area && parsed.nearest_area[0] ? parsed.nearest_area[0] : null
          if (!weather.configured.latitude && area) {
            var num = function(v) { var n = parseFloat(String(v)); return isNaN(n) ? null : n }
            weather.detected = { name: w ? w.label : "",
              latitude: area.latitude !== undefined ? num(area.latitude) : null,
              longitude: area.longitude !== undefined ? num(area.longitude) : null }
          }
          weather.weatherData = w
          weather.status = ""
        } catch (e) { weather.stallRetry() }
      }
    }
  }

  // A stalled or broken answer: retry shortly rather than sitting on the
  // old data, but a few failures in a row go back to the refresh timer.
  property int failStreak: 0
  function stallRetry() {
    failStreak++
    if (failStreak < 3) {
      status = "fetching"
      stallTimer.restart()
    } else {
      status = weatherData !== null ? "" : "error"
    }
  }

  Timer { id: stallTimer; interval: 90000; onTriggered: { weather.latestQuery = null; weather.refresh() } }

  Timer {
    id: refreshTimer
    interval: weather.refreshMinutes * 60000
    repeat: true
    running: weather.active
    triggeredOnStart: true
    onTriggered: weather.refresh()
  }

  // null = nothing fetched yet; "" is a real answer for the auto/IP case.
  property var latestQuery: null

  // A configured place also means the query changed: refetch right away.
  onLatChanged: latestQuery = ""
  onLonChanged: latestQuery = ""
  onStateChanged: if (state !== "") latestQuery = ""
}
