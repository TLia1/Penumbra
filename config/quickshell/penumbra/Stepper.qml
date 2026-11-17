import QtQuick
import QtQuick.Layouts

// A value between two arrows that step it, repeating while held: night light's times, idle
// timings, screen modes.
RowLayout {
    id: root

    property string text
    property string accessibleLabel: ""
    readonly property Item focusControl: canDecrease ? less : more
    property string lessGlyph: "󰅁"
    property string moreGlyph: "󰅂"
    property bool canDecrease: true
    property bool canIncrease: true
    property int textWidth: 72
    signal decreased()
    signal increased()

    spacing: 2

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        property bool available: true
        signal step()
        activeFocusOnTab: available
        Accessible.role: Accessible.Button
        Accessible.name: (glyph === root.lessGlyph ? "Decrease " : "Increase ") + root.accessibleLabel + " " + root.text
        Accessible.onPressAction: if (available) step()
        Keys.onSpacePressed: if (available) step()
        Keys.onReturnPressed: if (available) step()
        Keys.onEnterPressed: if (available) step()
        border.color: activeFocus ? Theme.accentBright : "transparent"
        implicitWidth: 28
        implicitHeight: 28
        radius: Theme.corner(14)
        color: area.containsMouse && available ? Theme.hover : "transparent"
        opacity: available ? 1 : 0.35
        Glyph { anchors.centerIn: parent; text: arrow.glyph; size: 13; color: Theme.textSoft }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: arrow.available
            cursorShape: Qt.PointingHandCursor
            onPressed: { arrow.step(); held.interval = 420; held.start(); }
            onReleased: held.stop()
            onCanceled: held.stop()
        }
        Timer {
            id: held
            repeat: true
            onTriggered: {
                interval = 70;
                if (arrow.available)
                    arrow.step();
            }
        }
    }

    Arrow { id: less; glyph: root.lessGlyph; available: root.canDecrease; onStep: root.decreased() }
    Label {
        Layout.preferredWidth: root.textWidth
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        font.weight: Font.DemiBold
    }
    Arrow { id: more; glyph: root.moreGlyph; available: root.canIncrease; onStep: root.increased() }
}
