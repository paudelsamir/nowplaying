import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "paudelsamir.nowplaying"
  ipcTarget: "paudelsamir.nowplaying"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property bool settingsOpen: false
  function toggleSettings() { root.settingsOpen = !root.settingsOpen }
  function setSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function resetSettings() {
    var defaults = {
      showIcon: true,
      showTitle: true,
      showArtist: false,
      highlightPlaying: true,
      showWhenNoMedia: true,
      maxTitleLength: 28,
      opacity: 1.0,
      idleIcon: "󰎄",
      playingIcon: "󱖒",
      pausedIcon: "󱖏"
    }
    var entry = { id: root.moduleName }
    for (var k in defaults) entry[k] = defaults[k]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

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

  // ---- helpers ----
  function formatNowPlayingTime(seconds) {
    var total = Math.floor(Math.max(0, Number(seconds) || 0))
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var secs = total % 60
    var pad = function(value) { return value < 10 ? "0" + value : String(value) }
    return hours > 0
      ? hours + ":" + pad(minutes) + ":" + pad(secs)
      : minutes + ":" + pad(secs)
  }
  function nowPlayingMeta(player) {
    if (!player) return ""
    var parts = []
    var artist = String(player.trackArtist || "")
    var album = String(player.trackAlbum || "")
    if (artist !== "") parts.push(artist)
    if (album !== "" && album !== artist) parts.push(album)
    return parts.join("  ·  ")
  }
  function nowPlayingFraction(player) {
    if (!player || !player.positionSupported || !player.lengthSupported
        || !(player.length > 0)) return 0
    return Math.max(0, Math.min(1, player.position / player.length))
  }
  function toggleNowPlaying(target) {
    var player = target || root.nowPlayingPlayer
    if (!player) return
    if (player.canTogglePlaying) player.togglePlaying()
    else if (player.isPlaying && player.canPause) player.pause()
    else if (!player.isPlaying && player.canPlay) player.play()
  }
  function stepNowPlaying(direction, target) {
    var player = target || root.nowPlayingPlayer
    if (!player) return
    if (direction < 0 && player.canGoPrevious) player.previous()
    else if (direction > 0 && player.canGoNext) player.next()
  }
  function seekNowPlaying(seconds, target) {
    var player = target || root.nowPlayingPlayer
    if (!player || !player.canSeek || !player.positionSupported) return
    var next = Math.max(0, Number(seconds) || 0)
    if (player.lengthSupported && player.length > 0) next = Math.min(next, player.length)
    player.position = next
  }
  function seekNowPlayingFraction(fraction, target) {
    var player = target || root.nowPlayingPlayer
    if (!player || !player.canSeek || !player.positionSupported
        || !player.lengthSupported || !(player.length > 0)) return
    root.seekNowPlaying(Math.max(0, Math.min(1, fraction)) * player.length, player)
  }
  function seekNowPlayingRelative(seconds, target) {
    var player = target || root.nowPlayingPlayer
    if (!player) return
    root.seekNowPlaying((Number(player.position) || 0) + seconds, player)
  }
  function adjustNowPlayingVolume(delta, target) {
    var player = target || root.nowPlayingPlayer
    if (!player || !player.canControl || !player.volumeSupported) return
    player.volume = Math.max(0, Math.min(1, Number(player.volume) + delta))
  }
  function nowPlayingVolumeIcon(player) {
    var p = player || root.nowPlayingPlayer
    if (!p) return "󰕾"
    var v = Number(p.volume)
    if (v <= 0.001) return "󰝟"
    if (v < 0.34) return "󰕿"
    if (v < 0.67) return "󰖀"
    return "󰕾"
  }
  function toggleNowPlayingMute(target) {
    var player = target || root.nowPlayingPlayer
    if (!player || !player.canControl || !player.volumeSupported) return
    if (Number(player.volume) > 0.001) {
      root._savedVolume = Number(player.volume)
      player.volume = 0
    } else {
      var restored = root._savedVolume > 0.001 ? root._savedVolume : 0.5
      player.volume = Math.max(0, Math.min(1, restored))
    }
  }
  function cycleNowPlayingLoop(target) {
    var player = target || root.nowPlayingPlayer
    if (!player || !player.loopSupported) return
    var current = Number(player.loopState)
    player.loopState = (current + 1) % 3
  }
  function toggleNowPlayingShuffle(target) {
    var player = target || root.nowPlayingPlayer
    if (!player || !player.shuffleSupported) return
    player.shuffle = !player.shuffle
  }
  function cycleNowPlayingRate(target) {
    var player = target || root.nowPlayingPlayer
    if (!player) return
    var rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    var current = Number(player.rate)
    var idx = 0
    for (var i = 0; i < rates.length; i++) {
      if (Math.abs(rates[i] - current) < 0.01) { idx = i; break }
    }
    player.rate = rates[(idx + 1) % rates.length]
  }
  function nowPlayingLoopIcon(player) {
    var p = player || root.nowPlayingPlayer
    if (!p) return "󰑖"
    var s = Number(p.loopState)
    if (s === 1) return "󰑘"
    if (s === 2) return "󰑙"
    return "󰑗"
  }
  function nowPlayingLoopLabel(player) {
    var p = player || root.nowPlayingPlayer
    if (!p) return "Repeat"
    var s = Number(p.loopState)
    if (s === 1) return "Repeat one"
    if (s === 2) return "Repeat all"
    return "Repeat off"
  }
  function openNowPlayingApp(target) {
    var player = target || root.nowPlayingPlayer
    if (!player) return
    if (player.canRaise) { player.raise(); return }
    var entry = String(player.desktopEntry || "")
    if (entry !== "" && root.bar && typeof root.bar.run === "function") {
      root.bar.run("gtk-launch " + entry)
    }
  }
  property real _savedVolume: 0.5

  // ---- Position timer ----
  Timer {
    id: nowPlayingPositionTimer
    interval: 500
    repeat: true
    running: root.opened && root.nowPlayingPlayers.length > 0
    onTriggered: {
      var list = root.nowPlayingPlayers
      for (var i = 0; i < list.length; i++) {
        if (list[i].isPlaying && list[i].positionSupported)
          list[i].positionChanged()
      }
    }
  }

  function open() {
    if (root.hostWidget && root.hostWidget.buttonItem) root.anchorItem = root.hostWidget.buttonItem
    panel.anchorItem = root.anchorItem
    if (root.controller) root.controller.show()
  }
  function close() {
    if (root.controller) root.controller.hide()
  }
  function toggle() {
    if (root.controller) root.controller.toggle()
  }

  // ---- UI ----
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    // (debug removed)
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)
        padding: Style.spacing.panelPadding

      // ---- Header with settings toggle ----
      Row {
        width: parent.width - Style.spacing.panelPadding * 2
        spacing: Style.space(6)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "NOW PLAYING"
          color: Qt.darker(root.contentForeground, 1.6)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1.2
          font.bold: true
        }

        Item {
          width: Math.max(0, parent.width - settingsHeaderLabel.implicitWidth - settingsGearButton.width - settingsCloseButton.width - parent.spacing * 3)
          height: 1
        }

        Text {
          id: settingsHeaderLabel
          anchors.verticalCenter: parent.verticalCenter
          visible: root.nowPlayingPlayers.length > 1
          text: root.nowPlayingPlayers.length + " SOURCES"
          color: Qt.darker(root.contentForeground, 1.9)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        PanelActionButton {
          id: settingsGearButton
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰒓"
          tooltipText: root.settingsOpen ? "Close settings" : "Settings"
          foreground: root.settingsOpen ? Color.accent : root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.toggleSettings()
        }

        PanelActionButton {
          id: settingsCloseButton
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰅙"
          tooltipText: "Close panel"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.close()
        }
      }

      // ---- Settings card ----
      BorderSurface {
        visible: root.settingsOpen
        width: parent.width - Style.spacing.panelPadding * 2
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
        padding: Style.spacing.popupPadding
        height: settingsColumn.implicitHeight + contentTopInset + contentBottomInset

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
        }

        Column {
          id: settingsColumn
          x: parent.contentLeftInset
          y: parent.contentTopInset
          width: parent.width - parent.contentLeftInset - parent.contentRightInset
          spacing: Style.space(8)

          Text {
            text: "DISPLAY"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
            font.bold: true
          }

          Repeater {
            model: [
              { key: "showIcon", label: "Show icon", fallback: true },
              { key: "showTitle", label: "Show title", fallback: true },
              { key: "showArtist", label: "Show artist", fallback: false },
              { key: "highlightPlaying", label: "Highlight when playing", fallback: true },
              { key: "showWhenNoMedia", label: "Show when no media", fallback: true }
            ]

            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - settingsToggle.implicitWidth - parent.spacing
                text: modelData.label
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              Controls.Switch {
                id: settingsToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.setting(modelData.key, modelData.fallback) !== false
                onToggled: root.setSetting(modelData.key, checked)
              }
            }
          }

          Text {
            text: "ICONS (change on your own)"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.2
            font.bold: true
          }

          Repeater {
            model: [
              { key: "idleIcon", label: "Idle", fallback: "󰎄" },
              { key: "playingIcon", label: "Playing", fallback: "󱖒" },
              { key: "pausedIcon", label: "Paused", fallback: "󱖏" }
            ]

            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - settingsIconField.implicitWidth - parent.spacing
                text: modelData.label
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              Controls.TextField {
                id: settingsIconField
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Style.space(60)
                text: String(root.setting(modelData.key, modelData.fallback))
                onEditingFinished: root.setSetting(modelData.key, text.trim() === "" ? modelData.fallback : text)
              }
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Icons: Nerd Font glyphs (nerdfonts.com/cheat-sheet). Paste any glyph into the fields above."
            color: Qt.darker(root.contentForeground, 1.7)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)

            PanelActionButton {
              iconText: "↺"
              tooltipText: "Reset all settings to defaults"
              foreground: Color.urgent
              fontFamily: root.contentFontFamily
              onClicked: root.resetSettings()
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Reset to defaults"
              color: Color.urgent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Text {
        visible: !root.hasNowPlaying
        width: parent.width - Style.spacing.panelPadding * 2
        wrapMode: Text.Wrap
        text: "No media playing"
        color: Qt.darker(root.contentForeground, 1.6)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
      }

      Repeater {
        model: root.nowPlayingPlayers

        BorderSurface {
          id: nowPlayingCard
          required property var modelData
          width: column.width - Style.spacing.panelPadding * 2
          height: nowPlayingCardContent.implicitHeight + contentTopInset + contentBottomInset
          radius: Style.cornerRadius
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g,
            root.contentForeground.b,
            modelData === root.nowPlayingPlayer ? 0.07 : 0.04)
          borderSpec: modelData === root.nowPlayingPlayer
            ? Border.controlSpec("normal", root.contentForeground, Color.accent)
            : Border.none()
          padding: Style.spacing.popupPadding

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
          }

          readonly property var player: modelData
          readonly property bool seekable: !!modelData && modelData.canSeek
            && modelData.positionSupported && modelData.lengthSupported
            && modelData.length > 0
          readonly property bool volumeSupported: !!modelData && modelData.volumeSupported
            && modelData.canControl

          Column {
            id: nowPlayingCardContent
            x: nowPlayingCard.contentLeftInset
            y: nowPlayingCard.contentTopInset
            width: nowPlayingCard.width - nowPlayingCard.contentLeftInset - nowPlayingCard.contentRightInset
            spacing: Style.space(8)

            // Cover + title row
            Row {
              width: parent.width
              spacing: Style.space(10)

              BorderSurface {
                id: nowPlayingCover
                width: Style.space(52)
                height: width
                radius: Style.spacing.labelGap
                color: Style.normalFillFor(root.contentForeground, Color.accent)
                borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)

                SizedImage {
                  anchors.fill: parent
                  anchors.margins: Style.space(2)
                  crop: true
                  url: modelData.trackArtUrl ? modelData.trackArtUrl : ""
                  visible: url != ""
                }
                Text {
                  anchors.centerIn: parent
                  visible: !(modelData.trackArtUrl)
                  text: "󰝚"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.display
                }
                MouseArea {
                  id: nowPlayingCoverMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.NoButton
                  onWheel: function(wheel) {
                    if (!modelData.volumeSupported || !modelData.canControl
                        || wheel.angleDelta.y === 0) return
                    root.adjustNowPlayingVolume(
                      wheel.angleDelta.y > 0 ? 0.05 : -0.05, modelData)
                    wheel.accepted = true
                  }
                }
                PanelToolTip {
                  visible: nowPlayingCoverMouse.containsMouse && modelData.volumeSupported
                  text: "Volume " + Math.round(Number(modelData.volume) * 100) + "% · scroll"
                  fontFamily: root.contentFontFamily
                }
              }

              Column {
                width: parent.width - nowPlayingCover.width - parent.spacing
                spacing: Style.space(2)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  text: modelData.trackTitle || modelData.identity || "Unknown track"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  visible: text !== ""
                  text: root.nowPlayingMeta(modelData)
                  color: Qt.darker(root.contentForeground, 1.45)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }
            }

            // Seek bar
            Row {
              width: parent.width
              spacing: Style.space(6)
              Text {
                id: npElapsed
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatNowPlayingTime(modelData.position)
                color: Qt.darker(root.contentForeground, 1.65)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
              Item {
                id: npSeek
                width: Math.max(0, parent.width - npElapsed.implicitWidth - npDuration.implicitWidth - parent.spacing * 2)
                height: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: Style.spacing.hairline
                  radius: height / 2
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.18)
                }
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width * root.nowPlayingFraction(modelData)
                  height: npSeekMouse.containsMouse && nowPlayingCard.seekable ? Style.space(3) : Style.spacing.hairline
                  radius: height / 2
                  color: nowPlayingCard.seekable ? Color.accent : Qt.darker(root.contentForeground, 1.5)
                  Behavior on height { NumberAnimation { duration: 80 } }
                }
                MouseArea {
                  id: npSeekMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  preventStealing: true
                  enabled: nowPlayingCard.seekable
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onPressed: function(mouse) { root.seekNowPlayingFraction(mouse.x / width, modelData) }
                  onPositionChanged: function(mouse) { if (pressed) root.seekNowPlayingFraction(mouse.x / width, modelData) }
                  onWheel: function(wheel) {
                    if (!nowPlayingCard.seekable || wheel.angleDelta.y === 0) return
                    root.seekNowPlayingRelative(wheel.angleDelta.y > 0 ? 10 : -10, modelData)
                    wheel.accepted = true
                  }
                }
                PanelToolTip {
                  visible: npSeekMouse.containsMouse && nowPlayingCard.seekable
                  text: "Seek · scroll for 10 seconds"
                  fontFamily: root.contentFontFamily
                }
              }
              Text {
                id: npDuration
                anchors.verticalCenter: parent.verticalCenter
                text: root.formatNowPlayingTime(modelData.length)
                color: Qt.darker(root.contentForeground, 1.65)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // Controls
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(2)
              PanelActionButton {
                iconText: "󰒮"
                tooltipText: "Previous track"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: modelData.canGoPrevious
                onClicked: root.stepNowPlaying(-1, modelData)
              }
              PanelActionButton {
                iconText: modelData.isPlaying ? "󰏤" : "󰐊"
                tooltipText: modelData.isPlaying ? "Pause" : "Play"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: modelData.canTogglePlaying || modelData.canPlay || modelData.canPause
                onClicked: root.toggleNowPlaying(modelData)
              }
              PanelActionButton {
                iconText: "󰒭"
                tooltipText: "Next track"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: modelData.canGoNext
                onClicked: root.stepNowPlaying(1, modelData)
              }
              PanelActionButton {
                iconText: root.nowPlayingLoopIcon(modelData)
                tooltipText: root.nowPlayingLoopLabel(modelData)
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: modelData.loopSupported
                onClicked: root.cycleNowPlayingLoop(modelData)
              }
              PanelActionButton {
                iconText: modelData.shuffle ? "󰒟" : "󰒞"
                tooltipText: modelData.shuffle ? "Shuffle on" : "Shuffle off"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: modelData.shuffleSupported
                onClicked: root.toggleNowPlayingShuffle(modelData)
              }
              PanelActionButton {
                iconText: "󰐍"
                tooltipText: "Speed " + Number(modelData.rate).toFixed(2).replace(/\.?0+$/, "") + "×"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.cycleNowPlayingRate(modelData)
              }
              PanelActionButton {
                iconText: root.nowPlayingVolumeIcon(modelData)
                tooltipText: "Mute / unmute"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: nowPlayingCard.volumeSupported
                onClicked: root.toggleNowPlayingMute(modelData)
              }
              PanelActionButton {
                iconText: "󰏌"
                tooltipText: "Open app"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: modelData.canRaise || String(modelData.desktopEntry || "") !== ""
                onClicked: root.openNowPlayingApp(modelData)
              }
              PanelActionButton {
                iconText: "󰅖"
                tooltipText: "Quit app"
                foreground: root.contentForeground
                hoverColor: Color.urgent
                fontFamily: root.contentFontFamily
                enabled: modelData.canQuit
                onClicked: { if (modelData.canQuit) modelData.quit() }
              }
            }

            // Volume bar
            Row {
              width: parent.width
              spacing: Style.space(6)
              visible: nowPlayingCard.volumeSupported
              Text {
                id: volIcon
                anchors.verticalCenter: parent.verticalCenter
                text: root.nowPlayingVolumeIcon(modelData)
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }
              Item {
                id: volBar
                width: Math.max(0, parent.width - volIcon.implicitWidth - volPct.implicitWidth - parent.spacing * 2)
                height: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: Style.spacing.hairline
                  radius: height / 2
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.18)
                }
                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width * Math.max(0, Math.min(1, Number(modelData ? modelData.volume : 0)))
                  height: volMouse.containsMouse ? Style.space(3) : Style.spacing.hairline
                  radius: height / 2
                  color: Color.accent
                  Behavior on height { NumberAnimation { duration: 80 } }
                }
                MouseArea {
                  id: volMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  preventStealing: true
                  cursorShape: Qt.PointingHandCursor
                  onPressed: function(mouse) {
                    if (!modelData.canControl || !modelData.volumeSupported) return
                    modelData.volume = Math.max(0, Math.min(1, mouse.x / width))
                  }
                  onPositionChanged: function(mouse) {
                    if (pressed) modelData.volume = Math.max(0, Math.min(1, mouse.x / width))
                  }
                  onWheel: function(wheel) {
                    if (wheel.angleDelta.y === 0) return
                    root.adjustNowPlayingVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05, modelData)
                    wheel.accepted = true
                  }
                }
                PanelToolTip {
                  visible: volMouse.containsMouse
                  text: "Volume " + Math.round(Number(modelData.volume) * 100) + "%"
                  fontFamily: root.contentFontFamily
                }
              }
              Text {
                id: volPct
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Number(modelData.volume) * 100) + "%"
                color: Qt.darker(root.contentForeground, 1.65)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }

          }
        }
      }
    }
  }
  }
}
