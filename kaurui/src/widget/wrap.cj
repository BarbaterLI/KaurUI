package kaurui.widget

import std.collection.*
import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// WrapPanel: lays children out left-to-right and wraps to the next row when
// the available width is exhausted. Row height is the tallest child of that row.
// ---------------------------------------------------------------------------

public class WrapPanel <: WidgetBase {
    private let UNBOUNDED_WIDTH: Float32 = 1000000.0f32

    private var childList: Array<Widget>
    private var horizontalSpacingValue: Float32
    private var verticalSpacingValue: Float32
    private let crossAlignValue: CrossAlign
    private var rowStartsValue: Array<Int64> = Array<Int64>()

    private var cacheValid: Bool = false
    private var lastMinW: Float32 = 0.0f32
    private var lastMaxW: Float32 = 0.0f32
    private var lastMinH: Float32 = 0.0f32
    private var lastMaxH: Float32 = 0.0f32
    private var lastCount: Int64 = 0
    private var lastVersion: Int64 = 0
    private var lastHorizontalSpacing: Float32 = 0.0f32
    private var lastVerticalSpacing: Float32 = 0.0f32
    private var lastCrossAlign: CrossAlign = CrossAlign.Start
    private var lastSize: Size = Size.ZERO

    public init(
        children: Array<Widget>,
        horizontalSpacing!: Float32 = 8.0f32,
        verticalSpacing!: Float32 = 8.0f32,
        crossAlign!: CrossAlign = CrossAlign.Start,
        flex!: Float32 = 0.0f32
    ) {
        super(flex)
        childList = children.clone()
        horizontalSpacingValue = horizontalSpacing
        verticalSpacingValue = verticalSpacing
        crossAlignValue = crossAlign
    }

    public prop children: Array<Widget> {
        get() {
            childList
        }
    }

    public func setSpacing(horizontal: Float32, vertical: Float32): Unit {
        horizontalSpacingValue = horizontal
        verticalSpacingValue = vertical
        bumpVersion()
        invalidateSelf()
    }

    public override func contentVersion(): Int64 {
        var total = version
        for (child in childList) {
            total += widgetContentVersion(child)
        }
        total
    }

    private func cacheMatches(c: Constraints, version: Int64): Bool {
        if (!cacheValid) {
            return false
        }
        if (lastMinW != c.minWidth) {
            return false
        }
        if (lastMaxW != c.maxWidth) {
            return false
        }
        if (lastMinH != c.minHeight) {
            return false
        }
        if (lastMaxH != c.maxHeight) {
            return false
        }
        if (lastCount != Int64(childList.size)) {
            return false
        }
        if (lastVersion != version) {
            return false
        }
        if (lastHorizontalSpacing != horizontalSpacingValue) {
            return false
        }
        if (lastVerticalSpacing != verticalSpacingValue) {
            return false
        }
        match (lastCrossAlign) {
            case CrossAlign.Start => match (crossAlignValue) {
                case CrossAlign.Start => true;
                case _ => false
            }
            case CrossAlign.Center => match (crossAlignValue) {
                case CrossAlign.Center => true;
                case _ => false
            }
            case CrossAlign.End => match (crossAlignValue) {
                case CrossAlign.End => true;
                case _ => false
            }
            case CrossAlign.Stretch => match (crossAlignValue) {
                case CrossAlign.Stretch => true;
                case _ => false
            }
        }
    }

    private func remember(c: Constraints, version: Int64, size: Size): Unit {
        cacheValid = true
        lastMinW = c.minWidth
        lastMaxW = c.maxWidth
        lastMinH = c.minHeight
        lastMaxH = c.maxHeight
        lastCount = Int64(childList.size)
        lastVersion = version
        lastHorizontalSpacing = horizontalSpacingValue
        lastVerticalSpacing = verticalSpacingValue
        lastCrossAlign = crossAlignValue
        lastSize = size
    }

