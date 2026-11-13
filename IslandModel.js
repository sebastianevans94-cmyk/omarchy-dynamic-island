.pragma library

// Pure helpers for the island. No QML types in here so the logic can be read
// (and reasoned about) without the scene around it.

// Base geometry for each view, in unscaled pixels. The island springs between
// these; `r` is the corner radius, which for the compact views is half the
// height so the shape stays a true capsule.
var sizes = {
  "idle":          { w: 210, h: 32, r: 16 },
  "idle-hover":    { w: 222, h: 34, r: 17 },
  "hidden":        { w: 0,   h: 32, r: 16 },
  "media":         { w: 300, h: 32, r: 16 },
  "recording":     { w: 232, h: 32, r: 16 },
  "mic":           { w: 214, h: 32, r: 16 },
  "hud-progress":  { w: 310, h: 36, r: 18 },
  "hud-label":     { w: 310, h: 36, r: 18 },
  "hud-track":     { w: 368, h: 66, r: 28 },
  "hud-toast":     { w: 368, h: 66, r: 28 },
  "media-expanded": { w: 404, h: 186, r: 42 },
  "recording-expanded": { w: 392, h: 76, r: 34 },
  "recording-media-expanded": { w: 404, h: 145, r: 40 },
  "idle-expanded": { w: 464, h: 170, r: 40 },
  "weather-expanded": { w: 424, h: 232, r: 40 },
  "notification":  { w: 404, h: 78, r: 34 },
  "inbox":         { w: 200, h: 32, r: 16 },
  "timer":         { w: 236, h: 32, r: 16 },
  "stopwatch":     { w: 236, h: 32, r: 16 },
  "activity":      { w: 256, h: 32, r: 16 },
  "calendar":      { w: 300, h: 32, r: 16 },
  "clock-expanded": { w: 380, h: 132, r: 40 },
  "activity-expanded": { w: 392, h: 104, r: 38 },
  "calendar-expanded": { w: 500, h: 262, r: 40 },
  "notification-actions": { w: 404, h: 118, r: 38 }
}

// Compact activities in priority order. The first one present owns the pill;
// the second one, if any, gets the detached bubble on the right.
var activityOrder = ["recording", "timer", "activity", "media", "stopwatch", "calendar", "mic", "inbox"]

function activities(flags) {
  flags = flags || {}
  var out = []
  for (var i = 0; i < activityOrder.length; i++)
    if (flags[activityOrder[i]]) out.push(activityOrder[i])
  return out
}

// Which view the island shows. Transient HUDs win over everything except an
// island the user deliberately opened, since a volume tick while reading the
// expanded player should not throw the player away.
function viewFor(state) {
  if (state.userExpanded && state.inboxOpen) return "inbox-expanded"
  if (state.userExpanded && state.outputsOpen) return "outputs-expanded"
  if (state.userExpanded && state.calendarOpen) return "calendar-expanded"
  // The weather pane rides below recording; recording still takes the top
  // of an opened island so it can be stopped from there.
  if (state.userExpanded && state.weatherOpen && !state.recording) return "weather-expanded"
  // Music owns the opened island only when it was opened for the music:
  // the drop-down's now-playing row sets focus explicitly. Plain pill
  // clicks keep showing the basic page, whose row leads to the player.
  if (state.userExpanded) {
    // Recording takes the top of an opened island so it can be stopped from
    // there; music, if any, rides along underneath.
    if (state.recording) return state.hasMedia ? "recording-media-expanded" : "recording-expanded"
    // Otherwise open whatever was clicked: the pill's activity, or the
    // bubble's when the bubble was the thing clicked.
    var focus = state.focus || state.primary
    if (focus === "timer" || focus === "stopwatch") return "clock-expanded"
    if (focus === "activity") return "activity-expanded"
    if (focus === "calendar") return "calendar-expanded"
    // Explicitly chosen music only: state.focus is the click's answer;
    // primary is just what happens to be live right now.
    if (state.focus === "media" && state.hasMedia) return "media-expanded"
    // Everything else — including with music playing — stays on the basic
    // page, whose now-playing row hands over to the player pane.
    return "idle-expanded"
  }
  if (state.hud && state.hud.layout === "progress") return "hud-progress"
  if (state.notification) return state.notificationActions ? "notification-actions" : "notification"
  if (state.hud) return state.hud.layout === "track" ? "hud-track"
    : (state.hud.layout === "toast" ? "hud-toast" : "hud-label")
  if (state.primary) return state.primary
  if (state.idleHidden) return "hidden"
  return state.hovered ? "idle-hover" : "idle"
}

// The opened inbox grows with its contents, up to four rows (then scrolls).
var inboxRowHeight = 58
var inboxRowGap = 6

function inboxSize(count) {
  if (count <= 0) return { w: 420, h: 72, r: 32 }
  var rows = Math.min(4, count)
  return { w: 420, h: 14 + rows * inboxRowHeight + (rows - 1) * inboxRowGap + 10 + 30 + 14, r: 36 }
}

// Output picker: a header plus one row per audio output.
function outputsSize(count) {
  var rows = Math.max(1, Math.min(6, count))
  return { w: 392, h: 16 + 22 + 8 + rows * 40 + (rows - 1) * 4 + 16, r: 36 }
}

// Views that sit on the notch itself; with a measured notch they grow to
// clear the camera cutout with room for content on both sides.
var compactViews = ["idle", "idle-hover", "media", "recording", "mic", "inbox", "timer",
                    "stopwatch", "activity", "calendar"]

