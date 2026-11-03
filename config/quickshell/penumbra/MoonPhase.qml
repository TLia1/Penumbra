import QtQuick

// Local phase illustration, with the same palette in every mode. No emoji font dependency.
Canvas {
    id: root
    property real phase: 0
    property color lit: Theme.accentBright
    property color shade: Theme.control
    property color rim: Theme.lineStrong
    implicitWidth: 38
    implicitHeight: 38
    onPhaseChanged: requestPaint()
    onLitChanged: requestPaint()
    onShadeChanged: requestPaint()
    onRimChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.scale(width / 128, height / 128);
        const c = 64, r = 53, k = 0.55228475;
        const p = ((phase % 1) + 1) % 1;
        const waxing = p <= 0.5;
        const tx = Math.cos(p * 2 * Math.PI) * r * (waxing ? 1 : -1);
        ctx.beginPath();
        ctx.arc(c, c, r, 0, 2 * Math.PI);
        ctx.fillStyle = shade;
        ctx.fill();
        ctx.strokeStyle = rim;
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(c, c - r);
        ctx.arc(c, c, r, -Math.PI / 2, Math.PI / 2, !waxing);
        ctx.bezierCurveTo(c + k * tx, c + r, c + tx, c + k * r, c + tx, c);
        ctx.bezierCurveTo(c + tx, c - k * r, c + k * tx, c - r, c, c - r);
        ctx.closePath();
        ctx.fillStyle = lit;
        ctx.fill();
    }
}
