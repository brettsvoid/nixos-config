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

      Item {
          id: root

          property var screen

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

          onHasPlayerChanged: {
              if (hasPlayer) cardWindow.shouldShow = true;
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

          // ══════════════════════════════════════
          // ── Card Window ──
          // ══════════════════════════════════════
          PanelWindow {
              id: cardWindow
              screen: root.screen

              anchors {
                  top: true
                  left: true
              }
              margins.top: 48 - 16
              margins.left: (screen.width - 420) / 2 - 16
              implicitWidth: 420 + 32
              implicitHeight: 180 + 32
              exclusionMode: ExclusionMode.Ignore
              WlrLayershell.layer: WlrLayer.Top
              color: "transparent"

              property bool shouldShow: false
              visible: shouldShow || slideOut.running

              Item {
                  id: cardContainer
                  anchors.fill: parent
                  opacity: 1
                  scale: 1
                  visible: opacity > 0
                  transformOrigin: Item.Top

                  Connections {
                      target: root
                      function onMinimizedChanged() {
                          if (root.minimized) {
                              cardShowAnim.stop();
                              cardHideAnim.start();
                          } else {
                              cardHideAnim.stop();
                              cardShowAnim.start();
                          }
                      }
                  }

                  SequentialAnimation {
                      id: cardHideAnim
                      ParallelAnimation {
                          NumberAnimation { target: cardContainer; property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuart }
                          NumberAnimation { target: cardContainer; property: "scale"; to: 0.85; duration: 300; easing.type: Easing.OutCubic }
                      }
                      ScriptAction { script: cardWindow.visible = false }
                  }

                  SequentialAnimation {
                      id: cardShowAnim
                      ScriptAction { script: cardWindow.visible = true }
                      PauseAnimation { duration: 100 }
                      ParallelAnimation {
                          NumberAnimation { target: cardContainer; property: "opacity"; to: 1; duration: 250; easing.type: Easing.OutQuart }
                          NumberAnimation { target: cardContainer; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                      }
                  }

                  // Background with rounded shadow (no children to overflow)
                  Rectangle {
                      id: cardBg
                      anchors.fill: parent
                      anchors.margins: 16
                      y: root.hasPlayer ? 0 : -parent.height
                      radius: 16
                      color: root.tc("background", "#1e1e2e")
                      layer.enabled: true
                      layer.effect: MultiEffect {
                          shadowEnabled: true
                          shadowColor: root.tc("shadow", "#000000")
                          shadowBlur: 1
                          shadowVerticalOffset: 0
                          shadowOpacity: 0.5
                      }

                      Behavior on y {
                          NumberAnimation {
                              id: slideOut
                              duration: 300
                              easing.type: Easing.OutCubic
                              onRunningChanged: {
                                  if (!running && !root.hasPlayer) cardWindow.shouldShow = false;
                              }
                          }
                      }
                  }

                  // Content clipped to rounded shape
                  Item {
                      id: card
                      anchors.fill: parent
                      anchors.margins: 16
                      y: cardBg.y
                      layer.enabled: true
                      layer.effect: MultiEffect {
                          maskEnabled: true
                          maskSource: cardMask
                          maskThresholdMin: 0.5
                          maskSpreadAtMin: 1.0
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

                  // Invisible mask shape for card clipping
                  Item {
                      id: cardMask
                      anchors.fill: card
                      visible: false
                      layer.enabled: true
                      Rectangle {
                          anchors.fill: parent
                          radius: 16
                          color: "white"
                      }
                  }
              }
          }

          // ══════════════════════════════════════
          // ── Minimized Button Window ──
          // ══════════════════════════════════════
          PanelWindow {
              id: buttonWindow
              screen: root.screen

              anchors {
                  top: true
                  left: true
              }
              margins.top: 8 - 16
              margins.left: screen.width / 2 + 146 - 16
              implicitWidth: 36 + 32
              implicitHeight: 36 + 32
              exclusionMode: ExclusionMode.Ignore
              WlrLayershell.layer: WlrLayer.Overlay
              color: "transparent"
              visible: root.hasPlayer

              Item {
                  id: minimizedCircle
                  anchors.fill: parent
                  anchors.margins: 16
                  opacity: 0
                  scale: 0.5
                  visible: opacity > 0

                  Connections {
                      target: root
                      function onMinimizedChanged() {
                          if (root.minimized) {
                              buttonShowAnim.start();
                          } else {
                              buttonShowAnim.stop();
                              buttonHideAnim.start();
                          }
                      }
                  }

                  SequentialAnimation {
                      id: buttonShowAnim
                      PauseAnimation { duration: 100 }
                      ParallelAnimation {
                          NumberAnimation { target: minimizedCircle; property: "opacity"; to: 1; duration: 250; easing.type: Easing.OutQuart }
                          NumberAnimation { target: minimizedCircle; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                      }
                  }

                  SequentialAnimation {
                      id: buttonHideAnim
                      ParallelAnimation {
                          NumberAnimation { target: minimizedCircle; property: "opacity"; to: 0; duration: 250; easing.type: Easing.OutQuart }
                          NumberAnimation { target: minimizedCircle; property: "scale"; to: 0.5; duration: 300; easing.type: Easing.OutCubic }
                      }
                  }

                  // Background with rounded shadow (no overflowing children)
                  Rectangle {
                      anchors.fill: parent
                      radius: 16
                      color: root.tc("background", "#1e1e2e")
                      layer.enabled: true
                      layer.effect: MultiEffect {
                          shadowEnabled: true
                          shadowColor: root.tc("shadow", "#000000")
                          shadowBlur: 1
                          shadowVerticalOffset: 0
                          shadowOpacity: 0.7
                      }
                  }

                  // Content clipped to rounded shape
                  Item {
                      anchors.fill: parent
                      layer.enabled: true
                      layer.effect: MultiEffect {
                          maskEnabled: true
                          maskSource: buttonMask
                          maskThresholdMin: 0.5
                          maskSpreadAtMin: 1.0
                      }

                      Rectangle {
                          anchors.fill: parent
                          radius: 16
                          color: root.tc("primary", "#cba6f7")
                          opacity: minimizedTap.pressed ? 0.5 : minimizedHover.hovered ? 0.25 : 0
                      }

                      AnimatedImage {
                          anchors.horizontalCenter: parent.horizontalCenter
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.verticalCenterOffset: 4
                          width: 40
                          height: 40
                          source: root.configDir + "/assets/music.gif"
                          fillMode: Image.PreserveAspectFit
                          playing: root.isPlaying
                      }
                  }

                  // Invisible mask shape
                  Item {
                      id: buttonMask
                      anchors.fill: parent
                      visible: false
                      layer.enabled: true
                      Rectangle {
                          anchors.fill: parent
                          radius: 16
                          color: "white"
                      }
                  }

                  HoverHandler { id: minimizedHover }
                  TapHandler { id: minimizedTap; onTapped: root.minimized = false }
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
