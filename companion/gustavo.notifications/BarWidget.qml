import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Ui

// Bell for the notch: filled when history has notifications, hollow when empty,
// slashed in DND. Same color as the other widget icons (no active/urgent tint).
// Left click opens the notch's notification history, right click toggles DND.
BarWidget {
  id: root
  moduleName: "gustavo.notifications"

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/"
  readonly property int count: historyFolder.count
  property bool dnd: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FolderListModel {
    id: historyFolder
    folder: "file://" + root.stateDir + "notifications/history"
    nameFilters: ["*.json"]
    showDirs: false
  }

  FileView {
    path: root.stateDir + "notifications.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.dnd = !!JSON.parse(text()).dnd } catch (e) { root.dnd = false }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.dnd ? "󰂛" : (root.count > 0 ? "󰂚" : "󰂜")
    tooltipText: root.dnd ? "Do not disturb" : (root.count > 0 ? root.count + " notifications" : "No notifications")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.bar.run("omarchy-toggle-notification-silencing")
      else root.bar.run("omarchy-shell notifications showHistory")
    }
  }
}
