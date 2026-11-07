package kaurui.widget

import kaurui.render.*

// ---------------------------------------------------------------------------
// Theme: all colors/fonts/spacing used by widgets come from here.
// ---------------------------------------------------------------------------

public struct Theme {
    public var background: Color
    public var surface: Color
    public var primary: Color
    public var primaryHover: Color
    public var primaryPressed: Color
    public var onPrimary: Color
    public var text: Color
    public var textSecondary: Color
    public var border: Color
    public var focusRing: Color
    public var disabledSurface: Color
    public var disabledText: Color
    public var fontSize: Float32
    public var titleFontSize: Float32
    public var spacing: Float32
    public var radius: Float32

    public init() {
        background = Color.rgb(245, 247, 250)
        surface = Color.rgb(255, 255, 255)
        primary = Color.rgb(52, 120, 246)
        primaryHover = Color.rgb(80, 145, 250)
        primaryPressed = Color.rgb(30, 95, 210)
        onPrimary = Color.rgb(255, 255, 255)
        text = Color.rgb(24, 28, 36)
        textSecondary = Color.rgb(120, 128, 140)
        border = Color.rgb(205, 211, 220)
        focusRing = Color.rgb(66, 133, 244)
        disabledSurface = Color.rgb(225, 228, 233)
        disabledText = Color.rgb(150, 156, 166)
        fontSize = 14.0f32
        titleFontSize = 20.0f32
        spacing = 8.0f32
        radius = 6.0f32
    }

    public static func light(): Theme {
        Theme()
    }

    public static func dark(): Theme {
        var t = Theme()
        t.background = Color.rgb(28, 30, 34)
        t.surface = Color.rgb(42, 45, 50)
        t.primary = Color.rgb(86, 150, 250)
        t.primaryHover = Color.rgb(110, 170, 255)
        t.primaryPressed = Color.rgb(60, 120, 220)
        t.onPrimary = Color.rgb(255, 255, 255)
        t.text = Color.rgb(235, 238, 242)
        t.textSecondary = Color.rgb(150, 158, 170)
        t.border = Color.rgb(70, 74, 82)
        t.focusRing = Color.rgb(110, 170, 255)
        t.disabledSurface = Color.rgb(56, 59, 65)
        t.disabledText = Color.rgb(115, 120, 130)
        return t
    }
}
