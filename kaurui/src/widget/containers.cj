package kaurui.widget

import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// Panel: a Row/Column container built on StackLayout.
// ---------------------------------------------------------------------------

public class Panel <: WidgetBase {
    private var childList: Array<Widget>
    private let axisValue: MainAxis
    private let spacingValue: Float32
    private let paddingValue: Insets
    private let crossAlignValue: CrossAlign
    private let mainAlignValue: MainAlign
    private let backgroundValue: ?Color

    private var cacheValid: Bool = false
    private var lastMinW: Float32 = 0.0f32
    private var lastMaxW: Float32 = 0.0f32
    private var lastMinH: Float32 = 0.0f32
    private var lastMaxH: Float32 = 0.0f32
    private var lastCount: Int64 = 0
    private var lastVersion: Int64 = 0
    private var lastSize: Size = Size.ZERO

    public init(
        children: Array<Widget>,
        axis!: MainAxis = MainAxis.Vertical,
        spacing!: Float32 = 8.0f32,
        padding!: Insets = Insets.zero(),
        crossAlign!: CrossAlign = CrossAlign.Start,
        mainAlign!: MainAlign = MainAlign.Start,
        background!: ?Color = None,
        flex!: Float32 = 0.0f32
    ) {
        super(flex)
        childList = children.clone()
        axisValue = axis
        spacingValue = spacing
        paddingValue = padding
        crossAlignValue = crossAlign
        mainAlignValue = mainAlign
        backgroundValue = background
    }

    public prop children: Array<Widget> {
        get() {
            childList
        }
    }

    public func add(child: Widget): Unit {
        childList = childList.concat([child])
        bumpVersion()
        invalidateSelf()
    }

    public func setChildren(children: Array<Widget>): Unit {
        childList = children.clone()
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
        lastVersion == version
    }

    private func remember(c: Constraints, version: Int64, size: Size): Unit {
        cacheValid = true
        lastMinW = c.minWidth
        lastMaxW = c.maxWidth
        lastMinH = c.minHeight
        lastMaxH = c.maxHeight
        lastCount = Int64(childList.size)
        lastVersion = version
        lastSize = size
    }

    private func stackConfig(): StackConfig {
        StackConfig(spacingValue, crossAlignValue, mainAlignValue)
    }

    public func measure(c: Constraints): Size {
        let currentVersion = contentVersion()
        if (cacheMatches(c, currentVersion)) {
            LayoutStats.cacheHits += 1
            sizeValue = lastSize
            return lastSize
        }
        LayoutStats.measureCalls += 1
        let inner = c.deflate(paddingValue)
        let content = StackLayout.measure(toLayoutItems(childList), inner, axisValue, stackConfig())
        let total = Size(
            content.width + paddingValue.left + paddingValue.right,
            content.height + paddingValue.top + paddingValue.bottom
        )
        let measured = c.constrain(total)
        sizeValue = measured
        remember(c, currentVersion, measured)
        measured
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        StackLayout.arrange(
            toLayoutItems(childList),
            rect.inset(paddingValue),
            axisValue,
            stackConfig()
        )
    }

    public func paint(r: Renderer): Unit {
        if (let Some(bg) <- backgroundValue) {
            r.fillRect(boundsValue, bg)
        }
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

// ---------------------------------------------------------------------------
// SizedBox: fixed/fluid box, optionally wrapping one child.
// ---------------------------------------------------------------------------

public class SizedBox <: WidgetBase {
    private let widthValue: Float32
    private let heightValue: Float32
    private let childValue: ?Widget

    public init(
        width!: Float32 = 0.0f32,
        height!: Float32 = 0.0f32,
        child!: ?Widget = None,
        flex!: Float32 = 0.0f32
    ) {
        super(flex)
        widthValue = width
        heightValue = height
        childValue = child
    }

    public func measure(c: Constraints): Size {
        var w = widthValue
        var h = heightValue
        if (let Some(child) <- childValue) {
            // A fixed axis becomes a tight constraint for the child; an
            // unspecified axis keeps the loose behaviour of the parent.
            let minW = if (w > 0.0f32) {
                w
            } else {
                0.0f32
            }
            let maxW = if (w > 0.0f32) {
                w
            } else {
                c.maxWidth
            }
            let minH = if (h > 0.0f32) {
                h
            } else {
                0.0f32
            }
            let maxH = if (h > 0.0f32) {
                h
            } else {
                c.maxHeight
            }
            let childSize = child.measure(Constraints(minW, maxW, minH, maxH))
            if (w <= 0.0f32) {
                w = childSize.width
            }
            if (h <= 0.0f32) {
                h = childSize.height
            }
        }
        sizeValue = c.constrain(Size(w, h))
        sizeValue
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        if (let Some(child) <- childValue) {
            let w = if (widthValue > 0.0f32) {
                widthValue
            } else {
                rect.width
            }
            let h = if (heightValue > 0.0f32) {
                heightValue
            } else {
                rect.height
            }
            child.arrange(Rect(rect.x, rect.y, w, h))
        }
    }

    public func paint(r: Renderer): Unit {
        if (let Some(child) <- childValue) {
            child.paint(r)
        }
    }

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        if (let Some(child) <- childValue) {
            child.bind(ctx)
        }
    }

    public override func hitTest(p: Point): Option<Widget> {
        if (!boundsValue.contains(p)) {
            return None
        }
        if (let Some(child) <- childValue) {
            if (let Some(hit) <- child.hitTest(p)) {
                return Some(hit)
            }
        }
        Some(this)
    }

    public override func subtreeWidgets(): Array<Widget> {
        var out: Array<Widget> = [this]
        if (let Some(child) <- childValue) {
            out = out.concat(child.subtreeWidgets())
        }
        out
    }

    public override func focusOrder(): Array<Widget> {
        var out = super.focusOrder()
        if (let Some(child) <- childValue) {
            out = out.concat(child.focusOrder())
        }
        out
    }
}

// ---------------------------------------------------------------------------
// Spacer: occupies flex space but paints and hit-tests nothing.
// ---------------------------------------------------------------------------

public class Spacer <: WidgetBase {
    public init(flex!: Float32 = 1.0f32) {
        super(flex)
    }

    public func measure(c: Constraints): Size {
        sizeValue = c.constrain(Size(0.0f32, 0.0f32))
        sizeValue
    }

    public func paint(r: Renderer): Unit {}

    public override func hitTest(p: Point): Option<Widget> {
        None
    }
}
