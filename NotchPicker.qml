import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Horizontal theme / background picker shown inside the expanded notch.
// Moving the selection applies it live (debounced, theme-set is slow); Enter or
// clicking the selected card keeps it, Escape or clicking outside reverts to
// what was active when the picker opened.
Item {
  id: picker

  property string kind: "" // "theme" | "background" | "" (closed)
  property color foreground: Color.foreground
  property color accent: Color.accent
  signal done()
  signal cancelled()

  property string original: ""
  property string applied: ""
  property bool ready: false
  readonly property int cardWidth: 160
  readonly property int cardHeight: 100

  ListModel { id: itemsModel }

  function open(k) {
    applyTimer.stop()
    ready = false
    kind = k
    original = ""
    applied = ""
    itemsModel.clear()
    listProc.command = ["bash", "-c", k === "theme" ? themeScript : backgroundScript]
    listProc.running = true
    Qt.callLater(function() { list.forceActiveFocus() })
  }

  // Closing without confirming: put back what was active on open.
  function revert() {
    applyTimer.stop()
    if (kind !== "" && applied !== "" && applied !== original) run(original)
    kind = ""
    ready = false
  }

  function confirm() {
    applyTimer.stop()
    var v = currentValue()
    if (v && v !== applied) run(v)
    original = applied // makes the revert on close a no-op
    done()
  }

  function currentValue() {
    return list.currentIndex >= 0 && list.currentIndex < itemsModel.count ? itemsModel.get(list.currentIndex).value : ""
  }

  function run(v) {
    if (!v) return
    applied = v
    Quickshell.execDetached(kind === "theme" ? ["omarchy-theme-set", v] : ["omarchy-theme-bg-set", v])
  }

  // Output: value <TAB> current-flag <TAB> preview path
  readonly property string themeScript: '
    cur=$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null)
    declare -A seen
    for d in ~/.config/omarchy/themes/*/ "${OMARCHY_PATH:-/usr/share/omarchy}"/themes/*/; do
      [[ -d $d ]] || continue
      n=$(basename "$d"); [[ -n ${seen[$n]} ]] && continue; seen[$n]=1
      p=$(find -L "$d" -maxdepth 1 -type f -iname "preview.*" 2>/dev/null | head -1)
      [[ -z $p ]] && p=$(find -L "$d/backgrounds" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) 2>/dev/null | sort | head -1)
      printf "%s\t%s\t%s\n" "$n" "$([[ $n == "$cur" ]] && echo 1)" "$p"
    done | sort'

  readonly property string backgroundScript: '
    t=$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null)
    cur=$(readlink -f ~/.local/state/omarchy/current/background 2>/dev/null)
    find -L ~/.local/state/omarchy/current/theme/backgrounds ~/.config/omarchy/backgrounds/"$t" -maxdepth 1 -type f \
      \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \\) 2>/dev/null |
      while read -r f; do r=$(readlink -f "$f"); printf "%s\t%s\t%s\n" "$r" "$([[ $r == "$cur" ]] && echo 1)" "$r"; done | sort -u'

  function labelFor(value) {
    if (kind === "theme") return value.split("-").map(function(w) { return w.charAt(0).toUpperCase() + w.slice(1) }).join(" ")
    var base = value.split("/").pop()
    return base.replace(/\.[^.]+$/, "")
  }

  Process {
    id: listProc
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        var currentIdx = 0
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (!parts[0]) continue
          if (parts[1] === "1") currentIdx = itemsModel.count
          itemsModel.append({ value: parts[0], label: picker.labelFor(parts[0]), preview: parts[2] || "" })
        }
        list.currentIndex = currentIdx
        list.positionViewAtIndex(currentIdx, ListView.Center)
        picker.original = picker.currentValue()
        picker.applied = picker.original
        picker.ready = true
      }
    }
  }

  Timer {
    id: applyTimer
    interval: picker.kind === "theme" ? 450 : 250
    onTriggered: picker.run(picker.currentValue())
  }

  Text {
    id: title
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    text: (picker.kind === "theme" ? "Theme" : "Background") + (list.currentIndex >= 0 && list.currentIndex < itemsModel.count ? "  ·  " + itemsModel.get(list.currentIndex).label : "")
    color: picker.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.weight: Font.DemiBold
  }

  ListView {
    id: list
    anchors.top: title.bottom
    anchors.topMargin: 10
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    orientation: ListView.Horizontal
    spacing: 10
    clip: true
    model: itemsModel
    // Selected card stays centered; flicking (touchpad) moves the selection too
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: (width - picker.cardWidth) / 2
    preferredHighlightEnd: (width + picker.cardWidth) / 2
    highlightMoveDuration: 160
    boundsBehavior: Flickable.StopAtBounds

    onCurrentIndexChanged: if (picker.ready) applyTimer.restart()

    Keys.onReturnPressed: picker.confirm()
    Keys.onEnterPressed: picker.confirm()
    Keys.onEscapePressed: picker.cancelled()

    // Mouse wheel (vertical) steps one card per notch
    property real wheelAccum: 0
    WheelHandler {
      onWheel: function(event) {
        var d = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x) ? event.angleDelta.y : event.angleDelta.x
        list.wheelAccum += d
        while (list.wheelAccum <= -120) { list.wheelAccum += 120; list.incrementCurrentIndex() }
        while (list.wheelAccum >= 120) { list.wheelAccum -= 120; list.decrementCurrentIndex() }
      }
    }

    delegate: Item {
      id: card
      required property int index
      required property string label
      required property string preview
      readonly property bool selected: ListView.isCurrentItem
      width: picker.cardWidth
      height: ListView.view.height

      Rectangle {
        id: frame
        width: picker.cardWidth
        height: picker.cardHeight
        radius: 8
        color: Qt.rgba(picker.foreground.r, picker.foreground.g, picker.foreground.b, 0.08)
        border.width: card.selected ? 2 : 0
        border.color: picker.accent

        Image {
          anchors.fill: parent
          anchors.margins: 4
          source: card.preview ? "file://" + card.preview : ""
          sourceSize.width: 320
          sourceSize.height: 200
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
        }
      }

      Text {
        anchors.top: frame.bottom
        anchors.topMargin: 6
        width: picker.cardWidth
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: card.label
        color: picker.foreground
        opacity: card.selected ? 1.0 : 0.6
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (list.currentIndex === card.index) picker.confirm()
          else list.currentIndex = card.index
        }
      }
    }
  }
}