function sizeFor(view, counts, notch) {
  var base
  if (view === "inbox-expanded") base = inboxSize(counts && counts.inbox || 0)
  else if (view === "outputs-expanded") base = outputsSize(counts && counts.outputs || 0)
  else base = sizes[view] || sizes["idle"]
  if (!notch || !(notch.w > 0) || compactViews.indexOf(view) === -1) return base
  var h = Math.max(base.h, notch.h > 0 ? notch.h : base.h)
  if (view === "idle" || view === "idle-hover") {
    var r = notch.r > 0 ? notch.r : h / 2
    return { w: notch.w + (view === "idle-hover" ? 12 : 0), h: h, r: Math.min(r, h / 2) }
  }
  // 60px of content either side of the cutout.
  return { w: Math.max(base.w, notch.w + 120), h: h, r: h / 2 }
}

// "25", "25m", "90s", "1h30m", "1:30" (m:s) or "1:30:00" (h:m:s) -> seconds.
function parseDuration(text) {
  var t = String(text || "").trim().toLowerCase()
  if (!t) return 0
  if (/^\d+$/.test(t)) return parseInt(t, 10) * 60
  if (/^\d+(:\d{1,2}){1,2}$/.test(t)) {
    var parts = t.split(":").map(function(p) { return parseInt(p, 10) })
    return parts.length === 2 ? parts[0] * 60 + parts[1] : parts[0] * 3600 + parts[1] * 60 + parts[2]
  }
  var total = 0
  var matched = false
  var re = /(\d+(?:\.\d+)?)\s*(h|hr|hours?|m|min|mins|minutes?|s|sec|secs|seconds?)/g
  var m
  while ((m = re.exec(t)) !== null) {
    matched = true
    var n = parseFloat(m[1])
    var u = m[2].charAt(0)
    total += u === "h" ? n * 3600 : (u === "m" ? n * 60 : n)
  }
  return matched ? Math.round(total) : 0
}

// 272.4s -> "4:32"; with tenths -> "4:32.4". Hours when needed. Tenths use
// integer math: a float 0.7 is stored as 0.6999…, and floor((s-whole)*10)
// then reads one tenth low for ~10% of values.
function formatClock(seconds, tenths) {
  var s = Math.max(0, Number(seconds) || 0)
  var t10 = Math.round(s * 10)
  var whole = Math.floor(t10 / 10)
  var text = formatTime(whole)
  if (tenths) text += "." + (t10 % 10)
  return text
}

// Bluetooth device icon names (freedesktop) -> Nerd Font glyph.
function deviceGlyph(icon) {
  var i = String(icon || "").toLowerCase()
  if (i.indexOf("headset") !== -1 || i.indexOf("headphone") !== -1) return "󰋋"
  if (i.indexOf("speaker") !== -1 || i.indexOf("audio") !== -1) return "󰓃"
  if (i.indexOf("keyboard") !== -1) return "󰌌"
  if (i.indexOf("mouse") !== -1 || i.indexOf("tablet") !== -1) return "󰍽"
  if (i.indexOf("gaming") !== -1 || i.indexOf("joystick") !== -1) return "󰊴"
  if (i.indexOf("phone") !== -1) return "󰄜"
  if (i.indexOf("watch") !== -1) return "󰖉"
  if (i.indexOf("computer") !== -1) return "󰌢"
  return "󰂱"
}

// ---------------------------------------------------------------- calendar
// A small iCalendar reader: enough for "what is my next meeting". Handles
// folded lines, UTC / floating / TZID times (TZID times are read as local
// time), all-day events, and DAILY/WEEKLY recurrence with INTERVAL, BYDAY,
// COUNT, UNTIL and EXDATE. Other recurrences show their first occurrence.

function icsDate(value) {
  var v = String(value || "").trim()
  var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(v)
  if (!m) return null
  var y = +m[1], mo = +m[2] - 1, d = +m[3]
  if (m[4] === undefined) return { time: new Date(y, mo, d).getTime(), allDay: true }
  var h = +m[4], mi = +m[5], se = +m[6]
  var time = m[7] ? Date.UTC(y, mo, d, h, mi, se) : new Date(y, mo, d, h, mi, se).getTime()
  return { time: time, allDay: false }
}

function icsUnescape(v) {
  return String(v || "").replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim()
}

var weekdayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

function occurrence(ev, start, duration) {
  return { title: ev.title, start: start, end: start + duration, allDay: ev.allDay, url: ev.url, location: ev.location }
}

