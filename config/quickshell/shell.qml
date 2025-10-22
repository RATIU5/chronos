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

      implicitHeight: 36
      color: "#121212"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        spacing: 8

        Rectangle {
          width: 36
          height: 36
          color: "#121212"

          Image {
            anchors.centerIn: parent
            source: `data:image/svg+xml;utf8,<?xml version="1.0" encoding="UTF-8" standalone="no"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg width="100%" height="100%" viewBox="0 0 24 18" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xml:space="preserve" xmlns:serif="http://www.serif.com/" style="fill-rule:evenodd;clip-rule:evenodd;stroke-linejoin:round;stroke-miterlimit:2;"><g><rect x="0" y="0" width="23.389" height="17.979" style="fill-opacity:0;"/><path d="M1.045,3.291l-0,1.377l20.937,-0l0,-1.377l-20.937,0Zm3.076,14.688l15.029,-0c2.461,-0 3.877,-1.485 3.877,-4.122l0,-9.726c0,-2.637 -1.416,-4.131 -3.877,-4.131l-15.029,0c-2.627,0 -4.121,1.494 -4.121,4.131l0,9.726c0,2.637 1.494,4.122 4.121,4.122Zm0.01,-1.573c-1.621,0 -2.559,-0.927 -2.559,-2.549l0,-9.726c0,-1.621 0.938,-2.559 2.559,-2.559l14.766,0c1.621,0 2.558,0.938 2.558,2.559l0,9.726c0,1.622 -0.937,2.549 -2.558,2.549l-14.766,0Z" style="fill:#e0e0e0;fill-rule:nonzero;"/></g></svg>`
            width: 28
            height: 23
            sourceSize: Qt.size(width, height)
            smooth: true
          }

          Text {
            anchors.centerIn: parent
            text: `${Hyprland.focusedWorkspace?.id}`
            font.family: Fonts.displayRegular.name
            font.bold: true
            color: "#e0e0e0"
            font.pixelSize: 12
            topPadding: 3
            rightPadding: 1
          }
        }

        Item {
          Layout.fillWidth: true
        }
      }
    }
  }
}
