import QtQuick
import "../config"
import "../theme"

// A month calendar, weeks starting on the day the settings choose, with today marked.
// The arrows move between months.
Column {
    id: root

    required property date today
    // The month shown; it starts at today's.
    property int year: root.today.getFullYear()
    property int month: root.today.getMonth()

    // The first day of the week, as Date.getDay() numbers it (0 is Sunday).
    readonly property int weekStart: ({
            "sunday": 0,
            "monday": 1,
            "saturday": 6
        })[Settings.dashboard.weekStart]

    // How far into the week the 1st falls, then 42 cells (six weeks) of dates.
    readonly property var cells: {
        const first = new Date(root.year, root.month, 1);
        const offset = (first.getDay() - root.weekStart + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; ++i)
            out.push(new Date(root.year, root.month, 1 - offset + i));
        return out;
    }

    function step(months) {
        const d = new Date(root.year, root.month + months, 1);
        root.year = d.getFullYear();
        root.month = d.getMonth();
    }

    spacing: Theme.spacingSmall

    Item {
        width: parent.width
        height: 32

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.typeTitleSmall
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingExtraSmall

            Repeater {
                model: [
                    {
                        glyph: 0xF0141, // md-chevron_left
                        months: -1
                    },
                    {
                        glyph: 0xF0142, // md-chevron_right
                        months: 1
                    }
                ]

                Rectangle {
                    id: arrow

                    required property var modelData

                    width: 32
                    height: 32
                    radius: Theme.cornerMedium
                    color: arrowArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(arrow.modelData.glyph)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.typeTitleMedium
                    }

                    MouseArea {
                        id: arrowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.step(arrow.modelData.months)
                    }
                }
            }
        }
    }

    Grid {
        columns: 7
        width: parent.width

        Repeater {
            model: {
                const days = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
                return days.slice(root.weekStart).concat(days.slice(0, root.weekStart));
            }

            Text {
                required property string modelData

                width: root.width / 7
                height: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.typeLabelMedium
            }
        }

        Repeater {
            model: root.cells

            Item {
                id: cell

                required property var modelData
                readonly property bool inMonth: cell.modelData.getMonth() === root.month
                readonly property bool isToday: cell.modelData.toDateString() === root.today.toDateString()

                width: root.width / 7
                height: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: width / 2
                    visible: cell.isToday
                    color: Theme.primary
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.getDate()
                    color: cell.isToday ? Theme.onPrimary : cell.inMonth ? Theme.text : Qt.alpha(Theme.subtext, 0.5)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.typeBodyMedium
                }
            }
        }
    }
}
