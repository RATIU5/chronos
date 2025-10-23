import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
  id: root
  
  RowLayout {
    id: rowLayout
    
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 10
    
    Text {
      Layout.fillWidth: true
      font.pixelSize: 14
      color: "#e0e0e0"
      text: Hyprland.activeToplevel?.appId ?? "Desktop"
    }
    
    Text {
      Layout.fillWidth: true
      font.pixelSize: 14
      color: "#e0e0e0"
      text: Hyprland.activeToplevel?.title ?? "No active window"
    }
  }
}