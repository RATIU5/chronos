import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
  id: root
  
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: 30
      color: "#1e1e2e"

      RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
          width: 20
          height: 20
          color: "#1e1e2e"

          Image {
            anchors.centerIn: parent
            source: "qrc:assets/desktop.svg"
            width: 20
            height: 20
            sourceSize: Qt.size(width, height)
            smooth: true
          }

          Text {
            anchors.centerIn: parent
            text: `${Hyprland.focusedWorkspace?.id}`
            color: "#cdd6f4"
            font.pixelSize: 12
          }
        }

        Item {
          Layout.fillWidth: true
        }

        Text {
          anchors.centerIn: parent
          text: Time.time
          color: "#cdd6f4"
          font.pixelSize: 14
        }
      }
    }
  }
}
