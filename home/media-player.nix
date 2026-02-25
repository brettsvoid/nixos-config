{ config, pkgs, ... }:

{
  xdg.configFile = {
    "quickshell/media-player/shell.qml".text = ''
      import QtQuick
      import Quickshell

      ShellRoot {
          Variants {
              model: Quickshell.screens
              MusicWidget {
                  property var modelData
                  screen: modelData
              }
          }
      }
    '';

    "quickshell/media-player/MusicWidget.qml".text = ''
      import QtQuick
      import QtQuick.Layouts
      import Quickshell
      import Quickshell.Wayland
      import Quickshell.Services.Mpris
      import Quickshell.Io
      import QtQuick.Effects

      PanelWindow {
          id: root

          anchors {
              top: true
              left: true
          }
          margins.top: minimized ? 8 : 52
          margins.left: minimized
              ? screen.width / 2 + 146
              : (screen.width - 420) / 2
          implicitWidth: minimized ? 36 : 420
          implicitHeight: minimized ? 36 : 180
          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: minimized ? WlrLayer.Overlay : WlrLayer.Top
          color: "transparent"

          Behavior on margins.top { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
          Behavior on margins.left { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
          Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
          Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

          // ── Minimize state ──
          property bool minimized: false

          // ── Asset path (injected by Nix) ──
          property string configDir: "${config.xdg.configHome}/quickshell/media-player"

          // ── Dynamic theme colors ──
          property var themeColors: ({})

          FileView {
              id: colorsFile
              path: "${config.home.homeDirectory}/.cache/ambxst/colors.json"
              watchChanges: true
              onLoaded: {
                  try {
                      root.themeColors = JSON.parse(colorsFile.text());
                  } catch (e) {
                      root.themeColors = {};
                  }
              }
              onFileChanged: colorsFile.reload()
          }

          function tc(token, fallback) {
              return themeColors[token] || fallback;
          }

          // ── Player selection: prefer playing, fall back to first ──
          readonly property var activePlayer: {
              const players = Mpris.players.values;
              if (!players || players.length === 0) return null;
              const playing = players.find(p => p.playbackState === MprisPlaybackState.Playing);
              if (playing) return playing;
              return players[0];
          }

          readonly property bool hasPlayer: activePlayer !== null
          readonly property bool isPlaying: hasPlayer && activePlayer.playbackState === MprisPlaybackState.Playing

          // ── Slide animation visibility ──
          property bool shouldShow: false
          visible: shouldShow || slideOut.running

          onHasPlayerChanged: {
              if (hasPlayer) shouldShow = true;
          }

          // ── Position tracking ──
          property real trackPosition: hasPlayer ? activePlayer.position : 0
          property real trackLength: hasPlayer ? activePlayer.length : 0

          Timer {
              interval: 1000
              repeat: true
              running: root.isPlaying
              onTriggered: {
                  if (root.activePlayer) {
                      root.trackPosition = root.activePlayer.position;
                      root.trackLength = root.activePlayer.length;
                  }
              }
          }

          Connections {
              target: root.activePlayer
              function onPlaybackStateChanged() {
                  if (root.activePlayer) root.trackPosition = root.activePlayer.position;
              }
              function onTrackChanged() {
                  if (root.activePlayer) {
                      root.trackPosition = root.activePlayer.position;
                      root.trackLength = root.activePlayer.length;
                  }
              }
          }

          function formatTime(seconds) {
              if (isNaN(seconds) || seconds < 0) return "0:00";
              var mins = Math.floor(seconds / 60);
              var secs = Math.floor(seconds % 60);
              return mins + ":" + (secs < 10 ? "0" : "") + secs;
          }

          // ── Card ──
          Item {
              anchors.fill: parent
              clip: true
              visible: !root.minimized

              Rectangle {
                  id: card
                  width: parent.width
                  height: parent.height
                  y: root.hasPlayer ? 0 : -height
                  radius: 16
                  color: root.tc("background", "#1e1e2e")
                  layer.enabled: true
                  layer.effect: MultiEffect {
                      shadowEnabled: true
                      shadowColor: root.tc("shadow", "#000000")
                      shadowBlur: 0.3
                      shadowVerticalOffset: 2
                      shadowOpacity: 0.3
                  }

                  Behavior on y {
                      NumberAnimation {
                          id: slideOut
                          duration: 300
                          easing.type: Easing.OutCubic
                          onRunningChanged: {
                              if (!running && !root.hasPlayer) root.shouldShow = false;
                          }
                      }
                  }

                  // ── Minimize button ──
                  Rectangle {
                      anchors.top: parent.top
                      anchors.right: parent.right
                      anchors.topMargin: 8
                      anchors.rightMargin: 8
                      width: 24
                      height: 24
                      radius: 12
                      color: minimizeHover.hovered
                          ? root.tc("outline", "#a6adc8")
                          : root.tc("surfaceDim", "#585b70")
                      z: 10

                      Text {
                          anchors.centerIn: parent
                          text: "\u2212"
                          font.pixelSize: 16
                          font.bold: true
                          color: root.tc("overBackground", "#cdd6f4")
                      }

                      HoverHandler { id: minimizeHover }

                      TapHandler { onTapped: root.minimized = true }
                  }

                  RowLayout {
                      anchors.fill: parent
                      anchors.margins: 16
                      spacing: 16

                      // ── Left: track info + controls ──
                      ColumnLayout {
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          spacing: 4

                          Text {
                              Layout.fillWidth: true
                              text: root.hasPlayer ? root.activePlayer.trackTitle : ""
                              color: root.tc("overBackground", "#cdd6f4")
                              font.pixelSize: 16
                              font.bold: true
                              elide: Text.ElideRight
                              maximumLineCount: 1
                          }

                          Text {
                              Layout.fillWidth: true
                              text: root.hasPlayer ? root.activePlayer.trackArtist : ""
                              color: root.tc("outline", "#a6adc8")
                              font.pixelSize: 13
                              elide: Text.ElideRight
                              maximumLineCount: 1
                          }

                          Text {
                              Layout.fillWidth: true
                              text: root.hasPlayer ? root.activePlayer.trackAlbum : ""
                              color: root.tc("outline", "#a6adc8")
                              font.pixelSize: 12
                              elide: Text.ElideRight
                              maximumLineCount: 1
                          }

                          Item { Layout.fillHeight: true }

                          // ── Progress bar ──
                          RowLayout {
                              Layout.fillWidth: true
                              spacing: 8

                              Text {
                                  text: root.formatTime(root.trackPosition)
                                  color: root.tc("outline", "#a6adc8")
                                  font.pixelSize: 11
                              }

                              Rectangle {
                                  Layout.fillWidth: true
                                  height: 4
                                  radius: 2
                                  color: root.tc("surfaceContainerHigh", "#313244")

                                  Rectangle {
                                      width: root.trackLength > 0
                                          ? parent.width * Math.min(root.trackPosition / root.trackLength, 1)
                                          : 0
                                      height: parent.height
                                      radius: 2
                                      color: root.tc("primary", "#cba6f7")
                                  }
                              }

                              Text {
                                  text: root.formatTime(root.trackLength)
                                  color: root.tc("outline", "#a6adc8")
                                  font.pixelSize: 11
                              }
                          }

                          // ── Playback controls ──
                          RowLayout {
                              Layout.alignment: Qt.AlignHCenter
                              spacing: 16

                              Rectangle {
                                  width: 36; height: 36; radius: 16
                                  color: root.tc("background", "#1e1e2e")

                                  Rectangle {
                                      anchors.fill: parent
                                      radius: parent.radius
                                      color: root.tc("primary", "#cba6f7")
                                      opacity: prevTap.pressed ? 0.5 : prevHover.hovered ? 0.25 : 0
                                  }

                                  Text {
                                      anchors.centerIn: parent
                                      text: "\u23EE"
                                      font.pixelSize: 20
                                      color: root.hasPlayer && root.activePlayer.canGoPrevious
                                          ? root.tc("overBackground", "#cdd6f4")
                                          : root.tc("outline", "#a6adc8")
                                  }

                                  HoverHandler { id: prevHover }
                                  TapHandler { id: prevTap; onTapped: { if (root.activePlayer) root.activePlayer.previous(); } }
                              }

                              Rectangle {
                                  width: 36; height: 36; radius: 16
                                  color: root.tc("background", "#1e1e2e")

                                  Rectangle {
                                      anchors.fill: parent
                                      radius: parent.radius
                                      color: root.tc("primary", "#cba6f7")
                                      opacity: playTap.pressed ? 0.5 : playHover.hovered ? 0.25 : 0
                                  }

                                  Text {
                                      anchors.centerIn: parent
                                      text: root.isPlaying ? "\u23F8" : "\u25B6"
                                      font.pixelSize: 24
                                      color: root.tc("primary", "#cba6f7")
                                  }

                                  HoverHandler { id: playHover }
                                  TapHandler { id: playTap; onTapped: { if (root.activePlayer) root.activePlayer.togglePlaying(); } }
                              }

                              Rectangle {
                                  width: 36; height: 36; radius: 16
                                  color: root.tc("background", "#1e1e2e")

                                  Rectangle {
                                      anchors.fill: parent
                                      radius: parent.radius
                                      color: root.tc("primary", "#cba6f7")
                                      opacity: nextTap.pressed ? 0.5 : nextHover.hovered ? 0.25 : 0
                                  }

                                  Text {
                                      anchors.centerIn: parent
                                      text: "\u23ED"
                                      font.pixelSize: 20
                                      color: root.hasPlayer && root.activePlayer.canGoNext
                                          ? root.tc("overBackground", "#cdd6f4")
                                          : root.tc("outline", "#a6adc8")
                                  }

                                  HoverHandler { id: nextHover }
                                  TapHandler { id: nextTap; onTapped: { if (root.activePlayer) root.activePlayer.next(); } }
                              }
                          }
                      }

                      // ── Right: animated GIF ──
                      AnimatedImage {
                          id: gifImage
                          Layout.preferredWidth: 120
                          Layout.fillHeight: true
                          visible: status === AnimatedImage.Ready
                          source: root.configDir + "/assets/music.gif"
                          fillMode: Image.PreserveAspectFit
                          playing: root.isPlaying
                      }
                  }
              }
          }

          // ── Minimized indicator (after card for z-order) ──
          Rectangle {
              id: minimizedCircle
              anchors.fill: parent
              radius: 16
              color: root.tc("background", "#1e1e2e")
              visible: root.minimized

              Rectangle {
                  anchors.fill: parent
                  radius: parent.radius
                  color: root.tc("primary", "#cba6f7")
                  opacity: minimizedTap.pressed ? 0.5 : minimizedHover.hovered ? 0.25 : 0
              }

              AnimatedImage {
                  anchors.centerIn: parent
                  width: 32
                  height: 32
                  source: root.configDir + "/assets/music.gif"
                  fillMode: Image.PreserveAspectFit
                  playing: root.isPlaying
              }

              HoverHandler { id: minimizedHover }
              TapHandler { id: minimizedTap; onTapped: root.minimized = false }
          }
      }
    '';
  };

  home.packages = [
    (pkgs.writeShellScriptBin "media-player-widget" ''
      pkill -f "quickshell/media-player" 2>/dev/null || true
      sleep 0.3
      export QSG_RHI_BACKEND=vulkan
      exec qs -n -p "$HOME/.config/quickshell/media-player"
    '')
  ];
}
