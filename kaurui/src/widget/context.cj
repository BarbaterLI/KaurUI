package kaurui.widget

import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// WidgetContext: injected by the app when a widget subtree is mounted.
// ---------------------------------------------------------------------------

public class WidgetContext {
    public var theme: Theme
    public var invalidateHandler: (Widget) -> Unit
    public var paintInvalidateHandler: (Widget) -> Unit
    public var focusHandler: (Widget) -> Unit
    public var measureTextHandler: (String, TextStyle) -> Size
    public var clipboard: Clipboard

    public init(theme: Theme) {
        this.theme = theme
        this.invalidateHandler = {_ => ()}
        this.paintInvalidateHandler = {_ => ()}
        this.focusHandler = {_ => ()}
        this.measureTextHandler = {text, style => estimateTextSize(text, style)}
        this.clipboard = MemoryClipboard()
    }

    public func invalidate(w: Widget): Unit {
        invalidateHandler(w)
    }

    public func invalidatePaint(w: Widget): Unit {
        paintInvalidateHandler(w)
    }

    public func requestFocus(w: Widget): Unit {
        focusHandler(w)
    }

    public func measureText(text: String, style: TextStyle): Size {
        measureTextHandler(text, style)
    }
}
