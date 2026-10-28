import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell.Io
import Quickshell.Widgets

// Penumbra's three wallpapers, then the images, GIFs and videos in ~/Pictures/Wallpapers; click
// one, or pick it with the arrow keys and Enter, to switch with penumbra-wallpaper's transition.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge - shadowRoom
    sheetWidth: 620
    open: Ui.wallpapersOpen
    onDismissed: Ui.dismiss()

    readonly property int cell: (sheetWidth - 36 - 20) / 3
    readonly property var scenes: [
        { name: "wallpaper", badge: "" },
        { name: "wallpaper-dawn", badge: "Animated" },
        { name: "wallpaper-eclipse", badge: "Animated" }
    ]

    // Look again each time it opens: the folder may have been created or filled since, and new
    // videos need their first frame for a thumbnail.
    onOpenChanged: {
        if (!open)
            return;
        yours.folder = "";
        yours.folder = Ui.fileUrl(Ui.wallpaperFolder);
        posters.running = true;
        selectCurrent();
    }

    // The highlighted choice: Penumbra's three, then yours, read as one three-column grid.
    property int selected: 0
    readonly property int total: scenes.length + yours.count
    function selectCurrent() {
        const scene = scenes.findIndex(s => s.name === Ui.wallpaper);
        let mine = yours.count - 1;
        while (mine >= 0 && yours.get(mine, "filePath") !== Ui.wallpaper)
            mine--;
        select(scene >= 0 ? scene : mine >= 0 ? scenes.length + mine : 0);
    }
    // The folder lists its files after the panel opens; find the current one among them.
    Connections {
        target: yours
        function onStatusChanged() {
            if (yours.status === FolderListModel.Ready && root.open)
                root.selectCurrent();
        }
    }
    function select(index) {
        selected = Math.max(0, Math.min(total - 1, index));
        const item = selected >= scenes.length ? mine.itemAt(selected - scenes.length) : null;
        if (!item)
            return;
        // Scroll your wallpapers just enough to show it.
        if (item.y < flick.contentY)
            flick.contentY = item.y;
        else if (item.y + item.height > flick.contentY + flick.height)
            flick.contentY = item.y + item.height - flick.height;
    }
    function choose(index) {
        const name = index < scenes.length ? scenes[index].name : yours.get(index - scenes.length, "filePath");
        if (name && name !== Ui.wallpaper)
            Ui.spawn([Ui.bin + "penumbra-wallpaper", name]);
    }
    keyTargets: [keys]
    Item {
        id: keys
        Keys.onLeftPressed: root.select(root.selected - 1)
        Keys.onRightPressed: root.select(root.selected + 1)
        Keys.onUpPressed: root.select(root.selected - 3)
        // From the last full row, down still reaches the shorter one below.
        Keys.onDownPressed: root.select(root.selected + 3 < root.total ? root.selected + 3 : Math.floor(root.selected / 3) < Math.floor((root.total - 1) / 3) ? root.total - 1 : root.selected)
        Keys.onTabPressed: root.select((root.selected + 1) % root.total)
        Keys.onBacktabPressed: root.select((root.selected + root.total - 1) % root.total)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home)
                root.select(0);
            else if (event.key === Qt.Key_End)
                root.select(root.total - 1);
            else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
                root.choose(root.selected);
            else
                return;
            event.accepted = true;
        }
    }
    FolderListModel {
        id: yours
        showDirs: false
        caseSensitive: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v"]
    }
    Process {
        id: posters
        command: [Ui.bin + "penumbra-wallpaper", "posters"]
        onExited: root.postersMade()
    }
    signal postersMade()

    component Choice: Column {
        id: choice
        required property string name
        property string badge: ""
        property url thumbnail
        // Its place among all the choices.
        required property int position
        readonly property bool current: Ui.wallpaper === name
        readonly property bool highlighted: root.selected === position
        width: root.cell
        spacing: 6

        ClippingRectangle {
            width: parent.width
            height: width * 9 / 16
            radius: Theme.radiusSmall
            color: Theme.raised
            border.width: choice.current ? 2 : 1
            border.color: choice.current ? Theme.accent : choice.highlighted ? Theme.lineStrong : Theme.line
            contentUnderBorder: true
            Image {
                id: thumb
                anchors.fill: parent
                source: choice.thumbnail
                sourceSize.width: 360
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                scale: choice.highlighted ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            }
            // A video's first frame may only just have been made.
            Connections {
                target: root
                function onPostersMade() {
                    if (thumb.status !== Image.Error)
                        return;
                    thumb.source = "";
                    thumb.source = choice.thumbnail;
                }
            }
            Glyph {
                visible: thumb.status !== Image.Ready
                anchors.centerIn: parent
                text: "󰸉"
                size: 22
                color: Theme.dim
            }
            Rectangle {
                visible: choice.badge !== ""
                anchors { left: parent.left; top: parent.top; margins: 8 }
                implicitWidth: badge.implicitWidth + 14
                implicitHeight: 20
                radius: Theme.corner(10)
                color: Theme.glassStrong
                Label {
                    id: badge
                    anchors.centerIn: parent
                    text: choice.badge
                    font.pixelSize: Theme.textTiny
                    font.weight: Font.DemiBold
                    color: Theme.accentBright
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // The mouse and the arrow keys move the same highlight.
                onEntered: root.selected = choice.position
                onClicked: root.choose(choice.position)
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Rectangle {
                visible: choice.current
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: Theme.corner(3)
                color: Theme.accent
            }
            Label {
                width: Math.min(implicitWidth, root.cell - 12)
                text: Ui.wallpaperTitle(choice.name)
                font.weight: choice.current ? Font.DemiBold : Font.Normal
                color: choice.current || choice.highlighted ? Theme.text : Theme.muted
            }
        }
    }

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: "Wallpaper"
                font.pixelSize: Theme.textLarge
                font.weight: Font.DemiBold
            }
            PillButton {
                text: "Open folder"
                onClicked: {
                    Ui.spawn(["bash", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "_", Ui.wallpaperFolder]);
                    Ui.dismiss();
                }
            }
        }

        Overline { text: "Penumbra" }
        Row {
            spacing: 10
            Repeater {
                model: root.scenes
                delegate: Choice {
                    required property var modelData
                    required property int index
                    position: index
                    name: modelData.name
                    badge: modelData.badge
                    thumbnail: Ui.fileUrl(Ui.wallpapers + modelData.name + ".png")
                }
            }
        }

        Overline { text: "Yours" }
        Label {
            visible: yours.count === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "Put images, GIFs and videos in ~/Pictures/Wallpapers, or right-click one in Dolphin and choose Set as Wallpaper."
            color: Theme.muted
        }
        Flickable {
            id: flick
            visible: yours.count > 0
            Layout.fillWidth: true
            // Two rows and a peek at the third.
            Layout.preferredHeight: Math.min(contentHeight, root.cell * 1.45 + 60)
            contentHeight: grid.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Grid {
                id: grid
                columns: 3
                spacing: 10
                Repeater {
                    id: mine
                    model: yours
                    delegate: Choice {
                        required property string filePath
                        required property int index
                        position: root.scenes.length + index
                        readonly property string kind: Ui.wallpaperKind(filePath)
                        name: filePath
                        badge: kind === "gif" ? "GIF" : kind === "video" ? "Video" : ""
                        thumbnail: Ui.fileUrl(kind === "video" ? Ui.wallpaperPoster(filePath) : filePath)
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: "Arrow keys and Enter pick one · Super+W cycles through them · the lock screen follows"
            font.pixelSize: Theme.textSmall
            color: Theme.dim
        }
    }
}
