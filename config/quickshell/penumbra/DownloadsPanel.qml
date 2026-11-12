import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "downloads.js" as Downloads

// Download a video, or only its sound, with yt-dlp: paste an address, choose video or audio, its
// format and quality and the folder it goes in. bin/penumbra-download does the downloading, so a
// download carries on when the panel closes or the shell restarts, and keeps the list of downloads
// in $XDG_RUNTIME_DIR/penumbra/downloads, shown below the form. shell.qml loads this panel only
// while it is open: closed, nothing of it runs. Super+D, the launcher (paste an address) or
// `panel downloads` / `panel download URL` open it.
Panel {
    id: root
    originKey: "downloads"
    anchors { top: true; right: true }
    margins.right: edgeMargin - shadowRoom
    preferredSheetWidth: 440
    // Opened a moment after it is made, so it springs open like the panels that always exist.
    property bool ready: false
    open: Ui.downloadsOpen && ready
    grabFocus: !choosingFolder
    onDismissed: if (!choosingFolder) Ui.dismiss()
    Timer { interval: 1; running: true; onTriggered: root.ready = true }
    onOpenChanged: if (open) Qt.callLater(() => urlField.forceActiveFocus())

    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: Ui.bin + "penumbra-download"

    // What penumbra-download probe found: { ytdlp (version or null), ffmpeg, videos, music }.
    property var tools: null
    readonly property bool missing: tools !== null && !tools.ytdlp
    // The looked-up address: { kind (video or playlist), title, channel, duration, thumbnail,
    // heights, audioOnly, entries }, or { error }.
    property var info: null
    readonly property bool looking: lookup.running || lookupDelay.running
    property bool wholePlaylist: false
    property var jobs: [] // newest first
    readonly property bool choosingFolder: chooser.running

    readonly property string url: Downloads.address(urlField.text, true)
    readonly property var choice: Settings.downloads ?? {}
    readonly property bool audio: choice.kind === "audio" || !!info?.audioOnly
    readonly property string format: Downloads.format(audio, audio ? choice.audioFormat : choice.videoFormat)
    readonly property var qualities: Downloads.qualities(audio, format, info?.heights)
    readonly property string quality: Downloads.quality(qualities, audio ? choice.audioQuality : choice.videoQuality)
    readonly property string folder: (audio ? choice.audioFolder : choice.videoFolder) || (audio ? tools?.music : tools?.videos) || ""
    readonly property bool playlist: info?.kind === "playlist" || wholePlaylist && Downloads.inPlaylist(url)
    readonly property bool canDownload: url !== "" && folder !== "" && !!tools?.ytdlp && !info?.error

    function remember(key, value) {
        Settings.downloads = Object.assign({}, choice, { [key]: value });
    }
    function download() {
        if (!canDownload)
            return;
        Ui.spawn(Downloads.command(helper, {
            url, audio, format, quality, folder, playlist,
            // A playlist's own title, not that of the video its address points at.
            title: !playlist || info?.kind === "playlist" ? info?.title ?? "" : ""
        }));
        urlField.text = "";
        urlField.forceActiveFocus();
    }
    function lookUp() {
        if (!url || !tools?.ytdlp)
            return;
        lookup.command = [helper, "info", url];
        lookup.running = true;
    }
    // An address from the launcher or IPC, else one on the clipboard.
    function takeAddress() {
        if (Ui.downloadUrl) {
            urlField.text = Ui.downloadUrl;
            Ui.downloadUrl = "";
        } else if (!urlField.text) {
            paste.running = true;
        }
    }

    onUrlChanged: {
        info = null;
        wholePlaylist = false;
        lookup.running = false;
        if (url && tools?.ytdlp)
            lookupDelay.restart();
        else
            lookupDelay.stop();
    }
    onToolsChanged: if (url && !info) lookupDelay.restart()
    Component.onCompleted: takeAddress()
    Connections {
        target: Ui
        function onDownloadUrlChanged() { if (Ui.downloadUrl) root.takeAddress(); }
    }

    // ── Helpers, each running only for a moment ─────────────────────
    Process {
        running: true
        command: [root.helper, "probe"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.tools = JSON.parse(text);
                } catch (e) {
                    root.tools = { ytdlp: null, ffmpeg: false };
                }
                state.reload(); // the probe makes the file the first time
            }
        }
    }
    Timer {
        id: lookupDelay
        interval: 450
        onTriggered: root.lookUp()
    }
    Process {
        id: lookup
        stdout: StdioCollector {
            onStreamFinished: {
                let answer;
                try {
                    answer = JSON.parse(text);
                } catch (e) {
                    return; // stopped for an address since changed
                }
                if (answer.url === root.url)
                    root.info = answer;
            }
        }
    }
    Process {
        id: paste
        command: ["wl-paste", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            onStreamFinished: {
                const address = Downloads.address(text, false);
                if (address && !urlField.text)
                    urlField.text = address;
            }
        }
    }
    Process {
        id: chooser
        command: [root.helper, "folder", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path)
                    root.remember(root.audio ? "audioFolder" : "videoFolder", path);
            }
        }
        onExited: urlField.forceActiveFocus()
    }
    FileView {
        id: state
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/penumbra/downloads"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text());
                if (Array.isArray(list))
                    root.jobs = list.slice().reverse();
            } catch (e) {
                // Caught mid-write; the next change brings the rest.
            }
        }
    }

    component IconButton: Rectangle {
        id: button
        property string glyph
        property color tint: Theme.textSoft
        signal clicked()
        implicitWidth: 30
        implicitHeight: 30
        radius: Theme.corner(15)
        color: buttonArea.containsMouse ? Theme.hover : "transparent"
        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
        Glyph {
            anchors.centerIn: parent
            text: button.glyph
            size: 14
            color: buttonArea.containsMouse ? Theme.text : button.tint
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                implicitWidth: 42
                implicitHeight: 42
                radius: Theme.corner(21)
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.accentDeep }
                }
                Glyph { anchors.centerIn: parent; text: "󰇚"; size: 19; color: Theme.accentInk }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: "Download"
                    font.pixelSize: Theme.textLarge
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    text: root.tools?.ytdlp ? "Video or audio · yt-dlp " + root.tools.ytdlp : "Video or audio, with yt-dlp"
                    font.pixelSize: Theme.textSmall
                    color: Theme.muted
                }
            }
        }

        // yt-dlp, or ffmpeg, missing.
        Rectangle {
            Layout.fillWidth: true
            visible: root.missing || root.tools !== null && !root.tools.ffmpeg
            implicitHeight: missingRow.implicitHeight + 20
            radius: Theme.radiusSmall
            color: Theme.alpha(Theme.amber, 0.12)
            border.color: Theme.alpha(Theme.amber, 0.4)
            RowLayout {
                id: missingRow
                anchors { fill: parent; margins: 10 }
                spacing: 10
                Glyph { text: "󰀦"; size: 17; color: Theme.amber }
                Label {
                    Layout.fillWidth: true
                    text: root.missing ? "yt-dlp is not installed. Install the yt-dlp package (or run ./install.sh again) to download videos and audio."
                        : "ffmpeg is not installed: audio can't be converted, and the best video qualities can't be put together."
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.textSmall
                }
            }
        }

        // The address.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Field {
                id: urlField
                Layout.fillWidth: true
                enabled: !root.missing
                placeholderText: "Paste a video or playlist address"
                invalid: text.trim() !== "" && root.url === "" || !!root.info?.error
                onAccepted: root.download()
            }
            IconButton {
                glyph: urlField.text ? "󰅖" : "󰅇"
                onClicked: {
                    if (urlField.text)
                        urlField.text = "";
                    else
                        paste.running = true;
                    urlField.forceActiveFocus();
                }
            }
        }

        // What the address is: looking it up, its title and length, or why yt-dlp can't read it.
        Rectangle {
            Layout.fillWidth: true
            visible: root.url !== ""
            implicitHeight: preview.implicitHeight + 16
            radius: Theme.radiusSmall
            color: Theme.raised
            border.color: Theme.line
            RowLayout {
                id: preview
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
                spacing: 12
                ClippingRectangle {
                    visible: !!root.info?.thumbnail
                    implicitWidth: 96
                    implicitHeight: 54
                    radius: Theme.corner(8)
                    color: Theme.control
                    Image {
                        anchors.fill: parent
                        source: root.info?.thumbnail ?? ""
                        sourceSize: Qt.size(192, 108)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Glyph {
                    visible: !root.info?.thumbnail
                    Layout.preferredWidth: 22
                    Layout.leftMargin: 4
                    text: root.looking ? "󰔟" : root.info?.error ? "󰅚" : root.audio ? "󰎈" : "󰕧"
                    size: 16
                    color: root.info?.error ? Theme.rose : Theme.accent
                    RotationAnimation on rotation {
                        running: root.looking && !Theme.reducedMotion
                        from: 0; to: 360; duration: 1200; loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.rotation = 0
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.fillWidth: true
                        text: root.info?.error ? "yt-dlp can't download this" : root.info?.title || (root.looking ? "Looking it up…" : root.url)
                        font.weight: root.info?.title ? Font.DemiBold : Font.Normal
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: {
                            const i = root.info;
                            if (!i)
                                return "";
                            if (i.error)
                                return i.error;
                            const parts = [];
                            if (i.kind === "playlist")
                                parts.push(i.entries === 1 ? "Playlist · 1 video" : `Playlist · ${i.entries} videos`);
                            if (i.channel)
                                parts.push(i.channel);
                            if (i.duration > 0)
                                parts.push(Downloads.clock(i.duration));
                            if (i.kind === "video" && i.heights?.length)
                                parts.push(`up to ${i.heights[0]}p`);
                            return parts.join(" · ");
                        }
                        font.pixelSize: Theme.textSmall
                        color: root.info?.error ? Theme.rose : Theme.muted
                        wrapMode: root.info?.error ? Text.Wrap : Text.NoWrap
                        maximumLineCount: 3
                    }
                }
            }
        }

        SwitchRow {
            visible: Downloads.inPlaylist(root.url) && root.info?.kind !== "playlist" && !root.info?.error
            glyph: "󰲸"
            title: "Whole playlist"
            subtitle: "Every video in it, in a folder of its own"
            checked: root.wholePlaylist
            onToggled: root.wholePlaylist = !root.wholePlaylist
        }

        // Video or audio, format, quality.
        ColumnLayout {
            Layout.fillWidth: true
            enabled: !root.missing
            opacity: enabled ? 1 : 0.5
            spacing: 8

            Segmented {
                Layout.fillWidth: true
                options: [
                    { value: "video", title: "Video", glyph: "󰕧", available: !root.info?.audioOnly },
                    { value: "audio", title: "Audio only", glyph: "󰎈" }
                ]
                current: root.audio ? "audio" : "video"
                onChosen: value => root.remember("kind", value)
            }

            Overline { Layout.fillWidth: true; Layout.topMargin: 4; text: "Format" }
            Segmented {
                Layout.fillWidth: true
                options: Downloads.formats(root.audio)
                current: root.format
                onChosen: value => root.remember(root.audio ? "audioFormat" : "videoFormat", value)
            }

            Overline { Layout.fillWidth: true; Layout.topMargin: 4; text: "Quality" }
            Segmented {
                Layout.fillWidth: true
                visible: root.qualities.length > 0
                options: root.qualities
                current: root.quality
                onChosen: value => root.remember(root.audio ? "audioQuality" : "videoQuality", value)
            }
            Label {
                Layout.fillWidth: true
                visible: root.qualities.length === 0
                text: "Lossless: the best sound the source has"
                font.pixelSize: Theme.textSmall
                color: Theme.textSoft
            }
            Label {
                Layout.fillWidth: true
                visible: !root.audio && root.quality !== "best"
                text: "The largest that isn't taller, when the video has no " + (root.quality === "2160" ? "4K" : root.quality + "p")
                font.pixelSize: Theme.textTiny
                color: Theme.dim
            }

            Overline { Layout.fillWidth: true; Layout.topMargin: 4; text: "Save in" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Field {
                    id: folderField
                    Layout.fillWidth: true
                    text: Downloads.home(root.folder, root.home)
                    placeholderText: "Folder"
                    onEditingFinished: {
                        const path = Downloads.expand(text, root.home);
                        if (path && path !== root.folder)
                            root.remember(root.audio ? "audioFolder" : "videoFolder", path.replace(/(.)\/+$/, "$1"));
                        text = Qt.binding(() => Downloads.home(root.folder, root.home));
                    }
                }
                PillButton {
                    text: root.choosingFolder ? "Choosing…" : "Browse…"
                    available: !root.choosingFolder
                    onClicked: chooser.running = true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: root.playlist ? "The whole playlist" : ""
                font.pixelSize: Theme.textSmall
                color: Theme.muted
            }
            PillButton {
                text: root.audio ? "Download audio" : "Download video"
                primary: true
                implicitHeight: 34
                available: root.canDownload
                onClicked: root.download()
            }
        }

        // Downloads in progress and finished ones, newest first.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.jobs.length > 0
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Overline { Layout.fillWidth: true; text: "Downloads" }
                Label {
                    visible: root.jobs.some(j => !Downloads.active(j))
                    text: "Clear finished"
                    font.pixelSize: Theme.textSmall
                    color: clearArea.containsMouse ? Theme.accentBright : Theme.accent
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([root.helper, "forget"])
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 250)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.jobs
                        delegate: Rectangle {
                            id: job
                            required property var modelData
                            readonly property bool running: Downloads.active(modelData)
                            readonly property bool failed: modelData.status === "failed"
                            readonly property bool done: modelData.status === "done"
                            Layout.fillWidth: true
                            implicitHeight: jobColumn.implicitHeight + 14
                            radius: Theme.radiusSmall
                            color: jobArea.containsMouse ? Theme.raised : "transparent"
                            Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

                            MouseArea {
                                id: jobArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            ColumnLayout {
                                id: jobColumn
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7; leftMargin: 10; rightMargin: 4 }
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Glyph {
                                        Layout.preferredWidth: 22
                                        text: job.failed ? "󰅚" : job.done ? "󰄬" : job.modelData.kind === "audio" ? "󰎈" : "󰕧"
                                        size: 16
                                        color: job.failed ? Theme.rose : job.done ? Theme.green : job.running ? Theme.accent : Theme.dim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label {
                                            Layout.fillWidth: true
                                            text: Downloads.title(job.modelData)
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: Downloads.describe(job.modelData, root.home)
                                            font.pixelSize: Theme.textSmall
                                            color: job.failed ? Theme.rose : Theme.muted
                                        }
                                    }
                                    IconButton {
                                        visible: job.done && !!job.modelData.file && !(job.modelData.items > 1)
                                        glyph: "󰐊"
                                        onClicked: { Ui.close(); Ui.spawn(["xdg-open", job.modelData.file]); }
                                    }
                                    IconButton {
                                        visible: job.done
                                        glyph: "󰉋"
                                        onClicked: {
                                            Ui.close();
                                            Ui.spawn(["xdg-open", job.modelData.file ? job.modelData.file.replace(/\/[^\/]*$/, "") : job.modelData.folder]);
                                        }
                                    }
                                    IconButton {
                                        glyph: "󰅖"
                                        tint: job.running ? Theme.rose : Theme.dim
                                        onClicked: Quickshell.execDetached([root.helper, job.running ? "cancel" : "forget", job.modelData.id])
                                    }
                                }

                                // Progress; sliding while the size isn't known yet, or while it converts.
                                Rectangle {
                                    id: track
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 32
                                    Layout.rightMargin: 6
                                    Layout.bottomMargin: 2
                                    visible: job.running
                                    readonly property bool known: job.modelData.status === "downloading" && job.modelData.percent >= 0
                                    implicitHeight: 4
                                    radius: Theme.corner(2)
                                    color: Theme.line
                                    clip: true
                                    Rectangle {
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.accent
                                        width: track.known ? parent.width * Math.min(100, job.modelData.percent) / 100 : parent.width * 0.3
                                        Behavior on width { enabled: track.known && !Theme.reducedMotion; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        NumberAnimation on x {
                                            running: !track.known && job.running && track.visible && !Theme.reducedMotion
                                            from: -track.width * 0.3
                                            to: track.width
                                            duration: 1300
                                            loops: Animation.Infinite
                                            onRunningChanged: if (!running) parent.x = 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
