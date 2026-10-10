import QtQuick
import Quickshell.Services.Pipewire
import "../components"
import "../theme"

// Outputs, inputs and the apps playing or recording, from PipeWire. Clicking a device
// makes it the default, which WirePlumber moves the streams that follow the default
// to; each device and app has its own volume and mute. The bar's audio icon and the
// OSD read the same nodes.
FocusScope {
    id: root

    // By name: PipeWire's own order changes from one start to the next.
    readonly property var nodes: Pipewire.nodes.values.filter(node => node.audio !== null).sort((a, b) => root.label(a).localeCompare(root.label(b)))
    readonly property var outputs: root.nodes.filter(node => !node.isStream && node.isSink)
    readonly property var inputs: root.nodes.filter(node => !node.isStream && !node.isSink)
    readonly property var streams: root.nodes.filter(node => node.isStream)

    function label(node) {
        return node.properties["application.name"] || node.description || node.nickname || node.name;
    }

    // A node's volume and mute are only kept up to date while something tracks it.
    PwObjectTracker {
        objects: root.nodes
    }

    component Heading: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeTitleSmall
        font.bold: true
        topPadding: Theme.spacingLarge
        bottomPadding: Theme.spacingSmall
    }

    component Empty: Text {
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeBodyMedium
        bottomPadding: Theme.spacingSmall
    }

    // A round button showing whether the node is muted, which toggles it.
    component MuteButton: Rectangle {
        id: mute

        required property PwNode node
        property int glyph
        property int mutedGlyph

        readonly property bool muted: mute.node.audio?.muted ?? false

        width: 36
        height: width
        radius: width / 2
        color: muteArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(mute.muted ? mute.mutedGlyph : mute.glyph)
            color: mute.muted ? Theme.error : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleMedium
        }

        MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (mute.node.audio)
                    mute.node.audio.muted = !mute.muted;
            }
        }
    }

    // A volume slider and its level, for one node.
    component Volume: Item {
        id: volume

        required property PwNode node

        implicitHeight: 24

        Slider {
            anchors.left: parent.left
            anchors.right: level.left
            anchors.rightMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            from: 0
            to: 1
            stepSize: 0.01
            value: volume.node.audio?.volume ?? 0
            onMoved: value => {
                if (volume.node.audio)
                    volume.node.audio.volume = value;
            }
        }

        Text {
            id: level
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            horizontalAlignment: Text.AlignRight
            text: Math.round((volume.node.audio?.volume ?? 0) * 100) + "%"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeBodyMedium
        }
    }

    // An output or input: its name (a click makes it the default), mute and volume.
    component Device: Item {
        id: device

        required property PwNode modelData
        property bool isDefault
        property int glyph
        property int mutedGlyph

        signal chosen

        width: parent?.width ?? 0
        implicitHeight: 52

        Rectangle {
            id: pick
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.45
            height: 40
            radius: height / 2
            color: device.isDefault ? Theme.primary : pickArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

            Text {
                id: tick
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(device.isDefault ? 0xF012C : 0xF0130) // md-check, md-checkbox_blank_circle_outline
                color: device.isDefault ? Theme.onPrimary : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeTitleSmall
            }

            Text {
                id: name
                anchors.left: tick.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingSmall
                anchors.rightMargin: Theme.spacingLarge
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: root.label(device.modelData)
                color: device.isDefault ? Theme.onPrimary : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeBodyMedium
            }

            MouseArea {
                id: pickArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: device.chosen()
            }
        }

        MuteButton {
            id: muteButton
            anchors.left: pick.right
            anchors.leftMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            node: device.modelData
            glyph: device.glyph
            mutedGlyph: device.mutedGlyph
        }

        Volume {
            anchors.left: muteButton.right
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            node: device.modelData
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width

            Heading {
                text: "Output"
                topPadding: 0
            }

            Repeater {
                model: root.outputs

                Device {
                    isDefault: modelData === Pipewire.defaultAudioSink
                    glyph: 0xF057E // md-volume_high
                    mutedGlyph: 0xF0581 // md-volume_off
                    onChosen: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            Empty {
                visible: root.outputs.length === 0
                text: "No outputs"
            }

            Heading {
                text: "Input"
            }

            Repeater {
                model: root.inputs

                Device {
                    isDefault: modelData === Pipewire.defaultAudioSource
                    glyph: 0xF036C // md-microphone
                    mutedGlyph: 0xF036D // md-microphone_off
                    onChosen: Pipewire.preferredDefaultAudioSource = modelData
                }
            }

            Empty {
                visible: root.inputs.length === 0
                text: "No inputs"
            }

            Heading {
                text: "Apps"
            }

            Repeater {
                model: root.streams

                Item {
                    id: stream

                    required property PwNode modelData
                    readonly property var props: stream.modelData.properties
                    // Playing (to an output), or recording (from an input).
                    readonly property bool playing: stream.props["media.class"] === "Stream/Output/Audio"

                    width: parent?.width ?? 0
                    implicitHeight: 52

                    Column {
                        id: label
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.45

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: root.label(stream.modelData)
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeBodyMedium
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: text !== ""
                            text: stream.props["media.name"] ?? ""
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.typeBodySmall
                        }
                    }

                    MuteButton {
                        id: streamMute
                        anchors.left: label.right
                        anchors.leftMargin: Theme.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        node: stream.modelData
                        glyph: stream.playing ? 0xF057E : 0xF036C // md-volume_high, md-microphone
                        mutedGlyph: stream.playing ? 0xF0581 : 0xF036D // md-volume_off, md-microphone_off
                    }

                    Volume {
                        anchors.left: streamMute.right
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        node: stream.modelData
                    }
                }
            }

            Empty {
                visible: root.streams.length === 0
                text: "No app is playing or recording"
            }
        }
    }
}
