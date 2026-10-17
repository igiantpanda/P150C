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

            // Round a range up to a "nice" 1/2/5 x 10^n step.
            function niceCeil(x) {
                if (!(x > 0) || !isFinite(x))
                    return 1
                const exp = Math.floor(Math.log10(x))
                const f = x / Math.pow(10, exp)
                let nf
                if (f <= 1)
                    nf = 1
                else if (f <= 2)
                    nf = 2
                else if (f <= 5)
                    nf = 5
                else
                    nf = 10
                return nf * Math.pow(10, exp)
            }

            function decimalsForStep(step) {
                if (step >= 1)
                    return 0
                if (step >= 0.1)
                    return 1
                if (step >= 0.01)
                    return 2
                return 3
            }

            // Compute axis bounds that tightly fit the data, with a small
            // margin and round tick values.
            function axisBounds(list) {
                let mn = Infinity
                let mx = -Infinity
                const src = list || []
                for (let i = 0; i < src.length; ++i) {
                    const v = Number(src[i])
                    if (!isFinite(v))
                        continue
                    if (v < mn)
                        mn = v
                    if (v > mx)
                        mx = v
                }
                if (!isFinite(mn))
                    return { lo: 0, hi: 16, step: 2, n: 8, dec: 0 }

                const range = mx - mn
                const pad = range > 0 ? range * 0.1 : Math.max(Math.abs(mx) * 0.1, 0.5)
                let rawLo = mn - pad
                const rawHi = mx + pad
                // Keep 0 as baseline when the data starts close to zero.
                if (!(rawLo > 0) || mn <= Math.max(mx, 1) * 0.05)
                    rawLo = 0

                const step = niceCeil(Math.max(1e-9, (rawHi - rawLo) / 8))
                const dec = decimalsForStep(step)
                let lo = Math.floor(rawLo / step + 1e-9) * step
                let hi = Math.ceil(rawHi / step - 1e-9) * step
                if (hi <= lo)
                    hi = lo + step
                let n = Math.max(1, Math.round((hi - lo) / step))
                lo = Number(lo.toFixed(dec + 2))
                hi = Number((lo + n * step).toFixed(dec + 2))
                return { lo: lo, hi: hi, step: step, n: n, dec: dec }
            }

            const vList = root.voltages || []
            const iList = root.currents || []
            const tList = root.times || []

            const bV = axisBounds(vList)
            const bI = axisBounds(iList)

            // Use the same number of divisions for both axes so that grid
            // lines, voltage labels and current labels always line up.
            const divisions = Math.max(bV.n, bI.n)
            bV.hi = Number((bV.lo + divisions * bV.step).toFixed(bV.dec + 2))
            bV.n = divisions
            bI.hi = Number((bI.lo + divisions * bI.step).toFixed(bI.dec + 2))
            bI.n = divisions

            // Time axis: choose a nice step targeting ~6 intervals and
            // display seconds / minutes / hours depending on the span.
            let span = 30
            if (tList.length > 0) {
                const tFirst = Number(tList[0])
                const tLast = Number(tList[tList.length - 1])
                if (isFinite(tFirst) && isFinite(tLast) && tLast > tFirst)
                    span = tLast - tFirst
            }
            const timeSteps = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900,
                               1800, 3600, 7200, 10800, 21600, 43200, 86400]
            const target = span / 6
            let tStep = timeSteps[timeSteps.length - 1]
            for (let i = 0; i < timeSteps.length; ++i) {
                if (timeSteps[i] >= target) {
                    tStep = timeSteps[i]
                    break
                }
            }
            let minT = 0
            let maxT = Math.max(tStep, Math.ceil(span / tStep) * tStep)
            if (tList.length > 0) {
                const tFirst = Number(tList[0])
                if (isFinite(tFirst))
                    minT = Math.floor(tFirst / tStep) * tStep
            }
            const spanT = Math.max(1e-6, maxT - minT)
            let timeUnit = "s"
            if (span >= 3600)
                timeUnit = "h"
            else if (span >= 60)
                timeUnit = "m"

            function pad2(v) { return v < 10 ? "0" + v : String(v) }
            function formatTime(t) {
                const s = Math.round(t)
                if (timeUnit === "s")
                    return s + "s"
                const hh = Math.floor(s / 3600)
                const mm = Math.floor((s % 3600) / 60)
                const ss = s % 60
                if (timeUnit === "h")
                    return hh + ":" + pad2(mm) + ":" + pad2(ss)
                return pad2(mm) + ":" + pad2(ss)
            }
            function formatValue(v, dec) {
                return Number(v).toFixed(dec)
            }

            function xOf(t) { return left + (t - minT) / spanT * plotW }
            function yOf(v, b) { return top + (1 - (v - b.lo) / (b.hi - b.lo)) * plotH }

            // Grid lines.
            ctx.strokeStyle = root.gridColor
            ctx.lineWidth = 1
            ctx.beginPath()
            for (let k = 0; k <= divisions; ++k) {
                const y = top + plotH * k / divisions
                ctx.moveTo(left, y)
                ctx.lineTo(left + plotW, y)
            }
            const timeCount = Math.round((maxT - minT) / tStep)
            for (let k = 0; k <= timeCount; ++k) {
                const x = xOf(minT + k * tStep)
                ctx.moveTo(x, top)
                ctx.lineTo(x, top + plotH)
            }
            ctx.stroke()

            ctx.strokeStyle = root.axisColor
            ctx.strokeRect(left, top, plotW, plotH)

            // Voltage / current tick labels.
            ctx.font = "12px sans-serif"
            ctx.textBaseline = "middle"
            for (let k = 0; k <= divisions; ++k) {
                const y = top + plotH * k / divisions
                ctx.fillStyle = root.voltageColor
                ctx.textAlign = "right"
                ctx.fillText(formatValue(bV.lo + (divisions - k) * bV.step, bV.dec),
                             left - 8, y)
                ctx.fillStyle = root.currentColor
                ctx.textAlign = "left"
                ctx.fillText(formatValue(bI.lo + (divisions - k) * bI.step, bI.dec),
                             left + plotW + 8, y)
            }

            // Time tick labels.
            ctx.fillStyle = "#bbbbbb"
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            for (let k = 0; k <= timeCount; ++k) {
                const t = minT + k * tStep
                ctx.fillText(formatTime(t), xOf(t), top + plotH + 8)
            }

            function drawSeries(values, color, b) {
                if (!values || values.length === 0 || tList.length === 0)
                    return
                const count = Math.min(values.length, tList.length)
                ctx.strokeStyle = color
                ctx.lineWidth = 2
                ctx.beginPath()
                for (let i = 0; i < count; ++i) {
                    const x = xOf(Number(tList[i]))
                    const y = yOf(Number(values[i]), b)
                    if (i === 0)
                        ctx.moveTo(x, y)
                    else
                        ctx.lineTo(x, y)
                }
                ctx.stroke()
            }

            drawSeries(vList, root.voltageColor, bV)
            drawSeries(iList, root.currentColor, bI)

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
