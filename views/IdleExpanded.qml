import QtQuick
import Quickshell
import qs.Commons
import "../IslandModel.js" as Model

// What the island opens into when nothing is live: the time with the
// weather beside it, now-playing below while something is playing, the
// battery on the right, and one-tap timers and a stopwatch at the bottom.
Item {
  id: view

  property var island: null
  readonly property int pad: island.s(26)
  readonly property var nextEvent: island.calendar.next

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
    font.letterSpacing: -1
    font.features: { "tnum": 1 }
    color: island.fg
  }

  // Weather card: a taller mini-card from the time's right to the panel's
  // right edge, so it fills the gap instead of a thin strip: conditions and
  // temp, the sky's own word, then the ranges beneath, and a third line of
  // whatever is most actionable — the next umbrella window, else the sun
  // times, else feels-like. A tap still opens the full pane.
  Rectangle {
    id: weatherChip
    visible: island.showWeather
    anchors.left: timeText.right
    anchors.leftMargin: view.island.s(14)
    anchors.right: parent.right
    anchors.rightMargin: view.pad
    y: island.s(14)
    height: island.s(62)
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
      anchors.fill: parent
      anchors.margins: view.island.s(8)
      spacing: view.island.s(2)

      Row {
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

  // Battery: small and dim beside the date, freeing the whole right side of
  // the clock row for the weather chip.
  Text {
    visible: island.hasBattery
    x: view.pad + island.s(180)
    anchors.verticalCenter: dateLine.verticalCenter
    text: Model.batteryIcon(island.batteryLevel, island.charging) + " "
      + Model.percentText(island.batteryLevel) + (island.charging ? " ·chg" : "")
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.fontFamily
    font.pixelSize: island.f(12)
    font.features: { "tnum": 1 }
    color: island.charging ? island.greenColor
      : (island.batteryLevel <= 0.2 ? island.urgentColor : island.fgDim)
  }

  // Now playing, full width below the clock row — while something is live.
  // Clicking anywhere on it opens the player pane.
  Rectangle {
    id: mediaRow
    visible: island.mediaActivity && island.hasMedia
    x: view.pad
    y: island.s(80)
    width: parent.width - view.pad * 2
    height: island.s(22)
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
      text: (island.mediaTitle || "Now playing")
        + (island.mediaArtist !== "" ? "  ·  " + island.mediaArtist : "")
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.textFamily
      font.pixelSize: island.f(11)
      color: island.mediaPlaying ? island.fg : island.fgDim
      elide: Text.ElideRight
      width: parent.width - island.s(96)
    }

    // Quick transport on the row itself: prev, play/pause, next.
    Row {
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

    MouseArea {
      id: mediaMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: island.openMediaPane()
    }
  }

  // System quick settings, in place of the timer chips: the island's own
  // do-not-disturb, the omarchy CLI's night light, a walk through the
  // installed themes, and the lock screen. Each fires its action on tap.
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island.s(16)
    spacing: island.s(8)

    Repeater {
      model: [
        { label: "DND", glyph: island.dndActive ? "󰂛" : "󰂚", on: island.dndActive },
        { label: "Night", glyph: "󰖜", on: false },
        { label: "Theme", glyph: "󰏘", on: false },
        { label: "Lock", glyph: "󰌾", on: false }
      ]

      Rectangle {
        id: chip
        required property var modelData
        height: island.s(28)
        width: chipLabel.implicitWidth + island.s(20)
        radius: height / 2
        color: Util.alpha(chip.modelData.on ? island.accentColor : island.fg,
                          chipMouse.pressed ? 0.30 : (chipMouse.containsMouse ? 0.18 : 0.11))
        scale: chipMouse.pressed ? 0.94 : 1

        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          id: chipLabel
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
          onClicked: {
            if (chip.modelData.label === "DND") { island.toggleDnd(); return }
            if (chip.modelData.label === "Night") { island.runShell(["omarchy", "toggle", "nightlight"]); return }
            if (chip.modelData.label === "Theme") { island.cycleTheme(); return }
            island.runShell(["omarchy", "system", "lock"])
          }
        }
      }
    }
  }
}
