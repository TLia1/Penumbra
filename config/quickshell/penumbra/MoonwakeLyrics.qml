import QtQuick

Item {
    id: root
    required property string text
    required property string family
    required property color ink
    required property int pixelSize
    implicitHeight: reflection.y + reflection.height

    component Verse: Text {
        width: root.width
        text: root.text
        textFormat: Text.PlainText
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.italic: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        color: root.ink
    }

    Verse {
        id: line
        style: Text.Raised
        styleColor: "#80372640"
    }

    Item {
        id: reflection
        y: line.height + 1
        width: root.width
        height: Math.round(line.height * 0.57)

        // Each ripple catches a sliver of the vertically mirrored lettering.
        Repeater {
            model: 7
            delegate: Item {
                id: ripple
                required property int index
                readonly property real depth: index / 7
                y: Math.round(reflection.height * depth)
                x: Math.sin(index * 2.3) * (0.5 + depth * 2)
                width: reflection.width
                height: Math.max(0, Math.round(reflection.height * (index + 1) / 7) - y - (index % 2))
                opacity: 0.42 * (1 - depth)
                clip: true
                Verse {
                    y: reflection.height - ripple.y
                    transform: Scale { yScale: -reflection.height / Math.max(1, line.height) }
                }
            }
        }
    }
}
