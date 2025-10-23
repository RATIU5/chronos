import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
  id: root
  
  // Helper function to get app name from desktop entries
  function getAppName(appId) {
    if (!appId) return "Desktop"
    
    // Try to find a matching desktop entry
    var entry = DesktopEntries.byId(appId)
    if (entry) {
      return entry.name || appId
    }
    
    // Fallback: capitalize the appId
    return appId.charAt(0).toUpperCase() + appId.slice(1)
  }
  
  RowLayout {
    id: rowLayout
    
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 10
    
    Text {
      Layout.fillWidth: true
      font.pixelSize: 14
      color: "#e0e0e0"
      text: {
        var toplevel = Hyprland.activeToplevel
        if (!toplevel) return "Desktop"
        
        // Try appId first, then try looking at the title as a fallback
        var appId = toplevel.appId
        return root.getAppName(appId)
      }
    }
    
    Text {
      Layout.fillWidth: true
      font.pixelSize: 14
      color: "#e0e0e0"
      text: Hyprland.activeToplevel?.title ?? "No active window"
    }
  }
}