import QtQuick
import QtQuick.Layouts
import QtTest

Item {
    width: 1000
    height: 800
    ColumnLayout {
        id: layout
        Rectangle {
            id: card
            implicitWidth: 100
            implicitHeight: 100
            StaggerReveal {
                id: reveal
                shown: false
                order: 2
            }
        }
    }
    DesktopDepth {
        id: depth
        active: true
        running: true
        center: Qt.point(500, 500)
        orbitRadius: 200
        clockY: 10
    }
    Rectangle {
        id: frameFixture
        width: 600
        height: 400
        color: "#123456"
        FrameSurface {
            id: frame
            anchors.fill: parent
        }
    }
    TestCase {
        name: "Phase2Motion"
        when: windowShown
        function test_frame() {
            wait(50);
            let image = grabImage(frameFixture);
            compare(image.pixel(1, 200), Theme.surface);
            compare(image.pixel(300, 25), frameFixture.color); // the bar remains unobscured
            compare(image.pixel(300, 200), frameFixture.color); // windows still show through
            compare(image.pixel(300, 52), Theme.surface); // joined underside of the bar
            compare(image.pixel(4, 55), Theme.surface); // concave rounded corner
            Theme.sharp = true;
            wait(50);
            image = grabImage(frameFixture);
            compare(image.pixel(4, 55), frameFixture.color); // no round cutout in sharp mode
            Theme.sharp = false;
        }
        function test_reveal() {
            compare(card.opacity, 0);
            compare(card.transform.length, 1);
            reveal.shown = true;
            wait(10);
            compare(card.opacity, 0);
            tryCompare(card, "opacity", 1, 1000);
            compare(card.y, 0);
            compare(card.transform[0].y, 0);
            reveal.shown = false;
            compare(card.opacity, 0);
            reveal.shown = true;
            wait(70);
            reveal.shown = false;
            compare(card.opacity, 0);
            reveal.shown = true;
            Theme.reducedMotion = true;
            compare(card.opacity, 1);
            compare(card.transform[0].y, 0);
            wait(400);
            compare(card.opacity, 1);
            reveal.shown = false;
            compare(card.opacity, 0);
            Theme.reducedMotion = false;
        }
        function test_depth() {
            compare(depth.live, true);
            compare(depth.samples.length, 8);
            depth.running = false;
            compare(depth.live, false);
            compare(depth.samples.length, 0);
            depth.running = true;
            Theme.reducedMotion = true;
            compare(depth.live, false);
            Theme.reducedMotion = false;
            depth.active = false;
            compare(depth.visible, false);
            compare(depth.live, false);
            depth.active = true;
            Settings.desktopAura = false;
            compare(depth.live, false);
            Settings.desktopAura = true;
            Ui.hasVisualizer = false;
            compare(depth.live, false);
            Ui.hasVisualizer = true;
            Media.playing = false;
            compare(depth.live, false);
            Media.playing = true;
        }
    }
}
