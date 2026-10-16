import QtQuick

Item {
    id: root

    property var times: []
    property var voltages: []
    property var currents: []

    readonly property color voltageColor: "#facc15"
    readonly property color currentColor: "#22d3ee"
    readonly property color gridColor: "#2a2a2a"
    readonly property color axisColor: "#555555"

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            ctx.reset()
            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, w, h)

            const left = 52
            const right = 52
            const top = 16
            const bottom = 32
            const plotW = Math.max(1, w - left - right)
            const plotH = Math.max(1, h - top - bottom)

            let maxV = 16
            let maxI = 16
            const vList = root.voltages || []
            const iList = root.currents || []
            const tList = root.times || []
            for (let i = 0; i < vList.length; ++i) {
                const v = Number(vList[i])
                if (v > maxV)
                    maxV = v
            }
            for (let i = 0; i < iList.length; ++i) {
                const cur = Number(iList[i])
                if (cur > maxI)
                    maxI = cur
            }
            maxV = Math.max(1, Math.ceil(maxV * 1.1))
            maxI = Math.max(1, Math.ceil(maxI * 1.1))

            let minT = 0
            let maxT = 30
            if (tList.length > 0) {
                minT = Number(tList[0])
                maxT = Number(tList[tList.length - 1])
                if (maxT - minT < 30)
                    maxT = minT + 30
            }
            const spanT = Math.max(1e-6, maxT - minT)

            function xOf(t) { return left + (t - minT) / spanT * plotW }
            function yV(v) { return top + (1 - v / maxV) * plotH }
            function yI(i) { return top + (1 - i / maxI) * plotH }

            ctx.strokeStyle = root.gridColor
            ctx.lineWidth = 1
            const ticks = 8
            ctx.beginPath()
            for (let n = 0; n <= ticks; ++n) {
                const y = top + plotH * n / ticks
                ctx.moveTo(left, y)
                ctx.lineTo(left + plotW, y)
            }
            ctx.moveTo(left + plotW / 2, top)
            ctx.lineTo(left + plotW / 2, top + plotH)
            ctx.stroke()

            ctx.strokeStyle = root.axisColor
            ctx.strokeRect(left, top, plotW, plotH)

            ctx.font = "12px sans-serif"
            ctx.textBaseline = "middle"
            for (let n = 0; n <= ticks; ++n) {
                const ratio = 1 - n / ticks
                const y = top + plotH * n / ticks
                ctx.fillStyle = root.voltageColor
                ctx.textAlign = "right"
                ctx.fillText(String(Math.round(maxV * ratio)), left - 8, y)
                ctx.fillStyle = root.currentColor
                ctx.textAlign = "left"
                ctx.fillText(String(Math.round(maxI * ratio)), left + plotW + 8, y)
            }

            ctx.fillStyle = "#bbbbbb"
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            const timeTicks = 6
            for (let n = 0; n <= timeTicks; ++n) {
                const t = minT + spanT * n / timeTicks
                ctx.fillText(t.toFixed(0) + "s", xOf(t), top + plotH + 8)
            }

            function drawSeries(values, color, yFunc) {
                if (!values || values.length === 0 || tList.length === 0)
                    return
                const count = Math.min(values.length, tList.length)
                ctx.strokeStyle = color
                ctx.lineWidth = 2
                ctx.beginPath()
                for (let i = 0; i < count; ++i) {
                    const x = xOf(Number(tList[i]))
                    const y = yFunc(Number(values[i]))
                    if (i === 0)
                        ctx.moveTo(x, y)
                    else
                        ctx.lineTo(x, y)
                }
                ctx.stroke()
            }

            drawSeries(vList, root.voltageColor, yV)
            drawSeries(iList, root.currentColor, yI)

            ctx.fillStyle = "#888888"
            ctx.textAlign = "left"
            ctx.textBaseline = "bottom"
            ctx.fillText("Sampling 5.000s", left + 8, h - 6)
        }
    }

    onTimesChanged: canvas.requestPaint()
    onVoltagesChanged: canvas.requestPaint()
    onCurrentsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}