// The link worth opening for an event: its URL, else the first meeting link
// in its location or description (Meet, Zoom, Teams all put one there).
function firstLink(text) {
  var m = /https?:\/\/[^\s<>"'\\]+/.exec(String(text || ""))
  return m ? m[0] : ""
}

function expandEvent(ev, from, to) {
  var out = []
  if (!ev.rrule) {
    if (ev.end > from && ev.start < to) out.push(ev)
    return out
  }
  var rule = {}
  ev.rrule.split(";").forEach(function(part) {
    var kv = part.split("=")
    if (kv.length === 2) rule[kv[0].toUpperCase()] = kv[1]
  })
  var freq = rule.FREQ
  // Malformed INTERVAL/COUNT must not become NaN: NaN poisons the modulo
  // and count comparisons, and the event silently loses every occurrence.
  var iv = parseInt(rule.INTERVAL || "1", 10)
  var interval = isFinite(iv) && iv >= 1 ? iv : 1
  var until = rule.UNTIL ? (icsDate(rule.UNTIL) || {}).time : Infinity
  var cv = rule.COUNT ? parseInt(rule.COUNT, 10) : Infinity
  var count = isFinite(cv) && cv >= 1 ? cv : Infinity
  var duration = ev.end - ev.start
  var first = new Date(ev.start)
  if (freq === "MONTHLY" || freq === "YEARLY") {
    // Same date every month / year (the common cases: rent, birthdays).
    var step = freq === "MONTHLY" ? interval : interval * 12
    for (var k = 0, made = 0; k < 2400 && made < count; k++) {
      var occ = new Date(first.getFullYear(), first.getMonth() + k * step, first.getDate(),
                         first.getHours(), first.getMinutes(), first.getSeconds())
      if (occ.getDate() !== first.getDate()) continue
      var ot = occ.getTime()
      if (ot > until || ot > to) break
      made += 1
      if (ev.exdates.indexOf(ot) !== -1) continue
      if (ot + duration > from) out.push(occurrence(ev, ot, duration))
    }
    return out
  }
  if (freq !== "DAILY" && freq !== "WEEKLY") {
    if (ev.end > from && ev.start < to) out.push(ev)
    return out
  }
  var days = freq === "WEEKLY" && rule.BYDAY
    ? rule.BYDAY.split(",").map(function(d) { return weekdayCodes.indexOf(d.replace(/^[+-]?\d+/, "")) })
        .filter(function(d) { return d >= 0 })
    : [first.getDay()]
  var n = 0
  // Walk day by day (bounded): cheap for a week-ahead window.
  for (var i = 0; i < 3700 && n < count; i++) {
    var day = new Date(first.getFullYear(), first.getMonth(), first.getDate() + i,
                       first.getHours(), first.getMinutes(), first.getSeconds())
    var t = day.getTime()
    if (t > until || t > to) break
    var weeks = Math.floor(i / 7)
    var ok = freq === "DAILY" ? i % interval === 0
      : (weeks % interval === 0 && days.indexOf(day.getDay()) !== -1)
    if (!ok) continue
    n += 1
    if (ev.exdates.indexOf(t) !== -1) continue
    if (t + duration > from) out.push(occurrence(ev, t, duration))
  }
  return out
}

// Events overlapping [from, to), soonest first. All-day ones only when
// asked for (the month view wants them, "next meeting" does not).
function parseIcs(text, from, to, includeAllDay) {
  var lines = String(text || "").replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "").split(/\r?\n/)
  var events = []
  var ev = null
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line === "BEGIN:VEVENT") { ev = { title: "", start: 0, end: 0, allDay: false, rrule: "", exdates: [], cancelled: false, url: "", location: "", description: "" }; continue }
    if (line === "END:VEVENT") {
      if (ev && ev.start && !ev.cancelled) {
        if (!ev.end) ev.end = ev.start + (ev.allDay ? 86400000 : 3600000)
        if (!ev.url) ev.url = firstLink(ev.location) || firstLink(ev.description)
        events = events.concat(expandEvent(ev, from, to))
      }
      ev = null
      continue
    }
    if (!ev) continue
    // Alarms carry their own DESCRIPTION/SUMMARY; without this skip the
    // alarm's text replaces the event's and its links hijack the click.
    if (line === "BEGIN:VALARM") { ev.alarm = true; continue }
    if (line === "END:VALARM") { ev.alarm = false; continue }
    if (ev.alarm) continue
    var colon = line.indexOf(":")
    if (colon < 0) continue
    var name = line.substring(0, colon).split(";")[0].toUpperCase()
    var value = line.substring(colon + 1)
    if (name === "SUMMARY") ev.title = icsUnescape(value)
    else if (name === "DTSTART") { var ds = icsDate(value); if (ds) { ev.start = ds.time; ev.allDay = ds.allDay } }
    else if (name === "DTEND") { var de = icsDate(value); if (de) ev.end = de.time }
    else if (name === "RRULE") ev.rrule = value
    else if (name === "URL") ev.url = value.trim()
    else if (name === "LOCATION") ev.location = icsUnescape(value)
    else if (name === "DESCRIPTION") ev.description = icsUnescape(value)
    else if (name === "X-GOOGLE-CONFERENCE") ev.url = ev.url || value.trim()
    else if (name === "EXDATE") value.split(",").forEach(function(v) { var x = icsDate(v); if (x) ev.exdates.push(x.time) })
    else if (name === "STATUS" && value.toUpperCase() === "CANCELLED") ev.cancelled = true
  }
  return events.filter(function(e) { return includeAllDay || !e.allDay })
    .sort(function(a, b) { return a.start - b.start })
}

function dayKey(time) {
  var d = new Date(time)
  return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate()
}

// Map of dayKey -> events for every day an event touches.
function eventsByDay(events) {
  var map = {}
  for (var i = 0; i < events.length; i++) {
    var e = events[i]
    var d = new Date(e.start)
    var day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    var last = e.end - 1
    for (var n = 0; n < 62 && day.getTime() <= last; n++) {
      var key = dayKey(day.getTime())
      if (!map[key]) map[key] = []
      map[key].push(e)
      day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
    }
  }
  return map
}

// Google's public holiday calendars, by ISO country code (each one checked
// to answer). Name is what the picker shows.
var holidayCalendars = [
  { code: "IN", name: "India", id: "indian" },
  { code: "US", name: "United States", id: "usa" },
  { code: "GB", name: "United Kingdom", id: "uk" },
  { code: "CA", name: "Canada", id: "canadian" },
  { code: "AU", name: "Australia", id: "australian" },
  { code: "NZ", name: "New Zealand", id: "new_zealand" },
  { code: "IE", name: "Ireland", id: "irish" },
  { code: "DE", name: "Germany", id: "german" },
  { code: "FR", name: "France", id: "french" },
  { code: "ES", name: "Spain", id: "spain" },
  { code: "IT", name: "Italy", id: "italian" },
  { code: "NL", name: "Netherlands", id: "dutch" },
  { code: "JP", name: "Japan", id: "japanese" },
  { code: "KR", name: "South Korea", id: "south_korea" },
  { code: "SG", name: "Singapore", id: "singapore" },
  { code: "MY", name: "Malaysia", id: "malaysia" },
  { code: "ID", name: "Indonesia", id: "indonesian" },
  { code: "PH", name: "Philippines", id: "philippines" },
  { code: "AE", name: "UAE", id: "ae" },
  { code: "PK", name: "Pakistan", id: "pk" },
  { code: "BD", name: "Bangladesh", id: "bd" },
  { code: "LK", name: "Sri Lanka", id: "lk" },
  { code: "BR", name: "Brazil", id: "brazilian" },
  { code: "MX", name: "Mexico", id: "mexican" }
]

