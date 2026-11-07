package kaurui.widget

import std.collection.*
import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// ListView: a vertically virtualized list of fixed-height items.
// Only the items inside the visible range (plus overscan) are materialized.
// ---------------------------------------------------------------------------

public class ListView <: WidgetBase {
    private let SCROLLBAR_WIDTH: Float32 = 4.0f32
    private let SCROLL_STEP: Float32 = 40.0f32
    private let MIN_THUMB_HEIGHT: Float32 = 16.0f32

    private let itemCountValue: Int64
    private let itemHeightValue: Float32
    private let builderValue: (Int64) -> Widget
    private let binderValue: ?((Widget, Int64) -> Unit)
    private let backgroundValue: ?Color
    private let overscanValue: Int64
    private let heightProviderValue: ?((Int64) -> Float32)

    private var builderCallsValue: Int64 = 0
    private var bindCallsValue: Int64 = 0

    private var offsetValue: Float32 = 0.0f32
    private var maxOffsetValue: Float32 = 0.0f32
    private var viewportHeightValue: Float32 = 0.0f32
    private var arrangedValue: Bool = false

    private var childMap: HashMap<Int64, Widget> = HashMap<Int64, Widget>()
    private var builtLoValue: Int64 = 1
    private var builtHiValue: Int64 = 0

    // Cached prefix sums for variable-height mode; prefix[i] is the top of row i.
    private var prefixValue: Array<Float32> = Array<Float32>()
    private var prefixReadyValue: Bool = false

    public init(
        itemCount!: Int64,
        itemHeight!: Float32,
        builder!: (Int64) -> Widget,
        flex!: Float32 = 0.0f32,
        background!: ?Color = None,
        overscan!: Int64 = 1,
        heightProvider!: ?((Int64) -> Float32) = None,
        binder!: ?((Widget, Int64) -> Unit) = None
    ) {
        super(flex)
        itemCountValue = itemCount
        itemHeightValue = itemHeight
        builderValue = builder
        binderValue = binder
        backgroundValue = background
        overscanValue = overscan
        heightProviderValue = heightProvider
    }

    public prop offset: Float32 {
        get() {
            offsetValue
        }
    }

    public prop builtCount: Int64 {
        get() {
            childMap.size
        }
    }

    // Total number of builder invocations so far, including the throwaway
    // probe used for width measurement in unbounded layouts.
    public prop builderCalls: Int64 {
        get() {
            builderCallsValue
        }
    }

    // Total number of binder invocations; only raised when a materialized
    // child is rebound to a different index.
    public prop bindCalls: Int64 {
        get() {
            bindCallsValue
        }
    }

    public prop firstVisibleIndex: Int64 {
        get() {
            if (heightProviderValue.isSome()) {
                return firstVisibleVariableIndex()
            }
            if (itemCountValue <= 0 || itemHeightValue <= 0.0f32) {
                return 0
            }
            var idx = Int64(offsetValue / itemHeightValue)
            if (idx < 0) {
                idx = 0
            }
            if (idx > itemCountValue - 1) {
                idx = itemCountValue - 1
            }
            idx
        }
    }

    public prop contentHeight: Float32 {
        get() {
            contentHeightOf()
        }
    }

    public func scrollBy(deltaPixels: Float32): Unit {
        setOffset(offsetValue + deltaPixels)
    }

    public func setOffset(v: Float32): Unit {
        var next = v
        if (next < 0.0f32) {
            next = 0.0f32
        }
        if (next > maxOffsetValue) {
            next = maxOffsetValue
        }
        if (next != offsetValue) {
            offsetValue = next
            refreshItems()
            invalidatePaintSelf()
        }
    }

    public func measure(c: Constraints): Size {
        let contentHeight = contentHeightOf()
        var viewport = contentHeight
        if (c.maxHeight < Float32.Inf) {
            viewport = if (contentHeight < c.maxHeight) {
                contentHeight
            } else {
                c.maxHeight
            }
        }
        let width = if (c.maxWidth < Float32.Inf) {
            c.maxWidth
        } else {
            firstItemWidth(c)
        }
        sizeValue = c.constrain(Size(width, viewport))
        viewportHeightValue = sizeValue.height
        maxOffsetValue = widgetMax(0.0f32, contentHeight - sizeValue.height)
        if (offsetValue > maxOffsetValue) {
            offsetValue = maxOffsetValue
        }
        refreshItems()
        sizeValue
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        viewportHeightValue = rect.height
        maxOffsetValue = widgetMax(0.0f32, contentHeightOf() - rect.height)
        if (offsetValue > maxOffsetValue) {
            offsetValue = maxOffsetValue
        }
        arrangedValue = true
        refreshItems()
    }

