package kaurui.widget

// ---------------------------------------------------------------------------
// Clipboard: text clipboard abstraction. The default implementation lives in
// process memory; an app can inject a system-backed one through WidgetContext.
// ---------------------------------------------------------------------------

public interface Clipboard {
    func getText(): String
    func setText(text: String): Unit
}

// In-process text clipboard, used by tests and as the fallback when no system
// clipboard is available.
public class MemoryClipboard <: Clipboard {
    private var textValue: String = ""

    public init() {}

    public func getText(): String {
        textValue
    }

    public func setText(text: String): Unit {
        textValue = text
    }
}