function holidayCalendar(code) {
  var c = String(code || "").toUpperCase()
  for (var i = 0; i < holidayCalendars.length; i++)
    if (holidayCalendars[i].code === c) return holidayCalendars[i]
  return null
}

function holidayUrl(code) {
  var h = holidayCalendar(code)
  return h ? "https://calendar.google.com/calendar/ical/en." + h.id + "%23holiday%40group.v.calendar.google.com/public/basic.ics" : ""
}

// "in 12m", "in 1h 5m", "now"
function untilText(start, now) {
  var s = Math.round((start - now) / 1000)
  if (s <= 30) return "now"
  var m = Math.ceil(s / 60)
  if (m < 60) return "in " + m + "m"
  return "in " + Math.floor(m / 60) + "h" + (m % 60 ? " " + (m % 60) + "m" : "")
}

// "now", "5m", "2h", "3d" — how long ago a notification arrived.
function ago(time, now) {
  var s = Math.max(0, Math.floor((Number(now || Date.now()) - Number(time)) / 1000))
  if (s < 60) return "now"
  if (s < 3600) return Math.floor(s / 60) + "m"
  if (s < 86400) return Math.floor(s / 3600) + "h"
  return Math.floor(s / 86400) + "d"
}

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function formatTime(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0))
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  var sec = s % 60
  return h > 0 ? h + ":" + pad2(m) + ":" + pad2(sec) : m + ":" + pad2(sec)
}

function clamp01(v) {
  var n = Number(v)
  if (!isFinite(n)) return 0
  return Math.max(0, Math.min(1, n))
}

function volumeIcon(volume, muted) {
  if (muted || volume <= 0.001) return "󰝟"
  if (volume < 0.34) return "󰕿"
  if (volume < 0.67) return "󰖀"
  return "󰕾"
}

function brightnessIcon(level) {
  if (level < 0.34) return "󰃞"
  if (level < 0.67) return "󰃟"
  return "󰃠"
}

var batteryDischarging = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
var batteryCharging = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]

function batteryIcon(fraction, charging) {
  var i = Math.max(0, Math.min(10, Math.round(clamp01(fraction) * 10)))
  return charging ? batteryCharging[i] : batteryDischarging[i]
}

function percentText(fraction) {
  return Math.round(clamp01(fraction) * 100) + "%"
}

// Power profiles (power-profiles-daemon). The glyphs are the ones Omarchy's
// own power panel uses; the chip cycles performance -> balanced -> power-saver.
var powerProfileOrder = ["performance", "balanced", "power-saver"]

function profileIcon(name) {
  if (name === "power-saver") return "󰌪"
  if (name === "balanced") return "󰊚"
  if (name === "performance") return "󰓅"
  return "󰂄"
}

function profileName(name) {
  if (name === "power-saver") return "Power Saver"
  if (name === "balanced") return "Balanced"
  if (name === "performance") return "Performance"
  return "Power Profile"
}

function nextPowerProfile(name) {
  var i = powerProfileOrder.indexOf(name)
  return powerProfileOrder[(i + 1) % powerProfileOrder.length]
}

// MPRIS proxies (playerctld) mirror another player; showing them would put
// every track in the island twice.
function isProxyPlayer(player) {
  var dbusName = String(player && player.dbusName || "").toLowerCase()
  var entry = String(player && player.desktopEntry || "").toLowerCase()
  return dbusName.indexOf("playerctld") !== -1 || entry === "playerctld"
}

function playerKey(player) {
  return player ? String(player.dbusName || player.identity || "") : ""
}

function hasTrack(player) {
  return !!(player && (player.trackTitle || player.trackArtist))
}

// How complete a player's track info is. When two players both claim to be
// playing (a music app plus a browser tab mirroring it), the one with cover
// art and a separate artist is the one worth showing.
function richness(player) {
  return (hasRealArt(player) ? 2 : 0) + (player.trackArtist ? 1 : 0)
}

// Chromium-based browsers hand MPRIS a temp file for artwork, and when the
// page gives none it is just the browser's own logo. It never outranks a
// player with a real cover.
function hasRealArt(player) {
  var url = String(player && player.trackArtUrl || "")
  if (!url) return false
  return url.indexOf("/.org.chromium.") === -1 && url.indexOf("/.com.google.Chrome.") === -1
    && url.indexOf("/.com.brave.") === -1 && url.indexOf("/.com.microsoft.Edge.") === -1
}

function normalizedTitle(player) {
  return String(player && player.trackTitle || "").toLowerCase().replace(/\s+/g, " ").trim()
}

// Two players showing one song: typically the Spotify app plus Chromium's
// mirror of it ("Boyfriend" vs "Boyfriend • Karan Aujla, Ikky", same length).
function sameTrack(a, b) {
  var ta = normalizedTitle(a)
  var tb = normalizedTitle(b)
  if (!ta || !tb) return false
  if (!(ta === tb || ta.indexOf(tb) === 0 || tb.indexOf(ta) === 0)) return false
  if (a.lengthSupported && b.lengthSupported && a.length > 0 && b.length > 0)
    return Math.abs(a.length - b.length) < 2
  return true
}

// Players worth considering: no proxies, something loaded, and of any pair
// playing the same song only the one with the better metadata.
function candidates(players) {
  var list = []
  players = players || []
  for (var i = 0; i < players.length; i++) {
    var p = players[i]
    if (!p || isProxyPlayer(p) || !hasTrack(p)) continue
    var duplicateOf = -1
    for (var j = 0; j < list.length; j++)
      if (sameTrack(p, list[j])) { duplicateOf = j; break }
    if (duplicateOf === -1) list.push(p)
    else if (richness(p) > richness(list[duplicateOf])) list[duplicateOf] = p
  }
  return list
}

