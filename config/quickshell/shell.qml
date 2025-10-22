import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
  id: root

  Time {}

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

        Repeater {
          model: Hyprland.workspaces

          Rectangle {
            required property var modelData
            width: 20
            height: 20
            radius: 4

            color: modelData.id === Hyprland.focusedWorkspace?.id ? "#89b4fa" : "#45475a"

            Text {
              anchors.centerIn: parent
              text: parent.modelData.id
              color: "#cdd6f4"
              font.pixelSize: 12
            }

            MouseArea {
              anchors.fill: parent
              onClicked: parent.modelData.activate()
            }
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
