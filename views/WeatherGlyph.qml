import QtQuick

// A weather glyph that breathes: one slow opacity pulse, nothing else.
// At this size (a few tens of pixels on a bar) most theatrics read as
// noise — so the live part is one quiet signal: the sky pulses once,
// gently, and otherwise sits perfectly still like every other token.
Item {
  id: weatherGlyph

  property string glyph: ""
  property int size: 16
  property color color: "white"

  implicitWidth: size
  implicitHeight: size

  Text {
    id: mainGlyph
    anchors.centerIn: parent
    text: weatherGlyph.glyph
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: weatherGlyph.fontFamily
    font.pixelSize: weatherGlyph.size
    color: weatherGlyph.color

    Behavior on color { ColorAnimation { duration: 400 } }

    SequentialAnimation on opacity {
      // Breathing only while actually shown: an always-running infinite
      // animation ticks the paint loop even when the island is hidden.
      running: weatherGlyph.visible
      loops: Animation.Infinite
      NumberAnimation { to: 0.72; duration: 2400; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1.0; duration: 2400; easing.type: Easing.InOutSine }
    }
  }

  property string fontFamily: ""
}