// The island sticks with the player it is already showing (`currentKey`), so
// pausing keeps that player on screen even while a browser tab keeps claiming
// "Playing". It moves on only when another player starts playing (handled by
// the caller) or the current one goes away. Without a current player: the
// richest playing one, then the richest one at all.
function pickPlayer(players, currentKey) {
  var list = candidates(players)
  var current = null
  var playing = null
  var fallback = null
  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    if (currentKey && playerKey(p) === currentKey) current = p
    if (p.isPlaying && (!playing || richness(p) > richness(playing))) playing = p
    if (!fallback || richness(p) > richness(fallback)) fallback = p
  }
  return current || playing || fallback
}

// Capture streams (something is recording from a microphone). Peak meters and
// monitor taps are capture streams too, but they are not a privacy signal.
function isMicStream(node) {
  if (!node || !node.isStream || node.isSink !== false) return false
  var name = String(node.name || "").toLowerCase()
  return name.indexOf("peak") === -1 && name.indexOf("monitor") === -1 && name.indexOf("cava") === -1
}

// Pull `colorN = "#rrggbb"` pairs out of a theme's colors.toml.
function parseColors(text) {
  var out = {}
  var re = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"/gm
  var m
  while ((m = re.exec(String(text || ""))) !== null) out[m[1]] = m[2]
  return out
}

function parseConfig(configText) {
  try {
    var cfg = JSON.parse(String(configText || "{}"))
    return cfg && typeof cfg === "object" ? cfg : {}
  } catch (e) {
    return {}
  }
}

// This plugin's own entry in shell.json's plugins[] array doubles as its
// settings block, e.g. { "id": "...", "style": "notch" }.
function entryFor(cfg, pluginId) {
  var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
  for (var i = 0; i < list.length; i++)
    if (list[i] && list[i].id === pluginId) return list[i]
  return {}
}

// Senders that are feedback noise rather than messages (Omarchy's rule).
function isEphemeralApp(appName) {
  var name = String(appName || "")
  return name === "notify-send" || name === "omarchy-action"
}

function stringHint(hints, name) {
  try {
    if (hints) {
      var value = hints[name]
      if (value !== undefined && value !== null) return String(value)
    }
  } catch (e) {}
  return ""
}

// omarchy-notification-send --exec passes the click command as a JSON argv.
function parseExecArgv(value) {
  var text = String(value || "")
  if (!text) return null
  var parsed
  try { parsed = JSON.parse(text) } catch (e) { return null }
  if (!Array.isArray(parsed) || parsed.length === 0) return null
  for (var i = 0; i < parsed.length; i++)
    if (typeof parsed[i] !== "string") return null
  return parsed
}

// Notification bodies may carry a little markup; the island shows text.
function plainText(value) {
  return String(value || "")
    .replace(/<br\s*\/?>/gi, " ")
    .replace(/<[^>]*>/g, "")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
    .replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim()
}

// Omarchy's OSD payloads ({ icon, message, value, max, duration }, as sent by
// `omarchy osd` and its callers), mapped onto island HUDs. `show` says
// whether volume and brightness levels should appear ({ volume, brightness });
// returns null for a payload the island should drop.
function osdGlyph(name) {
  var n = String(name || "").toLowerCase()
  if (n.indexOf("microphone-muted") === 0 || n === "microphone-off" || n === "mic-muted" || n === "mic-off") return "󰍭"
  if (n === "microphone" || n === "mic") return "󰍬"
  if (n === "keyboard") return "󰌌"
  if (n === "brightness" || n === "display") return "󰃠"
  if (n === "touchpad") return "󰟸"
  if (n === "touch" || n === "touchscreen") return "󰝁"
  if (n === "reboot" || n === "restart") return "󰜉"
  if (n === "shutdown" || n === "power" || n === "poweroff") return "󰐥"
  if (n === "logout" || n === "sign-out" || n === "leave") return "󰍃"
  if (n.indexOf("media") === 0 || n.indexOf("player") === 0) return "󰝚"
  if (n === "volume-muted" || n === "volume-mute" || n === "muted" || n === "mute") return "󰝟"
  if (n.indexOf("volume") === 0) return "󰕾"
  return String(name || "")
}

function osdHud(payload, show) {
  var p = payload || {}
  show = show || {}
  var key = String(p.icon || "").toLowerCase()
  var message = String(p.message || "")
  var max = Math.max(1, parseInt(p.max || "100", 10) || 100)
  var raw = parseInt(p.value, 10)
  var hasProgress = p.value !== undefined && p.value !== "" && !isNaN(raw) && message === ""
  var parsedDuration = parseInt(p.duration, 10)
  var duration = isNaN(parsedDuration) ? 1500 : Math.max(1500, parsedDuration)
  var volume = key.indexOf("volume") === 0 || key === "muted" || key === "mute"
  var off = /muted|-off$|^mute$/.test(key) || / disabled$/i.test(message)

  if (hasProgress) {
    var level = clamp01(raw / max)
    if (volume && !show.volume) return null
    if (key === "brightness" && !show.brightness) return null
    return {
      key: volume ? "volume" : (key === "brightness" ? "brightness" : "osd"),
      layout: "progress",
      icon: volume ? volumeIcon(level, off) : (key === "brightness" ? brightnessIcon(level) : osdGlyph(p.icon)),
      value: level,
      valueText: Math.round(level * 100) + "%",
      dim: off,
      duration: duration
    }
  }
  if (!message && !p.icon) return null
  return {
    key: "osd",
    layout: "label",
    // Switching outputs sends the device name with a volume icon.
    label: message,
    valueText: volume && !off && message ? "Playing on" : "",
    icon: osdGlyph(p.icon),
    dim: off,
    duration: duration
  }
}

