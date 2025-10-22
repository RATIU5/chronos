import Quickshell
import QtQuick

PanelWindow {
  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 30
  color: "#1e1e2e"

  Text {
    id: clockText
    anchors.centerIn: parent
    text: "Loading..."
    color: "#cdd6f4"
    font.pixelSize: 14
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
    onDateChanged: {
      clockText.text = Qt.formatDateTime(date, "hh:mm:ss")
    }
  }
}