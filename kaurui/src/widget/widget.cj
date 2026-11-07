package kaurui.widget

import std.collection.*
import kaurui.layout.*
import kaurui.render.*

public let MODULE_NAME: String = "kaurui.widget"

// ---------------------------------------------------------------------------
// Events delivered by the app to the hit widget.
// ---------------------------------------------------------------------------

public enum UiEvent {
    | MouseEnter
    | MouseLeave
    | MouseDown(Float32, Float32)
    | MouseUp(Float32, Float32)
    | MouseMove(Float32, Float32)
    | Wheel(Float32, Float32, Float32)
    | KeyDown(UInt32, Bool, Bool)
    | Char(UInt32)
    | FocusChanged(Bool)
}

// ---------------------------------------------------------------------------
// Widget contract
// ---------------------------------------------------------------------------

public interface Widget <: LayoutItem {
    func bind(ctx: WidgetContext): Unit
    func paint(r: Renderer): Unit
    func hitTest(p: Point): Option<Widget>
    func onEvent(e: UiEvent): Unit
    prop bounds: Rect
    prop focusable: Bool
    prop focused: Bool
    func setFocus(v: Bool): Unit
    func focusOrder(): Array<Widget>
    func subtreeWidgets(): Array<Widget>
    func isClickable(): Bool
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

func estimateTextSize(text: String, style: TextStyle): Size {
    let chars = Float32(text.size)
    Size(chars * style.fontSize * 0.6f32, style.fontSize * 1.4f32)
}

func clamp01(v: Float32): Float32 {
    if (v < 0.0f32) {
        return 0.0f32
    }
    if (v > 1.0f32) {
        return 1.0f32
    }
    v
}

func widgetMax(a: Float32, b: Float32): Float32 {
    if (a >= b) {
        a
    } else {
        b
    }
}

func toLayoutItems(items: Array<Widget>): Array<LayoutItem> {
    let out = ArrayList<LayoutItem>(items.size)
    for (item in items) {
        out.add(item)
    }
    out.toArray()
}

// Reads the content version of a widget through the WidgetBase contract so
// containers can sum the versions of their children.
func widgetContentVersion(w: Widget): Int64 {
    if (let Some(base) <- (w as WidgetBase)) {
        return base.contentVersion()
    }
    0
}

// ---------------------------------------------------------------------------
// WidgetBase: shared state and default behaviour.
// ---------------------------------------------------------------------------

public abstract class WidgetBase <: Widget {
    protected var ctxValue: Option<WidgetContext> = None
    protected var boundsValue: Rect = Rect.ZERO
    protected var sizeValue: Size = Size.ZERO
    protected var focusValue: Bool = false
    protected var focusableValue: Bool = false
    protected var flexValue: Float32
    private var versionValue: Int64 = 0

    protected init(flex: Float32) {
        flexValue = flex
    }

    // Content version: bumped by layout-affecting mutations only. Visual state
    // such as hover, caret or scroll offsets must never bump it.
    public prop version: Int64 {
        get() {
            versionValue
        }
    }

    protected func bumpVersion(): Unit {
        versionValue += 1
    }

    // Containers override this to include the versions of their children.
    public open func contentVersion(): Int64 {
        versionValue
    }

    public prop bounds: Rect {
        get() {
            boundsValue
        }
    }

    public prop size: Size {
        get() {
            sizeValue
        }
    }

    public prop flex: Float32 {
        get() {
            flexValue
        }
    }

    public prop focusable: Bool {
        get() {
            focusableValue
        }
    }

    public prop focused: Bool {
        get() {
            focusValue
        }
    }

    public func measure(c: Constraints): Size

    public func paint(r: Renderer): Unit

    public open func bind(ctx: WidgetContext): Unit {
        ctxValue = Some(ctx)
    }

    public open func arrange(rect: Rect): Unit {
        boundsValue = rect
    }

    public open func hitTest(p: Point): Option<Widget> {
        if (boundsValue.contains(p)) {
            return Some(this)
        }
        None
    }

    public open func onEvent(e: UiEvent): Unit {}

    public open func setFocus(v: Bool): Unit {
        if (focusValue != v) {
            focusValue = v
            invalidateSelf()
        }
    }

    public open func focusOrder(): Array<Widget> {
        if (focusableValue) {
            return [this]
        }
        Array<Widget>()
    }

    public open func subtreeWidgets(): Array<Widget> {
        [this]
    }

    public open func isClickable(): Bool {
        false
    }

    protected func invalidateSelf(): Unit {
        if (let Some(c) <- ctxValue) {
            c.invalidate(this)
        }
    }

    protected func invalidatePaintSelf(): Unit {
        if (let Some(c) <- ctxValue) {
            c.invalidatePaint(this)
        }
    }

    protected func themeOf(): Theme {
        if (let Some(c) <- ctxValue) {
            return c.theme
        }
        Theme.light()
    }

    protected func measureTextOf(text: String, fontSize: Float32, bold: Bool): Size {
        let style = TextStyle(fontSize, bold)
        if (let Some(c) <- ctxValue) {
            return c.measureText(text, style)
        }
        estimateTextSize(text, style)
    }
}