// Every setting and its default, in the README's order. The island writes
// the missing ones into its shell.json entry so they can be edited in place.
var defaultSettings = {
  style: "notch",
  background: "theme",
  idle: "pill",
  idleFace: "ticker",
  scale: 1,
  topMargin: 6,
  reserveSpace: true,
  keybind: "SUPER + ALT + I",
  monitor: "primary",
  layer: "top",
  expandOnHover: false,
  clockFormat: "h:mm AP",
  mediaLingerSeconds: 30,
  notchWidth: 0,
  notchHeight: 0,
  notchRadius: 0,
  visualizerColor: "accent",
  textFont: "iA Writer Quattro V",
  glow: false,
  calendars: [],
  calendarLeadMinutes: 15,
  holidays: "auto",
  timerSound: true,
  bluetooth: true,
  camera: true,
  calendar: true,
  notifications: true,
  inbox: true,
  osd: true,
  volume: true,
  brightness: true,
  charging: true,
  trackChange: true,
  recording: true,
  mic: true
}

function missingSettings(settings) {
  var s = settings || {}
  return Object.keys(defaultSettings).filter(function(k) { return !(k in s) })
}

// Hyprland's modifier mask for a key like "SUPER + ALT + I", and the key.
function parseKeybind(text) {
  var parts = String(text || "").split("+").map(function(p) { return p.trim() }).filter(function(p) { return p })
  if (parts.length === 0) return null
  var bits = { SHIFT: 1, CAPS: 2, CTRL: 4, CONTROL: 4, ALT: 8, MOD1: 8, MOD2: 16, MOD3: 32,
               SUPER: 64, WIN: 64, LOGO: 64, MOD4: 64, MOD5: 128 }
  var mask = 0
  for (var i = 0; i < parts.length - 1; i++) {
    var bit = bits[parts[i].toUpperCase()]
    if (bit === undefined) return null
    mask |= bit
  }
  return { mask: mask, key: parts[parts.length - 1] }
}

// ---------------------------------------------------------------------
// Weather. Shaped once here so the island pill, the idle-expanded
// drop-down and the weather pane all read from one object. Sources are
// the same two the shell's weather panel uses: open-meteo when the
// place is known (fast) and wttr.in otherwise (IP auto-detect, and the
// place it names seeds open-meteo for later refreshes).
// ---------------------------------------------------------------------

function weatherImperial(localeName) {
  var name = String(localeName || "").replace(".", "_")
  return /^en[_-]US([_.-]|$)/.test(name) || /^en[_-]LR([_.-]|$)/.test(name) || /^my([_.-]|$)/.test(name)
}

function weatherUnit(unitSetting, localeName) {
  var u = String(unitSetting || "").toLowerCase()
  if (u === "imperial") return true
  if (u === "metric") return false
  return weatherImperial(localeName)
}

function weatherRound(v) {
  var n = parseFloat(String(v))
  return isNaN(n) ? "" : String(Math.round(n))
}

function weatherTempText(cTemp, fTemp, imperial) {
  var v = weatherRound(imperial ? fTemp : cTemp)
  return v === "" ? "" : v + "°" + (imperial ? "F" : "C")
}

function weatherRangeText(minC, maxC, minF, maxF, imperial) {
  var lo = weatherRound(imperial ? minF : minC), hi = weatherRound(imperial ? maxF : maxC)
  return lo === "" || hi === "" ? "" : lo + "° / " + hi + "°"
}

// Ticker/drop-down glyphs. Same mapping as the shell weather panel
// (nerd-font) so island and panel never disagree about the sky.
function weatherIconForCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  if (c === 113) return night ? "\ue32b" : "\ue30d"
  if (c === 116) return night ? "\ue32e" : "\ue302"
  if (c === 119 || c === 122) return "\ue33d"
  if (c === 143 || c === 248 || c === 260) return night ? "\ue346" : "\ue313"
  if (c === 176 || c === 263 || c === 353) return night ? "\ue333" : "\ue308"
  if (c === 179 || c === 227 || c === 230 || c === 323 || c === 326 || c === 368) return night ? "\ue327" : "\ue30a"
  if (c === 182 || c === 185 || c === 281 || c === 284 || c === 311 || c === 314 ||
      c === 317 || c === 320 || c === 350 || c === 362 || c === 365 || c === 374 || c === 377) return "\ue3ad"
  if (c === 200 || c === 386 || c === 389 || c === 392 || c === 395) return "\ue31d"
  if (c === 266 || c === 293 || c === 296 || c === 299 || c === 302 || c === 305 || c === 308 || c === 356 || c === 359) return "\ue318"
  if (c === 329 || c === 332 || c === 335 || c === 338 || c === 371) return "\ue31a"
  return "\ue33d"
}

function weatherIconForOpenMeteoCode(openMeteoCode, night) {
  var c = parseInt(String(openMeteoCode || "0"), 10)
  if (c === 0) return weatherIconForCode(113, night)
  if (c === 1 || c === 2) return weatherIconForCode(116, night)
  if (c === 3) return weatherIconForCode(119, night)
  if (c === 45 || c === 48) return weatherIconForCode(143, night)
  if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return weatherIconForCode(266, night)
  if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return weatherIconForCode(308, night)
  if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return weatherIconForCode(338, night)
  if (c === 95 || c === 96 || c === 99) return weatherIconForCode(389, night)
  return weatherIconForCode(119, night)
}

function weatherHourlyIcon(hourly) {
  var best = null, bestDist = 9999
  for (var i = 0; i < (hourly || []).length; ++i) {
    var t = parseInt(String((hourly[i] && hourly[i].time) || "0"), 10)
    if (isNaN(t)) continue
    var dist = Math.abs(t - 1200)
    if (dist < bestDist) { bestDist = dist; best = hourly[i] }
  }
  return best ? weatherIconForCode(best.weatherCode, false) : ""
}

function weatherDayName(dateString) {
  var d = new Date(String(dateString || "") + "T12:00:00")
  if (isNaN(d.getTime())) return ""
  return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()]
}