    public func paint(r: Renderer): Unit {
        r.pushClip(boundsValue)
        if (let Some(bg) <- backgroundValue) {
            r.fillRect(boundsValue, bg)
        }
        if (builtHiValue >= builtLoValue) {
            for (i in builtLoValue..=builtHiValue) {
                if (let Some(child) <- childMap.get(i)) {
                    child.paint(r)
                }
            }
        }
        r.popClip()
        paintScrollbar(r, themeOf())
    }

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        if (builtHiValue >= builtLoValue) {
            for (i in builtLoValue..=builtHiValue) {
                if (let Some(child) <- childMap.get(i)) {
                    child.bind(ctx)
                }
            }
        }
    }

    public override func hitTest(p: Point): Option<Widget> {
        if (!boundsValue.contains(p)) {
            return None
        }
        var i = builtHiValue
        while (i >= builtLoValue) {
            if (let Some(child) <- childMap.get(i)) {
                if (let Some(hit) <- child.hitTest(p)) {
                    return Some(hit)
                }
            }
            i -= 1
        }
        Some(this)
    }

    public override func onEvent(e: UiEvent): Unit {
        match (e) {
            case Wheel(delta, _, _) => scrollBy(-delta * SCROLL_STEP)
            case _ => ()
        }
    }

    public override func subtreeWidgets(): Array<Widget> {
        var out: Array<Widget> = [this]
        if (builtHiValue >= builtLoValue) {
            for (i in builtLoValue..=builtHiValue) {
                if (let Some(child) <- childMap.get(i)) {
                    out = out.concat(child.subtreeWidgets())
                }
            }
        }
        out
    }

    public override func focusOrder(): Array<Widget> {
        var out: Array<Widget> = [this]
        if (builtHiValue >= builtLoValue) {
            for (i in builtLoValue..=builtHiValue) {
                if (let Some(child) <- childMap.get(i)) {
                    out = out.concat(child.focusOrder())
                }
            }
        }
        out
    }

    private func contentHeightOf(): Float32 {
        if (heightProviderValue.isSome()) {
            if (itemCountValue <= 0) {
                return 0.0f32
            }
            ensurePrefix()
            return prefixValue[itemCountValue]
        }
        Float32(itemCountValue) * itemHeightValue
    }

    // Builds the prefix-sum array exactly once, so the provider is never called
    // more than itemCount times.
    private func ensurePrefix(): Unit {
        if (prefixReadyValue) {
            return
        }
        let pre = ArrayList<Float32>()
        pre.add(0.0f32)
        if (let Some(hp) <- heightProviderValue) {
            var acc = 0.0f32
            for (i in 0..itemCountValue) {
                var h = hp(i)
                if (h <= 0.0f32) {
                    h = 1.0f32
                }
                acc += h
                pre.add(acc)
            }
        }
        prefixValue = pre.toArray()
        prefixReadyValue = true
    }

    private func itemHeightAtIndex(i: Int64): Float32 {
        if (heightProviderValue.isSome()) {
            ensurePrefix()
            return prefixValue[i + 1] - prefixValue[i]
        }
        itemHeightValue
    }

    // Largest i in [0, itemCount] with prefix[i] <= target.
    private func prefixLastNotExceeding(target: Float32): Int64 {
        var lo: Int64 = 0
        var hi: Int64 = itemCountValue
        while (lo < hi) {
            let mid = (lo + hi + 1) / 2
            if (prefixValue[mid] <= target) {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        lo
    }

    private func firstVisibleVariableIndex(): Int64 {
        if (itemCountValue <= 0) {
            return 0
        }
        ensurePrefix()
        var idx = prefixLastNotExceeding(offsetValue)
        if (idx > itemCountValue - 1) {
            idx = itemCountValue - 1
        }
        if (idx < 0) {
            idx = 0
        }
        idx
    }

    private func lastVisibleVariableIndex(): Int64 {
        ensurePrefix()
        var idx = prefixLastNotExceeding(offsetValue + viewportHeightValue)
        if (idx > itemCountValue - 1) {
            idx = itemCountValue - 1
        }
        idx
    }

    private func firstItemWidth(c: Constraints): Float32 {
        if (itemCountValue <= 0) {
            return 0.0f32
        }
        let idx = firstVisibleIndex
        let probeHeight = if (heightProviderValue.isSome()) {
            itemHeightAtIndex(idx)
        } else {
            itemHeightValue
        }
        if (let Some(child) <- childMap.get(idx)) {
            return child.measure(Constraints.loose(c.maxWidth, probeHeight)).width
        }
        buildWidget(idx).measure(Constraints.loose(c.maxWidth, probeHeight)).width
    }

    private func buildWidget(i: Int64): Widget {
        builderCallsValue += 1
        builderValue(i)
    }

    // Resolves the visible index range and keeps only the children inside it.
    private func refreshItems(): Unit {
        let variable = heightProviderValue.isSome()
        if (itemCountValue <= 0 || (!variable && itemHeightValue <= 0.0f32)) {
            childMap.clear()
            builtLoValue = 1
            builtHiValue = 0
            return
        }
        let first = firstVisibleIndex
        var last = if (variable) {
            lastVisibleVariableIndex()
        } else {
            Int64((offsetValue + viewportHeightValue) / itemHeightValue)
        }
        if (last < first) {
            last = first
        }
        if (last > itemCountValue - 1) {
            last = itemCountValue - 1
        }
        var lo = first - overscanValue
        if (lo < 0) {
            lo = 0
        }
        var hi = last + overscanValue
        if (hi > itemCountValue - 1) {
            hi = itemCountValue - 1
        }
        let retained = HashMap<Int64, Widget>()
        // Children whose index left the new range are parked for reuse; a
        // widget is rebound to a different index instead of building a new one.
        let pool = ArrayList<Widget>()
        let reusable = binderValue.isSome()
        if (reusable) {
            for ((i, child) in childMap) {
                if (i < lo || i > hi) {
                    pool.add(child)
                }
            }
        }
        var poolCursor: Int64 = 0
        if (hi >= lo) {
            for (i in lo..=hi) {
                match (childMap.get(i)) {
                    case Some(child) => retained.add(i, child)
                    case None =>
                        if (poolCursor < pool.size) {
                            let reused = pool[poolCursor]
                            poolCursor += 1
                            if (let Some(binder) <- binderValue) {
                                binder(reused, i)
                                bindCallsValue += 1
                            }
                            retained.add(i, reused)
                        } else {
                            let child = buildWidget(i)
                            if (let Some(c) <- ctxValue) {
                                child.bind(c)
                            }
                            retained.add(i, child)
                        }
                }
            }
        }
        childMap = retained
        builtLoValue = lo
        builtHiValue = hi
        arrangeChildren()
    }

    private func arrangeChildren(): Unit {
        if (!arrangedValue || builtHiValue < builtLoValue) {
            return
        }
        let variable = heightProviderValue.isSome()
        if (variable) {
            ensurePrefix()
        }
        for (i in builtLoValue..=builtHiValue) {
            if (let Some(child) <- childMap.get(i)) {
                let top = if (variable) {
                    prefixValue[i]
                } else {
                    Float32(i) * itemHeightValue
                }
                let height = if (variable) {
                    prefixValue[i + 1] - prefixValue[i]
                } else {
                    itemHeightValue
                }
                child.arrange(
                    Rect(
                        boundsValue.x,
                        top - offsetValue + boundsValue.y,
                        boundsValue.width,
                        height
                    )
                )
            }
        }
    }

    private func paintScrollbar(r: Renderer, th: Theme): Unit {
        let contentHeight = contentHeightOf()
        if (maxOffsetValue <= 0.0f32 || contentHeight <= 0.0f32) {
            return
        }
        let viewport = boundsValue.height
        if (viewport <= 0.0f32) {
            return
        }
        let track = Rect(boundsValue.x + boundsValue.width - SCROLLBAR_WIDTH, boundsValue.y, SCROLLBAR_WIDTH, viewport)
        r.fillRect(track, th.border)

        var thumbHeight = viewport * viewport / contentHeight
        if (thumbHeight < MIN_THUMB_HEIGHT) {
            thumbHeight = MIN_THUMB_HEIGHT
        }
        if (thumbHeight > viewport) {
            thumbHeight = viewport
        }
        let travel = viewport - thumbHeight
        let ratio = if (maxOffsetValue > 0.0f32) {
            offsetValue / maxOffsetValue
        } else {
            0.0f32
        }
        r.fillRect(Rect(track.x, track.y + travel * ratio, SCROLLBAR_WIDTH, thumbHeight), th.textSecondary)
    }
}