    public func measure(c: Constraints): Size {
        let currentVersion = contentVersion()
        if (cacheMatches(c, currentVersion)) {
            LayoutStats.cacheHits += 1
            sizeValue = lastSize
            return lastSize
        }
        LayoutStats.measureCalls += 1
        let n = childList.size
        if (n == 0) {
            sizeValue = c.constrain(Size(0.0f32, 0.0f32))
            remember(c, currentVersion, sizeValue)
            return sizeValue
        }
        var avail = c.maxWidth
        let unbounded = avail > UNBOUNDED_WIDTH
        if (unbounded) {
            avail = Float32.Inf
        }
        let childConstraints = Constraints.loose(avail, c.maxHeight)
        for (child in childList) {
            child.measure(childConstraints)
        }
        if (unbounded) {
            // No finite width: everything fits on one row.
            var sum = 0.0f32
            for (child in childList) {
                sum += child.size.width
            }
            avail = sum + horizontalSpacingValue * Float32(n - 1)
        }

        let starts = ArrayList<Int64>()
        starts.add(0)
        var rowWidth = childList[0].size.width
        var rowHeight = childList[0].size.height
        var maxRowWidth = 0.0f32
        var totalHeight = 0.0f32
        for (i in 1..n) {
            let childSize = childList[i].size
            let candidate = rowWidth + horizontalSpacingValue + childSize.width
            if (candidate > avail) {
                maxRowWidth = widgetMax(maxRowWidth, rowWidth)
                totalHeight += rowHeight + verticalSpacingValue
                starts.add(i)
                rowWidth = childSize.width
                rowHeight = childSize.height
            } else {
                rowWidth = candidate
                rowHeight = widgetMax(rowHeight, childSize.height)
            }
        }
        maxRowWidth = widgetMax(maxRowWidth, rowWidth)
        totalHeight += rowHeight
        rowStartsValue = starts.toArray()
        let measured = c.constrain(Size(maxRowWidth, totalHeight))
        sizeValue = measured
        remember(c, currentVersion, measured)
        measured
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        let n = childList.size
        if (n == 0 || rowStartsValue.size == 0) {
            return
        }
        var y = rect.y
        for (ri in 0..rowStartsValue.size) {
            let from = rowStartsValue[ri]
            let to = if (ri + 1 < rowStartsValue.size) {
                rowStartsValue[ri + 1]
            } else {
                n
            }
            var rowHeight = 0.0f32
            for (i in from..to) {
                rowHeight = widgetMax(rowHeight, childList[i].size.height)
            }
            var x = rect.x
            for (i in from..to) {
                let childSize = childList[i].size
                let childY = match (crossAlignValue) {
                    case CrossAlign.Center => y + (rowHeight - childSize.height) * 0.5f32
                    case _ => y
                }
                childList[i].arrange(Rect(x, childY, childSize.width, childSize.height))
                x += childSize.width + horizontalSpacingValue
            }
            y += rowHeight + verticalSpacingValue
        }
    }

    public func paint(r: Renderer): Unit {
        for (child in childList) {
            if (let Some(clip) <- r.currentClip) {
                if (child.bounds.intersect(clip).isNone()) {
                    LayoutStats.paintSkips += 1
                    continue
                }
            }
            child.paint(r)
        }
    }

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        for (child in childList) {
            child.bind(ctx)
        }
    }

    public override func hitTest(p: Point): Option<Widget> {
        if (!boundsValue.contains(p)) {
            return None
        }
        var i = childList.size - 1
        while (i >= 0) {
            if (let Some(hit) <- childList[i].hitTest(p)) {
                return Some(hit)
            }
            i -= 1
        }
        Some(this)
    }

    public override func subtreeWidgets(): Array<Widget> {
        var out: Array<Widget> = [this]
        for (child in childList) {
            out = out.concat(child.subtreeWidgets())
        }
        out
    }

    public override func focusOrder(): Array<Widget> {
        var out = super.focusOrder()
        for (child in childList) {
            out = out.concat(child.focusOrder())
        }
        out
    }
}
