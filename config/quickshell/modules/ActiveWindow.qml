import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
  id: root
  
  property string cachedAppName: "Desktop"
  
  // Watch for changes to the active toplevel
  Connections {
    target: Hyprland
    
    function onActiveToplevelChanged() {
      // This fires when the active window changes
      if (Hyprland.activeToplevel) {
        windowTitleProcess.running = true
      } else {
        root.cachedAppName = "Desktop"
      }
    }
  }
  
  Process {
    id: windowTitleProcess
    command: ["bash", "-c", "hyprctl activewindow -j | jq -r '.initialTitle'"]
    running: false
    
    stdout: StdioCollector {
      onStreamFinished: {
        root.cachedAppName = this.text.trim() || "Desktop"
      }
    }
  }
  
  Component.onCompleted: {
    if (Hyprland.activeToplevel) {
      windowTitleProcess.running = true
    }
  }
  
  Text {
    font.pixelSize: 14
    color: "#e0e0e0"
    text: root.cachedAppName
  }
}