// One normalized read: the panel's wttr.in j1 answer (current + up to
// 3 daily entries), or open-meteo's combined current+daily answer.
function weatherFromWttr(report, labelOverride) {
  if (!report || !report.current_condition || !report.current_condition.length) return null
  var cc = report.current_condition[0]
  var num = function(v) { var n = parseFloat(String(v)); return isNaN(n) ? null : String(Math.round(n)) }
  // wttr's j1 answer carries no sunrise/sunset for the current hour; the
  // observation clock is a decent stand-in for day vs night (the open-meteo
  // path does it exactly with is_day).
  var hour = new Date().getHours()
  var isDay = hour >= 6 && hour < 19
  var out = {
    label: labelOverride || "",
    icon: weatherIconForCode(cc.weatherCode, isDay) || "",
    kind: weatherKindForCode(cc.weatherCode, isDay),
    tempC: num(cc.temp_C), tempF: num(cc.temp_F),
    feelsC: num(cc.FeelsLikeC), feelsF: num(cc.FeelsLikeF),
    // num()'s rounded string is the value to show: a raw "11.1" reads
    // inconsistent next to every other field, and a calm day must show
    // "0" rather than blank (num("0") is truthy as a String).
    windKmph: num(cc.windspeedKmph) || "",
    windMph: num(cc.windspeedMiles) || "",
    humidity: num(cc.humidity),
    isDay: isDay,
    days: []
  }
  var days = report.weather || []
  for (var i = 0; i < days.length && out.days.length < 3; ++i) {
    var wd = days[i]
    if (!wd) continue
    out.days.push({
      name: i === 0 ? "Today" : weatherDayName(wd.date),
      icon: weatherHourlyIcon(wd.hourly),
      maxC: num(wd.maxtempC), minC: num(wd.mintempC),
      maxF: num(wd.maxtempF), minF: num(wd.mintempF)
    })
  }
  var area = report.nearest_area && report.nearest_area[0] ? report.nearest_area[0] : null
  if (area) {
    var place = area.areaName && area.areaName.length ? String(area.areaName[0].value) : ""
    if (!out.label && place) out.label = place
  }
  return out
}

function weatherPad2(n) { return (n < 10 ? "0" : "") + n }

// The next ~12 hours of precipitation probability, local hour first, for
// the mini bar chart in the weather pane. Open-meteo only (wttr has no
// hourly probability feed). The hourly times are stamped in the PLACE's
// timezone (timezone=auto), so the reference clock must come from the
// report itself — current.time is in that same zone; a Date.now() stamp
// would offset the whole chart for any place in another timezone.
function weatherRainUpNext(hourly, reference) {
  if (!hourly || !hourly.time || !hourly.precipitation_probability) return []
  var ref = String(reference || "")
  var stamp
  if (ref.length >= 13 && ref.charAt(10) === "T") {
    stamp = ref.slice(0, 13)
  } else {
    var d = new Date()
    stamp = d.getFullYear() + "-" + weatherPad2(d.getMonth() + 1) + "-"
      + weatherPad2(d.getDate()) + "T" + weatherPad2(d.getHours())
  }
  var out = []
  for (var i = 0; i < hourly.time.length && out.length < 12; ++i) {
    var t = String(hourly.time[i] || "")
    if (t < stamp) continue
    var pct = parseInt(String(hourly.precipitation_probability[i]) || "", 10)
    out.push({ time: t.slice(11, 16), pct: isNaN(pct) ? 0 : pct })
  }
  return out
}

function weatherHourMinute(iso) {
  var s = String(iso || "")
  return s.length >= 16 ? s.slice(11, 16) : ""
}

function weatherFromOpenMeteo(report, labelOverride) {
  var current = report && report.current ? report.current : null
  var daily = report && report.daily ? report.daily : null
  if (!current || current.temperature_2m === undefined) return null
  var isDay = Number(current.is_day) !== 0
  var out = {
    label: labelOverride || "",
    icon: weatherIconForOpenMeteoCode(current.weather_code, isDay) || "",
    kind: weatherKindForOpenMeteoCode(current.weather_code, isDay),
    tempC: weatherRound(current.temperature_2m), tempF: weatherRound(current.temperature_2m * 9 / 5 + 32),
    feelsC: weatherRound(current.apparent_temperature),
    feelsF: weatherRound(current.apparent_temperature * 9 / 5 + 32),
    windKmph: weatherRound(current.wind_speed_10m), windMph: weatherRound(current.wind_speed_10m * 0.621371),
    humidity: weatherRound(current.relative_humidity_2m),
    isDay: isDay,
    days: []
  }
  if (daily && daily.time) {
    for (var i = 0; i < daily.time.length && out.days.length < 3; ++i) {
      out.days.push({
        name: i === 0 ? "Today" : weatherDayName(daily.time[i]),
        icon: weatherIconForOpenMeteoCode(daily.weather_code ? daily.weather_code[i] : 0, isDay),
        maxC: weatherRound(daily.temperature_2m_max ? daily.temperature_2m_max[i] : ""),
        minC: weatherRound(daily.temperature_2m_min ? daily.temperature_2m_min[i] : ""),
        // Convert the raw float once, then round: routing through the
        // rounded C string double-rounds and can move the F by a degree.
        maxF: weatherRound(daily.temperature_2m_max ? parseFloat(daily.temperature_2m_max[i]) * 9 / 5 + 32 : ""),
        minF: weatherRound(daily.temperature_2m_min ? parseFloat(daily.temperature_2m_min[i]) * 9 / 5 + 32 : "")
      })
    }
  }
  out.rain = weatherRainUpNext(report.hourly, current.time)
  out.sunrise = daily && daily.sunrise && daily.sunrise.length ? weatherHourMinute(daily.sunrise[0]) : ""
  out.sunset = daily && daily.sunset && daily.sunset.length ? weatherHourMinute(daily.sunset[0]) : ""
  return out
}

