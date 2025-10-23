import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
  id: root
  implicitHeight: 36
  
  property string cachedAppName: "Desktop"
  
  function processTitle(rawTitle) {
    if (!rawTitle || rawTitle === "") {
      return "Desktop"
    }
    
    const cleanupRules = [
      { pattern: /^.*\s-\s(Chromium|Google Chrome)$/i, replacement: "$1" },
      { pattern: /^.*\s-\s(Mozilla Firefox|Firefox)$/i, replacement: "Firefox" },
      { pattern: /^.*\s-\s(.+)$/, replacement: "$1" },
    ]
    
    for (let rule of cleanupRules) {
      let match = rawTitle.match(rule.pattern)
      if (match) {
        return rawTitle.replace(rule.pattern, rule.replacement)
      }
    }
    
    return rawTitle
  }
  
  Connections {
    target: Hyprland
    
    function onActiveToplevelChanged() {
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
        let rawTitle = this.text.trim()
        root.cachedAppName = root.processTitle(rawTitle)
      }
    }
  }
  
  Component.onCompleted: {
    if (Hyprland.activeToplevel) {
      windowTitleProcess.running = true
    }
  }
  
  Text {
    anchors.centerIn: parent
    font.pixelSize: 14
    font.bold: true
    color: "#e0e0e0"
    text: root.cachedAppName
  }
}