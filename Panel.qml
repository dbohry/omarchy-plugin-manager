import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "plugin-manager"
  ipcTarget: "plugin-manager"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string pluginIcon: String.fromCodePoint(0xf0431)

  // Raw rows from `omarchy-plugin-list --json`, sorted by display name.
  property var plugins: []
  property string filterText: ""
  readonly property var filteredPlugins: {
    var needle = filterText.trim().toLowerCase()
    if (needle === "") return plugins
    return plugins.filter(function(p) {
      return String(p.name).toLowerCase().indexOf(needle) >= 0
        || String(p.id).toLowerCase().indexOf(needle) >= 0
    })
  }
  readonly property bool busy: actionProc.running || listProc.running
  property string focusSection: "restart"  // "restart" | "list"
  property int selectedIndex: -1

  function refresh() {
    if (listProc.running) return
    listProc.running = true
  }

  function updatePlugins(raw) {
    var parsed = []
    try { parsed = JSON.parse(raw) } catch (e) { parsed = [] }
    parsed.sort(function(a, b) { return String(a.name).localeCompare(String(b.name)) })
    root.plugins = parsed
  }

  function togglePlugin(p) {
    if (!p || root.busy || !p.canDisable) return
    actionProc.command = [p.enabled ? "omarchy-plugin-disable" : "omarchy-plugin-enable", p.id]
    actionProc.running = true
  }

  function restartShell() {
    Quickshell.execDetached(["bash", "-c", "omarchy restart shell"])
    root.close()
  }

  function ensureCursor() {
    if (root.filteredPlugins.length === 0) { focusSection = "restart"; return }
    if (focusSection === "list") {
      if (selectedIndex < 0) selectedIndex = 0
      if (selectedIndex >= root.filteredPlugins.length) selectedIndex = root.filteredPlugins.length - 1
    }
  }

  function moveCursor(dy) {
    if (dy === 0) return
    if (focusSection === "restart") {
      if (dy > 0 && root.filteredPlugins.length > 0) { focusSection = "list"; selectedIndex = 0 }
      return
    }
    if (dy < 0 && selectedIndex <= 0) { focusSection = "restart"; return }
    selectedIndex = Math.max(0, Math.min(root.filteredPlugins.length - 1, selectedIndex + dy))
  }

  function activateCursor() {
    if (focusSection === "restart") restartShell()
    else if (selectedIndex >= 0 && selectedIndex < root.filteredPlugins.length) togglePlugin(root.filteredPlugins[selectedIndex])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    focusSection = "restart"
    selectedIndex = -1
    filterText = ""
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onFilteredPluginsChanged: ensureCursor()

  Process {
    id: listProc
    command: ["omarchy-plugin-list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updatePlugins(text)
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.pluginIcon
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        root.ensureCursor()
        root.moveCursor(dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelSectionHeader {
            text: "PLUGINS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Button {
            width: parent.width
            text: root.busy ? "Restarting…" : "Restart Shell"
            bordered: true
            enabled: !root.busy
            foreground: root.foreground
            fontFamily: root.fontFamily
            hasCursor: root.focusSection === "restart"
            onHovered: function(isHovered) { if (isHovered) { root.focusSection = "restart" } }
            onClicked: root.restartShell()
          }

          PanelSeparator {
            foreground: root.foreground
          }

          TextField {
            id: searchField
            width: parent.width
            placeholderText: "Filter plugins…"
            foreground: root.foreground
            accent: root.accent
            text: root.filterText
            onTextChanged: root.filterText = text
          }

          Text {
            visible: root.filteredPlugins.length === 0
            width: parent.width
            text: root.busy ? "Loading plugins…" : (root.filterText === "" ? "No plugins found." : "No plugins match \"" + root.filterText + "\".")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.filteredPlugins

              PluginRow {
                required property var modelData
                required property int index
                width: parent.width
                plugin: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component PluginRow: Toggle {
    id: row
    property var plugin: null
    property int rowIndex: -1

    label: plugin ? plugin.name : ""
    description: plugin
      ? (plugin.id + (plugin.canDisable ? "" : " · required, cannot be disabled"))
      : ""
    foreground: root.foreground
    accent: root.accent
    fontFamily: root.fontFamily
    checked: plugin ? !!plugin.enabled : false
    enabled: plugin ? plugin.canDisable && !root.busy : false
    opacity: enabled ? 1.0 : 0.55
    hasCursor: root.focusSection === "list" && root.selectedIndex === rowIndex

    onHovered: function(isHovered) {
      if (isHovered) { root.focusSection = "list"; root.selectedIndex = rowIndex }
    }
    onClicked: {
      root.focusSection = "list"
      root.selectedIndex = rowIndex
      root.togglePlugin(plugin)
    }
  }
}