// The weather location file (owned by omarchy-weather-location): blank or
// unparseable means the place is auto-detected.
function weatherParseLocation(raw) {
  var unset = { name: "", latitude: null, longitude: null }
  try {
    var d = JSON.parse(String(raw || ""))
    if (!d || typeof d !== "object") return unset
    var latitude = parseFloat(d.latitude)
    var longitude = parseFloat(d.longitude)
    return {
      name: typeof d.name === "string" ? d.name.replace(/^\s+|\s+$/g, "") : "",
      latitude: !isNaN(latitude) ? latitude : null,
      longitude: !isNaN(longitude) ? longitude : null
    }
  } catch (e) { return unset }
}

// 758150 -> "758k"; 43.3m-style inputs: "4.1m" keeps the pill value short.
function abbrevTokens(n) {
  var v = Number(n)
  if (!isFinite(v) || v <= 0) return "0"
  // 999500 rounds to 1000k at the k boundary — promote to m instead of
  // printing four digits the pill has no room for.
  if (v >= 999500) return (v / 1000000).toFixed(1) + "m"
  if (v >= 1000) return Math.round(v / 1000) + "k"
  return String(v)
}

// sysfs hwmon dump -> {cpuTemp, gpuTemp, gpuBusy} in C and percent. Chips
// carry their name on the same line: k10temp/coretemp/zenpower (or any
// cpu*) is the CPU, amdgpu/i915/nouveau (or any gpu*) the GPU. Hottest
// card and busiest card win independently. gpu_busy_percent arrives as a
// bare number on its own line — never treat a named sensor's value (a
// temperature, a fan RPM) as a busy percent. Desktops with no GPU lines
// just drop them.
function hardwareStats(raw) {
  var out = { cpuTemp: null, gpuTemp: null, gpuBusy: null }
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; ++i) {
    var line = lines[i].toLowerCase()
    var m = line.match(/(\d+)\s*$/)
    if (!m) continue
    var n = parseInt(m[1], 10)
    if (isNaN(n) || line.indexOf("busy") !== -1) continue
    // Millidegrees (hwmon temp inputs) normalize to C; sub-zero ambient is
    // legal, sensor garbage is not.
    var t = n > 2000 ? Math.round(n / 1000) : n
    var isTemp = t > -40 && t < 130
    if (line.indexOf("k10temp") !== -1 || line.indexOf("coretemp") !== -1
        || line.indexOf("zenpower") !== -1 || line.indexOf("cpu") !== -1) {
      if (isTemp) out.cpuTemp = t
    } else if (line.indexOf("amdgpu") !== -1 || line.indexOf("i915") !== -1
        || line.indexOf("nouveau") !== -1 || line.indexOf("gpu") !== -1) {
      if (isTemp) out.gpuTemp = Math.max(out.gpuTemp !== null ? out.gpuTemp : -Infinity, t)
    }
  }
  if (out.gpuTemp === -Infinity) out.gpuTemp = null
  // gpu_busy_percent: only lines that are just a number count.
  var busies = []
  for (var j = 0; j < lines.length; ++j) {
    var l = lines[j].trim()
    if (/^\d+\s*$/.test(l)) busies.push(parseInt(l, 10))
  }
  if (busies.length > 0) out.gpuBusy = Math.max.apply(null, busies)
  return out
}

// "Rolling (5h)" -> "5h", "Weekly (7-day)" -> "wk", "Monthly" -> "mo".
function agentLimitTag(label, index) {
  var s = String(label || "").toLowerCase()
  if (s.indexOf("5h") !== -1) return "5h"
  if (s.indexOf("week") !== -1 || s.indexOf("7-day") !== -1) return "wk"
  if (s.indexOf("month") !== -1) return "mo"
  return String(label).slice(0, 6) || "#" + (index + 1)
}

// The sky's motion class for WeatherGlyph: what the text glyph becomes
// when it wants to move. Mirrors the icon tables above.
function weatherKindForCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  if (c === 113) return night ? "night" : "sun"
  if (c === 116) return "cloud"
  if (c === 119 || c === 122) return "cloud"
  if (c === 143 || c === 248 || c === 260) return "fog"
  if (c === 176 || c === 263 || c === 353) return "rain"
  if (c === 179 || c === 227 || c === 230 || c === 323 || c === 326 || c === 368) return "snow"
  if (c === 182 || c === 185 || c === 281 || c === 284 || c === 311 || c === 314 ||
      c === 317 || c === 320 || c === 350 || c === 362 || c === 365 || c === 374 || c === 377) return "rain"
  if (c === 200 || c === 386 || c === 389 || c === 392 || c === 395) return "thunder"
  if (c === 266 || c === 293 || c === 296 || c === 299 || c === 302 || c === 305 || c === 308 || c === 356 || c === 359) return "rain"
  if (c === 329 || c === 332 || c === 335 || c === 338 || c === 371) return "snow"
  return "cloud"
}

function weatherKindForOpenMeteoCode(openMeteoCode, night) {
  var c = parseInt(String(openMeteoCode || "0"), 10)
  if (c === 0) return weatherKindForCode(113, night)
  if (c === 1 || c === 2) return weatherKindForCode(116, night)
  if (c === 3) return weatherKindForCode(119, night)
  if (c === 45 || c === 48) return weatherKindForCode(143, night)
  if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return weatherKindForCode(266, night)
  if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return weatherKindForCode(308, night)
  if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return weatherKindForCode(338, night)
  if (c === 95 || c === 96 || c === 99) return weatherKindForCode(389, night)
  return "cloud"
}

// One word for the sky, for the drop-down card: plain English for the
// motion class.
function weatherConditionName(kind) {
  switch (String(kind || "")) {
    case "sun": return "Clear"
    case "night": return "Clear night"
    case "cloud": return "Cloudy"
    case "fog": return "Fog"
    case "rain": return "Rain"
    case "snow": return "Snow"
    case "thunder": return "Storm"
    default: return ""
  }
}
