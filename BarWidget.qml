import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "paudelsamir.nowplaying"

  // ---- MPRIS players ----
  readonly property var nowPlayingPlayers: {
    var values = Mpris.players ? Mpris.players.values : []
    var playing = []
    var paused = []
    for (var i = 0; i < values.length; i++) {
      var player = values[i]
      if (!player || !(player.trackTitle || player.trackArtist)) continue
      if (player.isPlaying) playing.push(player)
      else paused.push(player)
    }
    return playing.concat(paused)
  }
  readonly property var nowPlayingPlayer: root.nowPlayingPlayers.length > 0
    ? root.nowPlayingPlayers[0] : null
  readonly property bool hasNowPlaying: root.nowPlayingPlayers.length > 0
  readonly property bool isPlaying: !!root.nowPlayingPlayer && !!root.nowPlayingPlayer.isPlaying

  // ---- Settings ----
  readonly property bool showIcon: root.setting("showIcon", true) !== false
  readonly property bool showTitle: root.setting("showTitle", false) !== false
  readonly property bool showArtist: root.setting("showArtist", false) !== false
  readonly property bool highlightPlaying: root.setting("highlightPlaying", true) !== false
  readonly property bool showWhenNoMedia: root.setting("showWhenNoMedia", true) !== false
  readonly property int maxTitleLength: Number(root.setting("maxTitleLength", 28)) || 28
  readonly property string idleIcon: String(root.setting("idleIcon", "󰎄"))
  readonly property string playingIcon: String(root.setting("playingIcon", "󱖒"))
  readonly property string pausedIcon: String(root.setting("pausedIcon", "󱖏"))
  readonly property real widgetOpacity: {
    var o = root.setting("opacity", 1.0)
    return (o === undefined || o === null) ? 1.0 : Number(o)
  }

  visible: root.showWhenNoMedia || root.hasNowPlaying
  implicitWidth: visible ? (content.implicitWidth + Style.space(14)) : 0
  implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

  readonly property string displayTitle: {
    if (!root.nowPlayingPlayer) return ""
    var t = String(root.nowPlayingPlayer.trackTitle || "")
    if (t.length > root.maxTitleLength) t = t.slice(0, root.maxTitleLength) + "…"
    return t
  }
  readonly property string displayArtist: {
    if (!root.nowPlayingPlayer) return ""
    var a = String(root.nowPlayingPlayer.trackArtist || "")
    // avoid duplicates
    if (a !== "" && a === root.displayTitle) a = ""
    if (a.length > root.maxTitleLength) a = a.slice(0, root.maxTitleLength) + "…"
    return a
  }
  readonly property string barIcon: {
    if (!root.hasNowPlaying) return root.idleIcon
    return root.isPlaying ? root.playingIcon : root.pausedIcon
  }
  readonly property string barText: {
    var parts = []
    if (root.showTitle && root.displayTitle) parts.push(root.displayTitle)
    if (root.showArtist && root.displayArtist) parts.push(root.displayArtist)
    return parts.join("  ·  ")
  }

  readonly property color barForeground: root.bar ? root.bar.barForeground : Color.foreground
  // Exposed so the panel can re-anchor to the live button after a move.
  property var buttonItem: button

  // ---- Panel lifecycle (calendar pattern) ----
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function togglePanel() { root.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = root.buttonItem
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onOpenedChanged: if (opened) injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  ShellIpc {
    target: "paudelsamir.nowplaying"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  // ---- Visual content ----
  Row {
    id: content
    anchors.centerIn: parent
    opacity: root.widgetOpacity
    spacing: Style.space(6)

    Text {
      visible: root.showIcon
      text: root.barIcon
      color: root.highlightPlaying && root.isPlaying
        ? Color.accent : root.barForeground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.icon
      anchors.verticalCenter: parent.verticalCenter
      Behavior on color { ColorAnimation { duration: Style.duration(160) } }
    }

    Text {
      visible: root.showTitle || root.showArtist
      text: root.barText
      color: root.barForeground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      width: Math.min(implicitWidth, Style.space(200))
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    keepSpace: true
    text: "\u200b"
    tooltipText: root.hasNowPlaying
      ? (root.displayTitle + (root.displayArtist ? " — " + root.displayArtist : ""))
      : "No media playing"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
      else if (b === Qt.MiddleButton) {
        if (root.nowPlayingPlayer) {
          if (root.nowPlayingPlayer.isPlaying && root.nowPlayingPlayer.canPause) root.nowPlayingPlayer.pause()
          else if (root.nowPlayingPlayer.canPlay) root.nowPlayingPlayer.play()
          else if (root.nowPlayingPlayer.canTogglePlaying) root.nowPlayingPlayer.togglePlaying()
        }
      } else if (b === Qt.RightButton) {
        root.open()
        Qt.callLater(function() {
          if (panelLoader.item && typeof panelLoader.item.toggleSettings === "function")
            panelLoader.item.toggleSettings()
        })
      }
    }
  }

  // scroll to change track (via WidgetButton's wheelMoved signal so hover
  // stays on the button and its tooltip keeps working)
  Connections {
    target: button
    function onWheelMoved(delta) {
      if (!root.nowPlayingPlayer) return
      if (delta > 0) {
        if (root.nowPlayingPlayer.canGoPrevious) root.nowPlayingPlayer.previous()
      } else if (delta < 0) {
        if (root.nowPlayingPlayer.canGoNext) root.nowPlayingPlayer.next()
      }
    }
  }
}