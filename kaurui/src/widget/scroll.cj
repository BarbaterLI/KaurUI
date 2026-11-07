package kaurui.widget

import std.collection.*
import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// ScrollView: a vertical scrolling viewport around a single child.
// ---------------------------------------------------------------------------

public class ScrollView <: WidgetBase {
    private let SCROLLBAR_WIDTH: Float32 = 4.0f32
    private let SCROLL_STEP: Float32 = 40.0f32
    private let MIN_THUMB_HEIGHT: Float32 = 16.0f32

    private let childValue: Widget
    private let backgroundValue: ?Color
    private var offsetValue: Float32 = 0.0f32
    private var maxOffsetValue: Float32 = 0.0f32
    private var childHeightValue: Float32 = 0.0f32
    private var arrangedValue: Bool = false

    public init(child: Widget, flex!: Float32 = 0.0f32, background!: ?Color = None) {
        super(flex)
        childValue = child
        backgroundValue = background
    }

    public prop offset: Float32 {
        get() {
            offsetValue
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
            if (arrangedValue) {
                placeChild()
            }
            invalidatePaintSelf()
        }
    }

    public func measure(c: Constraints): Size {
        // Main axis (vertical) is unbounded, cross axis follows the parent width.
        let childConstraints = Constraints(0.0f32, c.maxWidth, 0.0f32, Float32.Inf)
        let childSize = childValue.measure(childConstraints)
        childHeightValue = childSize.height
        sizeValue = c.constrain(Size(childSize.width, childSize.height))
        maxOffsetValue = widgetMax(0.0f32, childHeightValue - sizeValue.height)
        if (offsetValue > maxOffsetValue) {
            offsetValue = maxOffsetValue
            if (arrangedValue) {
                placeChild()
            }
        }
        sizeValue
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        maxOffsetValue = widgetMax(0.0f32, childHeightValue - rect.height)
        if (offsetValue > maxOffsetValue) {
            offsetValue = maxOffsetValue
        }
        arrangedValue = true
        placeChild()
    }

    public func paint(r: Renderer): Unit {
        let th = themeOf()
        r.pushClip(boundsValue)
        if (let Some(bg) <- backgroundValue) {
            r.fillRect(boundsValue, bg)
        }
        childValue.paint(r)
        r.popClip()
        paintScrollbar(r, th)
    }

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        childValue.bind(ctx)
    }

    public override func hitTest(p: Point): Option<Widget> {
        if (!boundsValue.contains(p)) {
            return None
        }
        // Child bounds already live in the parent's absolute coordinate space.
        if (let Some(hit) <- childValue.hitTest(p)) {
            return Some(hit)
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
        out = out.concat(childValue.subtreeWidgets())
        out
    }

    public override func focusOrder(): Array<Widget> {
        var out = super.focusOrder()
        out = out.concat(childValue.focusOrder())
        out
    }

    private func placeChild(): Unit {
        let width = if (boundsValue.width > 0.0f32) {
            boundsValue.width
        } else {
            sizeValue.width
        }
        childValue.arrange(Rect(boundsValue.x, boundsValue.y - offsetValue, width, childHeightValue))
    }

    private func paintScrollbar(r: Renderer, th: Theme): Unit {
        if (maxOffsetValue <= 0.0f32 || childHeightValue <= 0.0f32) {
            return
        }
        let viewport = boundsValue.height
        if (viewport <= 0.0f32) {
            return
        }
        let track = Rect(boundsValue.x + boundsValue.width - SCROLLBAR_WIDTH, boundsValue.y, SCROLLBAR_WIDTH, viewport)
        r.fillRect(track, th.border)

        var thumbHeight = viewport * viewport / childHeightValue
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
