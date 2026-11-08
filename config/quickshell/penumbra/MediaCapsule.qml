import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Capsule {
    id: root
    shown: !!Media.player
    padding: 12
    spacing: 10
    tip: ""
    // The player can disappear during the exit animation.
    onClicked: m => {
        if (m.button === Qt.MiddleButton) Media.player?.togglePlaying();
        else { pinned = !popup.visible || !pinned; popup.visible = pinned; }
    }
    onScrolled: step => step > 0 ? Media.player?.previous() : Media.player?.next()

    property bool pinned: false
    property color artTint: Theme.accentBright
    onHoveredChanged: hovered ? openDelay.restart() : closeDelay.restart()
    onShownChanged: if (!shown) { pinned = false; popup.visible = false; }
    property Timer openDelay: Timer {
        interval: 280
        onTriggered: if (root.hovered && Media.player) popup.visible = true
    }
    property Timer closeDelay: Timer {
        interval: 350
        onTriggered: if (!root.hovered && !popup.hovered && !root.pinned) popup.visible = false
    }
    property MediaPopover popup: MediaPopover {
        anchor.item: root
        onHoveredChanged: if (!hovered) root.closeDelay.restart()
        onDismissed: { root.pinned = false; visible = false; }
    }
    // Quantize a tiny cover sample; use its most common saturated colour for the spectrum.
    // This runs once per cover, never once per audio frame.
    property Canvas sampler: Canvas {
        parent: root
        width: 16; height: 16; opacity: 0
        property string art: Media.player?.trackArtUrl ?? ""
        property string previous: ""
        onArtChanged: {
            root.artTint = Theme.accentBright;
            if (previous) unloadImage(previous);
            previous = art;
            if (art) loadImage(art);
        }
        onImageLoaded: requestPaint()
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            if (!art || !isImageLoaded(art)) return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 16, 16); ctx.drawImage(art, 0, 0, 16, 16);
            const pixels = ctx.getImageData(0, 0, 16, 16).data;
            const buckets = {}; let best = null;
            for (let i = 0; i < pixels.length; i += 4) {
                const r = pixels[i], g = pixels[i+1], b = pixels[i+2];
                if (pixels[i+3] < 128 || Math.max(r,g,b) < 65 || Math.max(r,g,b)-Math.min(r,g,b) < 25) continue;
                const key = [r >> 5, g >> 5, b >> 5].join(",");
                const v = buckets[key] ?? (buckets[key] = {n: 0, r: 0, g: 0, b: 0});
                v.n++; v.r += r; v.g += g; v.b += b;
                if (!best || v.n > best.n) best = v;
            }
            if (best) root.artTint = Qt.rgba(best.r / best.n / 255, best.g / best.n / 255, best.b / best.n / 255, 1);
        }
    }

    ClippingRectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: Theme.corner(6)
        color: Theme.raised
        Image {
            id: cover
            anchors.fill: parent
            source: Media.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(48, 48)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Glyph {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "󰎆"
            size: 15
            color: Theme.accentBright
        }
    }
    Row {
        visible: Ui.hasVisualizer
        spacing: 2
        Layout.preferredHeight: 18
        Repeater {
            model: Media.count
            delegate: Rectangle {
                required property int index
                anchors.verticalCenter: parent?.verticalCenter
                width: 3
                height: 5 + (Media.bars[index] ?? 0) * 13
                radius: Theme.corner(1.5)
                color: root.artTint
                Behavior on height { NumberAnimation { duration: 60 * Theme.motion } }
            }
        }
    }
}
