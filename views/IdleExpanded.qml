import QtQuick
import Quickshell
import qs.Commons
import "../IslandModel.js" as Model

// What the island opens into when nothing is live: the time with the
// weather beside it, now-playing below while something is playing, and the
// system buttons — power profile (with battery/charge on battery devices),
// DND, night light, theme, lock — with one-tap timers and a stopwatch.
Item {
  id: view

  property var island: null
  readonly property int pad: island.s(26)
  readonly property var nextEvent: island.calendar.next

  // What the chained rows actually occupy: the island grows the panel to
  // this when it exceeds the designed height, so content is never clipped
  // and rows never overlap. Depends only on content metrics, never on the
  // panel's own size — no sizing loop.
  readonly property real bottomEdge: bottomRow.y + bottomRow.height + pad
  Binding {
    target: view.island
    property: "idleExpandedHeight"
    value: view.bottomEdge
  }

  // The quick-settings chips of the bottom row: the power-profile chip
  // first — icons only, so it reads at a glance: the daemon's current
  // profile glyph, and on a battery device the charge glyph beside it
  // (green while charging). Then DND, night light, theme, lock.
  // Glyphs ride in a parts row, not one string: they need the mono family,
  // and mixing them into the text font's string overlaps.
  readonly property var quickChips: {
    var prof = island.powerProfile || "balanced"
    var glyphs = [Model.profileIcon(prof)]
    if (island.hasBattery)
      glyphs.push(Model.batteryIcon(island.batteryLevel, island.charging))
    var chips = [{ kind: "power", on: false, glyphs: glyphs }]
    chips.push({ kind: "dnd", label: "DND", glyph: island.dndActive ? "󰂛" : "󰂚", on: island.dndActive })
    chips.push({ kind: "night", label: "Night", glyph: "󰖜", on: false })
    chips.push({ kind: "theme", label: "Theme", glyph: "󰏘", on: false })
    chips.push({ kind: "lock", label: "Lock", glyph: "󰌾", on: false })
    return chips
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // Left block: the time, and the date (or next meeting) that opens the
  // calendar. The weather chip rides to the clock's right — clock, chip
  // and date are direct siblings here, since QML anchors may only point
  // at a parent or sibling.
  Text {
    id: timeText
    x: view.pad
    y: island.s(14)
    text: Qt.formatDateTime(clock.date, island.clockFormat)
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(30)
    font.weight: Font.Light
    font.letterSpacing: -island.ls(1)
    font.features: { "tnum": 1 }
    color: island.fg
  }

  // Weather card: a taller mini-card from the time's right to the panel's
  // right edge, so it fills the gap instead of a thin strip: conditions and
  // temp, the sky's own word, then the ranges beneath, and a third line of
  // whatever is most actionable — the next umbrella window, else the sun
  // times, else feels-like. A tap still opens the full pane. Battery and
  // charge live on the profile chip in the bottom row, so the card keeps
  // the full width at every scale.
  Rectangle {
    id: weatherChip
    visible: island.showWeather
    anchors.left: timeText.right
    anchors.leftMargin: view.island.s(14)
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    y: island.s(14)
    // Content is f()-scaled (fonts), the design height s()-scaled: keep the
    // design size but never clip — grow to fit when fonts run larger.
    height: Math.max(island.s(62), contentCol.implicitHeight + island.s(16))
    radius: view.island.s(14)
    color: Util.alpha(island.accentColor,
      weatherMouse.pressed ? 0.28 : (weatherMouse.containsMouse ? 0.18 : 0.10))
    scale: weatherMouse.pressed ? 0.98 : 1

    Behavior on scale { NumberAnimation { duration: 120 } }

    readonly property string rainWindow: {
      if (!island.weatherReady || !island.weather || !island.weather.rain) return ""
      var r = island.weather.rain
      for (var i = 1; i < r.length; ++i)
        if (r[i].pct >= 50) return "󰖕 rain @ " + r[i].time
      return ""
    }
    readonly property string sunTimes: {
      if (!island.weatherReady || !island.weather || !island.weather.rain) return ""
      return island.weather.rain !== undefined && island.weather.sunrise && island.weather.sunset
        ? "󰖜 " + island.weather.sunrise + "  ·  󰖛 " + island.weather.sunset : ""
    }
    readonly property string feelsLine: {
      if (!island.weatherReady || !island.weather) return ""
      var f = Model.weatherTempText(island.weather.feelsC, island.weather.feelsF, island.weatherImperial)
      return f === "" ? "" : "feels " + f
    }

    Column {
      id: contentCol
      anchors.fill: parent
      anchors.margins: view.island.s(8)
      spacing: view.island.s(2)

      // All three rows center themselves in the card, so the composition
      // reads as one balanced medallion instead of a left-leaning list.
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        WeatherGlyph {
          anchors.verticalCenter: parent.verticalCenter
          size: view.island.f(18)
          glyph: island.weatherReady && island.weather ? island.weather.icon : "󰖕"
          color: view.island.accentColor
          fontFamily: view.island.fontFamily
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: view.island.s(6)
          text: island.weatherReady && island.weather
            ? Model.weatherTempText(island.weather.tempC, island.weather.tempF, view.island.weatherImperial)
            : (view.island.weatherSource.status === "fetching" ? "Weather…" : "Weather —")
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: view.island.fontFamily
          font.pixelSize: view.island.f(17)
          font.bold: true
          font.features: { "tnum": 1 }
          color: view.island.accentColor
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: view.island.s(8)
          text: island.weatherReady && island.weather ? Model.weatherConditionName(island.weather.kind) : ""
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: view.island.textFamily
          font.pixelSize: view.island.f(10)
          font.capitalization: Font.AllUppercase
          color: Util.alpha(view.island.accentColor, 0.75)
        }
      }

      Text {
        text: island.weatherReady && island.weather
          ? (island.weather.days.length > 0
            ? "H " + Model.weatherTempText(island.weather.days[0].maxC, island.weather.days[0].maxF, view.island.weatherImperial)
            + " / L " + Model.weatherTempText(island.weather.days[0].minC, island.weather.days[0].minF, view.island.weatherImperial)
            + (island.weather.windKmph !== ""
              ? "  ·  󰳢 " + (view.island.weatherImperial ? island.weather.windMph + "mph" : island.weather.windKmph + "km/h")
              : "")
            + (island.weather.humidity !== "" ? "  ·  󰗎 " + island.weather.humidity + "%" : "")
            : "")
          : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.textFamily
        font.pixelSize: view.island.f(9)
        font.features: { "tnum": 1 }
        color: Util.alpha(view.island.fg, 0.62)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        width: parent.width
      }

      Text {
        text: {
          if (!island.weatherReady || !island.weather) return ""
          if (weatherChip.rainWindow !== "") return weatherChip.rainWindow
          if (weatherChip.sunTimes !== "") return weatherChip.sunTimes
          return weatherChip.feelsLine
        }
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.fontFamily
        font.pixelSize: view.island.f(9)
        font.features: { "tnum": 1 }
        color: Util.alpha(view.island.fg, 0.5)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        width: parent.width
      }
    }

    MouseArea {
      id: weatherMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: island.openWeather()
    }
  }

  Text {
    id: dateLine
    anchors.top: timeText.bottom
    anchors.topMargin: island.s(2)
    x: view.pad
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: island.openCalendar()
      onContainsMouseChanged: dateLine.font.underline = containsMouse
    }
    text: view.nextEvent
      ? "󰃭  " + view.nextEvent.title + "  ·  " + Qt.formatDateTime(new Date(view.nextEvent.start), island.clockFormat.indexOf("AP") !== -1 ? "h:mm AP" : "HH:mm")
      : Qt.formatDateTime(clock.date, "dddd, d MMMM")
        + (island.calendar.todayAllDay.length > 0 ? "  ·  " + island.calendar.todayAllDay.join(", ") : "")
    width: island.s(172)
    elide: Text.ElideRight
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.textFamily
    font.pixelSize: island.f(12)
    color: view.nextEvent ? island.accentColor : island.fgDim
  }

  // The tallest edge above the media row: the weather chip when shown (it
  // spans the whole clock row), else the date line. Rows chain from this,
  // so any growth — larger fonts, an extra line in the chip — reflows
  // downward instead of overlapping the row below it.
  readonly property real clockRowBottom: weatherChip.visible
    ? weatherChip.y + weatherChip.height : dateLine.y + dateLine.height

  // Now playing, full width below the clock row — while something is live.
  // Clicking anywhere on it opens the player pane.
  Rectangle {
    id: mediaRow
    visible: island.mediaActivity && island.hasMedia
    x: view.pad
    y: view.clockRowBottom + island.s(12)
    width: parent.width - view.pad * 2
    // Fit the f()-scaled transport buttons: an s()-only height breaks when
    // fontScale exceeds the spacing scale (buttons poke out of the capsule).
    height: Math.max(island.s(22), transportRow.implicitHeight + island.s(4))
    radius: height / 2
    color: Util.alpha(island.fg, mediaMouse.containsMouse ? 0.18 : 0.10)
    scale: mediaMouse.pressed ? 0.98 : 1

    Behavior on scale { NumberAnimation { duration: 120 } }

    AlbumArt {
      id: miniArt
      x: island.s(4)
      anchors.verticalCenter: parent.verticalCenter
      width: island.s(15)
      height: width
      source: island.mediaArt
      tint: island.accentColor
      fontFamily: island.fontFamily
    }

    Text {
      anchors.left: miniArt.right
      anchors.leftMargin: island.s(7)
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: transportRow.left
      anchors.rightMargin: island.s(6)
      text: (island.mediaTitle || "Now playing")
        + (island.mediaArtist !== "" ? "  ·  " + island.mediaArtist : "")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.textFamily
      font.pixelSize: island.f(11)
      color: island.mediaPlaying ? island.fg : island.fgDim
      elide: Text.ElideRight
    }

    // Quick transport on the row itself: prev, play/pause, next. Declared
    // BEFORE the row-wide open-click MouseArea — QML delivers to the
    // topmost sibling, so a MouseArea after the Row would swallow every
    // button's hover and press.
    Row {
      id: transportRow
      anchors.right: parent.right
      anchors.rightMargin: island.s(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(4)

      IconButton {
        glyph: "󰒮"
        glyphSize: island.f(11)
        color: island.fg
        fontFamily: island.fontFamily
        available: island.mediaCanPrevious
        onClicked: island.mediaPrevious()
      }

      IconButton {
        glyph: island.mediaPlaying ? "󰏤" : "󰐊"
        glyphSize: island.f(11)
        color: island.fg
        fontFamily: island.fontFamily
        available: true
        onClicked: island.mediaToggle()
      }

      IconButton {
        glyph: "󰒭"
        glyphSize: island.f(11)
        color: island.fg
        fontFamily: island.fontFamily
        available: island.mediaCanNext
        onClicked: island.mediaNext()
      }
    }

    // Row-wide "open the player" click; declared last so the buttons above
    // it receive their events first.
    MouseArea {
      id: mediaMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: island.openMediaPane()
    }
  }

  // The bottom row, symmetric: the agent meter button on the left edge, the
  // quick-setting chips centered between, and the notifications bell on the
  // right edge. (Floating bubbles are retired; everything is a persistent
  // button on this panel now.)
  Item {
    id: bottomRow
    x: view.pad
    // Chains from the media row when it shows (else from its slot), so the
    // bottom row follows whatever sits above it.
    y: (mediaRow.visible ? mediaRow.y + mediaRow.height : mediaRow.y) + island.s(12)
    width: parent.width - view.pad * 2
    height: island.s(26)

    // One template for the whole row: capsule buttons at s(26) with the
    // same inner padding, the same tint/hover/press curve, words in the
    // theme font and numbers in the mono — so the agent readout, the quick
    // settings and the notifications read as one family.
    // Agent meter button: glyph + the tightest meter's percent, said in
    // text so the button answers even when the arc is near zero.
    Rectangle {
      id: agentBtn
      visible: island.showOpencode
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: agentRow.implicitWidth + island.s(12)
      height: island.s(26)
      radius: height / 2
      color: Util.alpha(island.fg, agentMouse.pressed ? 0.30 : (agentMouse.containsMouse ? 0.18 : 0.11))
      scale: agentMouse.pressed ? 0.94 : 1

      Behavior on scale { NumberAnimation { duration: 120 } }

      Row {
        id: agentRow
        anchors.centerIn: parent
        spacing: island.s(4)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰚩"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          color: island.agentWarm ? island.opencodeRingColor : Util.alpha(island.fg, 0.4)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: island.agentWarm && island.opencodeData
            ? (island.opencodeData.limits.length > 0
              ? Math.round(island.opencodeData.limits[0].pct * 100) + "%"
              : "·")
            : "—"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          font.bold: true
          font.features: { "tnum": 1 }
          color: island.agentWarm && island.opencodeData && island.opencodeData.limits.length > 0
            ? island.opencodeRingColor : Util.alpha(island.fg, 0.4)
        }
      }

      MouseArea {
        id: agentMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.opencodePoke()
      }
    }

    // Notifications bell: same capsule template, with the pending count
    // inline in the mono (accent while something waits). Tap opens the
    // inbox.
    Rectangle {
      id: bellBtn
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: bellRow.implicitWidth + island.s(12)
      height: island.s(26)
      radius: height / 2
      color: Util.alpha(island.fg, bellMouse.pressed ? 0.30 : (bellMouse.containsMouse ? 0.18 : 0.11))
      scale: bellMouse.pressed ? 0.94 : 1

      Behavior on scale { NumberAnimation { duration: 120 } }
      Behavior on color { ColorAnimation { duration: 160 } }

      Row {
        id: bellRow
        anchors.centerIn: parent
        spacing: island.s(4)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰂚"
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          color: island.inbox.length > 0 ? island.accentColor : island.fgDim
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: String(island.inbox.length > 9 ? "9+" : island.inbox.length)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: island.fontFamily
          font.pixelSize: island.f(12)
          font.bold: true
          font.features: { "tnum": 1 }
          color: island.inbox.length > 0 ? island.accentColor : Util.alpha(island.fg, 0.4)
        }
      }

      MouseArea {
        id: bellMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.openInbox()
      }
    }

    // Quick settings, centered between the two bookends. Each fires its
    // action on tap: the power profile (icons only — cycles through the
    // daemon's three profiles, and on a battery device the charge glyph
    // beside it makes it the charge indicator, green while charging),
    // DND (the island's own daemon state), night light, the next installed
    // theme, the lock screen.
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      spacing: island.s(6)

      Repeater {
        model: view.quickChips

        Rectangle {
          id: chip
          required property var modelData
          property bool hovered: false
          // The power tooltip outlives the pointer's time on the chip by a
          // beat: closing the instant the chip is left makes the popup
          // vanish while the pointer travels the gap to the tooltip itself.
          property bool tipOpen: false
          height: island.s(26)
          width: (chip.modelData.glyphs !== undefined
            ? chipSpans.implicitWidth : chipLabel.implicitWidth) + island.s(12)
          radius: height / 2
          color: Util.alpha(chip.modelData.on ? island.accentColor : island.fg,
                            chipMouse.pressed ? 0.30 : (chipMouse.containsMouse ? 0.18 : 0.11))
          scale: chipMouse.pressed ? 0.94 : 1

          Behavior on scale { NumberAnimation { duration: 120 } }
          Behavior on color { ColorAnimation { duration: 120 } }

          // Icon-only chips (the power chip): one mono Text per glyph, so
          // the nerd font carries them without fallback overlap.
          Row {
            id: chipSpans
            anchors.centerIn: parent
            spacing: island.s(3)
            visible: chip.modelData.glyphs !== undefined

            Repeater {
              model: chip.modelData.glyphs || []

              Text {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
                font.family: island.fontFamily
                font.pixelSize: island.f(12)
                font.weight: Font.DemiBold
                color: chip.modelData.kind === "power" && island.charging ? island.greenColor : island.fg
              }
            }
          }

          Text {
            id: chipLabel
            visible: chip.modelData.glyphs === undefined
            anchors.centerIn: parent
            text: chip.modelData.glyph + " " + chip.modelData.label
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.textFamily
            font.pixelSize: island.f(12)
            font.weight: Font.DemiBold
            color: chip.modelData.on ? island.accentColor : island.fg
          }

          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
              chip.hovered = containsMouse
              if (chip.modelData.kind === "power") {
                if (containsMouse) { chip.tipOpen = true; tipClose.stop() }
                else tipClose.restart()
              }
            }
            onClicked: {
              if (chip.modelData.kind === "power") { island.cycleProfile(); return }
              if (chip.modelData.kind === "dnd") { island.toggleDnd(); return }
              if (chip.modelData.kind === "night") { island.runShell(["omarchy", "toggle", "nightlight"]); return }
              if (chip.modelData.kind === "theme") { island.cycleTheme(); return }
              island.runShell(["omarchy", "system", "lock"])
            }
          }

          Timer {
            id: tipClose
            interval: 350
            onTriggered: chip.tipOpen = false
          }

          // Hover info popup: battery details + the selected power profile.
          Rectangle {
            id: powerTip
            visible: chip.tipOpen
            z: 100
            anchors.bottom: chip.top
            anchors.bottomMargin: island.s(4)
            anchors.horizontalCenter: chip.horizontalCenter
            width: powerTipText.implicitWidth + island.s(12)
            height: island.s(22)
            radius: height / 2
            color: Util.alpha("#000000", 0.82)
            border.color: Util.alpha(island.fg, 0.25)
            border.width: 1

            Text {
              id: powerTipText
              anchors.centerIn: parent
              text: {
                var prof = Model.profileName(island.powerProfile || "balanced")
                if (!island.hasBattery) return prof
                var state = island.charging ? "charging" : "on battery"
                return prof + "  ·  " + Model.batteryIcon(island.batteryLevel, island.charging)
                  + " " + Model.percentText(island.batteryLevel) + "  ·  " + state
              }
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              font.family: island.textFamily
              font.pixelSize: island.f(11)
              font.weight: Font.DemiBold
              color: "#ffffff"
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              // Hovering the tooltip holds it open; leaving it (without
              // returning to the chip) closes it after the grace beat.
              onContainsMouseChanged: {
                if (containsMouse) tipClose.stop()
                else if (!chipMouse.containsMouse) tipClose.restart()
              }
            }
          }
        }
      }
    }
  }
}
