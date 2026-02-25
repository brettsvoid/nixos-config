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

      PanelWindow {
          id: root

          anchors {
              top: true
          }
          margins.top: 52
          implicitWidth: 420
          implicitHeight: 180
          exclusionMode: ExclusionMode.Ignore
          color: "transparent"

          // ── Asset path (injected by Nix) ──
          property string configDir: "${config.xdg.configHome}/quickshell/media-player"

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

              Rectangle {
                  id: card
                  width: parent.width
                  height: parent.height
                  y: root.hasPlayer ? 0 : -height
                  radius: 16
                  color: "#1e1e2e"
                  border.color: "#313244"
                  border.width: 1

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
                              color: "#cdd6f4"
                              font.pixelSize: 16
                              font.bold: true
                              elide: Text.ElideRight
                              maximumLineCount: 1
                          }

                          Text {
                              Layout.fillWidth: true
                              text: root.hasPlayer ? root.activePlayer.trackArtist : ""
                              color: "#bac2de"
                              font.pixelSize: 13
                              elide: Text.ElideRight
                              maximumLineCount: 1
                          }

                          Text {
                              Layout.fillWidth: true
                              text: root.hasPlayer ? root.activePlayer.trackAlbum : ""
                              color: "#a6adc8"
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
                                  color: "#a6adc8"
                                  font.pixelSize: 11
                              }

                              Rectangle {
                                  Layout.fillWidth: true
                                  height: 4
                                  radius: 2
                                  color: "#313244"

                                  Rectangle {
                                      width: root.trackLength > 0
                                          ? parent.width * Math.min(root.trackPosition / root.trackLength, 1)
                                          : 0
                                      height: parent.height
                                      radius: 2
                                      color: "#cba6f7"
                                  }
                              }

                              Text {
                                  text: root.formatTime(root.trackLength)
                                  color: "#a6adc8"
                                  font.pixelSize: 11
                              }
                          }

                          // ── Playback controls ──
                          RowLayout {
                              Layout.alignment: Qt.AlignHCenter
                              spacing: 24

                              Text {
                                  text: "\u23EE"
                                  font.pixelSize: 20
                                  color: root.hasPlayer && root.activePlayer.canGoPrevious ? "#cdd6f4" : "#585b70"
                                  MouseArea {
                                      anchors.fill: parent
                                      cursorShape: Qt.PointingHandCursor
                                      onClicked: { if (root.activePlayer) root.activePlayer.previous(); }
                                  }
                              }

                              Text {
                                  text: root.isPlaying ? "\u23F8" : "\u25B6"
                                  font.pixelSize: 24
                                  color: "#cba6f7"
                                  MouseArea {
                                      anchors.fill: parent
                                      cursorShape: Qt.PointingHandCursor
                                      onClicked: { if (root.activePlayer) root.activePlayer.togglePlaying(); }
                                  }
                              }

                              Text {
                                  text: "\u23ED"
                                  font.pixelSize: 20
                                  color: root.hasPlayer && root.activePlayer.canGoNext ? "#cdd6f4" : "#585b70"
                                  MouseArea {
                                      anchors.fill: parent
                                      cursorShape: Qt.PointingHandCursor
                                      onClicked: { if (root.activePlayer) root.activePlayer.next(); }
                                  }
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
