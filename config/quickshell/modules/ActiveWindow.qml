import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
  id: root
  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
  readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

  property string activeWindowAddress: `0x${activeWindow?.HyprlandToplevel?.address}`
  property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name
  property var biggestWindow: HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id)

  RowLayout {
    id: rowLayout

    anchors.horizontalCenter: parent.horizontalCenter
    spacing: -4

    Text {
      Layout.fillWidth: true
      font.pixelSize: 14
      color: "#e0e0e0"
      text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ? 
        root.activeWindow?.appId :
        (root.biggestWindow?.class) ?? "Desktop"
    }

    Text {
      Layout.fillWidth: true
      font.pixelSize: 14
      color: "#e0e0e0"
      text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ? 
        root.activeWindow?.title :
        (root.biggestWindow?.title) ?? `Workspace ${monitor?.activeWorkspace?.id ?? 1}`
    }
  }
}