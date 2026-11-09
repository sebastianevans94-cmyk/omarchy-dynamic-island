import QtQuick
import qs.Commons
import "../IslandModel.js" as Model

// The full weather pane the drop-down's weather tile opens into: current
// conditions with feels-like, wind and humidity, and a three-day forecast.
// The back button returns to the drop-down rather than closing the island.
Item {
  id: view

  property var island: null
  readonly property var w: island.weather
  readonly property bool ready: island.weatherReady && !!w
  readonly property int pad: island.s(26)

  Text {
    y: view.island.s(18)
    anchors.left: parent.left
    anchors.leftMargin: view.pad
    text: view.ready && view.w.label !== "" ? "󰔎  " + view.w.label
      : (view.island.weatherSource.status === "fetching" ? "󰔎  Locating…"
      : (view.ready ? "󰔎  Weather" : "󰔎  Weather unavailable"))
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: view.island.textFamily
    font.pixelSize: view.island.f(13)
    font.weight: Font.DemiBold
    color: view.island.fg
    elide: Text.ElideRight
    width: parent.width - view.pad * 3
  }

  Text {
    id: back
    y: view.island.s(18)
    anchors.right: parent.right
    anchors.rightMargin: view.pad - view.island.s(6)
    text: "← Back"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: view.island.textFamily
    font.pixelSize: view.island.f(12)
    color: view.island.fgDim
    scale: backMouse.pressed ? 0.94 : 1

    Behavior on scale { NumberAnimation { duration: 120 } }

    MouseArea {
      id: backMouse
      anchors.fill: parent
      anchors.margins: -view.island.s(6)
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: view.island.closeWeather()
    }
  }

  // Not ready: what's happening, and a manual poke.
  Column {
    anchors.centerIn: parent
    spacing: view.island.s(10)
    visible: !view.ready

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: view.island.weatherSource.status === "error" ? "The weather service isn't answering"
        : "Getting the weather…"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: view.island.textFamily
      font.pixelSize: view.island.f(13)
      color: view.island.fgDim
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "󰑐  Retry now"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: view.island.textFamily
      font.pixelSize: view.island.f(12)
      color: view.island.accentColor
      scale: retryMouse.pressed ? 0.94 : 1

      Behavior on scale { NumberAnimation { duration: 120 } }

      MouseArea {
        id: retryMouse
        anchors.fill: parent
        anchors.margins: -view.island.s(6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: view.island.weatherSource.refresh()
      }
    }
  }

  // Current conditions: the glyph (one quiet breathe) rides with the
  // transformed temperature, details beside it. Numbers in the theme's
  // monospace, tabular so widths hold.
  WeatherGlyph {
    id: heroGlyph
    visible: view.ready
    anchors.left: parent.left
    anchors.leftMargin: view.pad
    y: view.island.s(60)
    size: view.island.f(46)
    glyph: view.ready ? view.w.icon : ""
    color: view.island.fg
    fontFamily: view.island.fontFamily
  }

  Row {
    visible: view.ready
    anchors.left: heroGlyph.right
    anchors.leftMargin: view.island.s(16)
    anchors.verticalCenter: heroGlyph.verticalCenter
    spacing: view.island.s(20)

    Column {
      spacing: view.island.s(2)

      Text {
        text: view.w ? (view.w.tempC === "" ? "—" : Model.weatherTempText(view.w.tempC, view.w.tempF, view.island.weatherImperial)) : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.fontFamily
        font.pixelSize: view.island.f(30)
        font.weight: Font.Light
        font.features: { "tnum": 1 }
        color: view.island.fg
      }

      Text {
        text: view.w ? (view.w.tempC === "" ? "" : "feels " + Model.weatherTempText(view.w.feelsC, view.w.feelsF, view.island.weatherImperial)) : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.textFamily
        font.pixelSize: view.island.f(11)
        font.features: { "tnum": 1 }
        color: view.island.fgDim
      }
    }

    Column {
      spacing: view.island.s(2)

      Text {
        text: view.w ? (view.w.windKmph === "" ? "" : "󰳢  " + (view.island.weatherImperial ? view.w.windMph + " mph" : view.w.windKmph + " km/h")) : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.textFamily
        font.pixelSize: view.island.f(11)
        font.features: { "tnum": 1 }
        color: view.island.fgDim
      }

      Text {
        text: view.w ? (view.w.humidity === "" ? "" : "󰗎  " + view.w.humidity + "%") : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.textFamily
        font.pixelSize: view.island.f(11)
        font.features: { "tnum": 1 }
        color: view.island.fgDim
      }
    }
  }

  // Hairline between the hero and the forecast, like the island's rim.
  Rectangle {
    visible: view.ready
    x: view.pad - view.island.s(6)
    y: view.island.s(144)
    width: parent.width - (view.pad - view.island.s(6)) * 2
    height: 1
    color: Util.alpha(view.island.fg, 0.14)
  }

  // The next 12 hours of rain probability, plus the sun times, from
  // open-meteo. Bars rise with the probability; ones worth an umbrella take
  // the accent. Hidden when wttr answered (it has neither feed).
  Item {
    visible: view.ready && view.w && view.w.rain && view.w.rain.length > 0
    x: view.pad
    y: view.island.s(106)
    width: parent.width - view.pad * 2
    height: view.island.s(30)

    Row {
      id: rainRow
      anchors.bottom: parent.bottom
      anchors.bottomMargin: view.island.s(11)
      spacing: view.island.s(2)

      Repeater {
        model: view.ready && view.w.rain ? view.w.rain : []

        Item {
          required property var modelData
          width: view.island.s(10)
          height: view.island.s(16)

          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(view.island.s(2), view.island.s(16) * modelData.pct / 100)
            radius: width / 3
            color: modelData.pct >= 55 ? view.island.accentColor : Util.alpha(view.island.fg, 0.38)
          }
        }
      }
    }

    Row {
      anchors.left: rainRow.right
      anchors.leftMargin: view.island.s(10)
      anchors.verticalCenter: rainRow.verticalCenter
      spacing: view.island.s(10)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: view.w && view.w.sunrise !== "" ? "󰖜  " + view.w.sunrise : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.textFamily
        font.pixelSize: view.island.f(11)
        font.features: { "tnum": 1 }
        color: view.island.fgDim
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: view.w && view.w.sunset !== "" ? "󰖛  " + view.w.sunset : ""
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.textFamily
        font.pixelSize: view.island.f(11)
        font.features: { "tnum": 1 }
        color: view.island.fgDim
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "·  rain next 12 h"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: view.island.textFamily
        font.pixelSize: view.island.f(9)
        color: Util.alpha(view.island.fg, 0.45)
      }
    }
  }

  // Three days: today and the two after. Today reads in the accent, the
  // rest dim, so the order needs no words.
  Row {
    visible: view.ready
    anchors.horizontalCenter: parent.horizontalCenter
    y: view.island.s(156)
    spacing: view.island.s(36)

    Repeater {
      model: view.ready ? view.w.days : []

      delegate: Column {
        id: dayCol
        required property var modelData
        required property int index

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: dayCol.modelData.name
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: view.island.textFamily
          font.pixelSize: view.island.f(11)
          font.weight: Font.DemiBold
          color: dayCol.index === 0 ? view.island.accentColor : view.island.fgDim
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: dayCol.modelData.icon
          textFormat: Text.PlainText
          font.family: view.island.fontFamily
          font.pixelSize: view.island.f(20)
          color: view.island.fg
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "H " + Model.weatherTempText(dayCol.modelData.maxC, dayCol.modelData.maxF, view.island.weatherImperial)
            + " · " + "L " + Model.weatherTempText(dayCol.modelData.minC, dayCol.modelData.minF, view.island.weatherImperial)
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
          font.family: view.island.fontFamily
          font.pixelSize: view.island.f(11)
          font.features: { "tnum": 1 }
          color: view.island.fg
        }
      }
    }
  }
}
