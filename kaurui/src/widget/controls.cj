package kaurui.widget

import std.collection.*
import kaurui.layout.*
import kaurui.render.*
import kaurui.ffi.*

// ---------------------------------------------------------------------------
// Label
// ---------------------------------------------------------------------------

public class Label <: WidgetBase {
    private let LARGE_WIDTH: Float32 = 1000000.0f32

    private var textValue: String
    private let fontSizeValue: Float32
    private let boldValue: Bool
    private let colorValue: ?Color
    private let alignValue: TextAlign
    private let wrapValue: Bool
    private var linesValue: Array<String> = Array<String>()

    public init(
        text: String,
        fontSize!: Float32 = 14.0f32,
        bold!: Bool = false,
        color!: ?Color = None,
        align!: TextAlign = TextAlign.Left,
        wrap!: Bool = false,
        flex!: Float32 = 0.0f32
    ) {
        super(flex)
        textValue = text
        fontSizeValue = fontSize
        boldValue = bold
        colorValue = color
        alignValue = align
        wrapValue = wrap
    }

    public func setText(text: String): Unit {
        textValue = text
        linesValue = Array<String>()
        bumpVersion()
        invalidateSelf()
    }

    public func measure(c: Constraints): Size {
        if (!wrapValue) {
            let measured = measureTextOf(textValue, fontSizeValue, boldValue)
            sizeValue = c.constrain(measured)
            return sizeValue
        }
        linesValue = wrapLines(c.maxWidth)
        var width = 0.0f32
        for (line in linesValue) {
            width = widgetMax(width, measureTextOf(line, fontSizeValue, boldValue).width)
        }
        let lineHeight = fontSizeValue * 1.4f32
        sizeValue = c.constrain(Size(width, lineHeight * Float32(linesValue.size)))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        let th = themeOf()
        let col = match (colorValue) {
            case Some(v) => v
            case None => th.text
        }
        let style = TextStyle(fontSizeValue, boldValue)
        if (!wrapValue) {
            r.drawText(textValue, boundsValue, style, col, alignValue)
            return
        }
        let lines = if (linesValue.isEmpty()) {
            wrapLines(boundsValue.width)
        } else {
            linesValue
        }
        let lineHeight = fontSizeValue * 1.4f32
        var y = boundsValue.y
        for (line in lines) {
            r.drawText(line, Rect(boundsValue.x, y, boundsValue.width, lineHeight), style, col, alignValue)
            y += lineHeight
        }
    }

    // Splits the text on explicit newlines and on the available width. When the
    // width is unbounded (or effectively unbounded) only newlines break lines.
    private func wrapLines(availableWidth: Float32): Array<String> {
        let lines = ArrayList<String>()
        let bounded = availableWidth > 0.0f32 && availableWidth < LARGE_WIDTH
        var line = ""
        for (r in textValue.runes()) {
            if (r == r'\n') {
                lines.add(line)
                line = ""
                continue
            }
            let candidate = line + r.toString()
            if (bounded && !line.isEmpty() && measureTextOf(candidate, fontSizeValue, boldValue).width > availableWidth) {
                lines.add(line)
                line = r.toString()
            } else {
                line = candidate
            }
        }
        if (!line.isEmpty() || lines.size == 0) {
            lines.add(line)
        }
        lines.toArray()
    }
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

public class Button <: WidgetBase {
    private let textValue: String
    private let onClickValue: () -> Unit
    private var enabledValue: Bool
    private var hoverValue: Bool = false
    private var pressedValue: Bool = false

    public init(
        text: String,
        onClick!: () -> Unit = {=>},
        enabled!: Bool = true,
        flex!: Float32 = 0.0f32
    ) {
        super(flex)
        textValue = text
        onClickValue = onClick
        enabledValue = enabled
    }

    public prop enabled: Bool {
        get() {
            enabledValue
        }
    }

    public func setEnabled(v: Bool): Unit {
        enabledValue = v
        if (!v) {
            hoverValue = false
            pressedValue = false
        }
        bumpVersion()
        invalidateSelf()
    }

    public func measure(c: Constraints): Size {
        let th = themeOf()
        let textSize = measureTextOf(textValue, th.fontSize, false)
        sizeValue = c.constrain(Size(textSize.width + 24.0f32, textSize.height + 12.0f32))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        let th = themeOf()
        let bg = if (!enabledValue) {
            th.disabledSurface
        } else if (pressedValue) {
            th.primaryPressed
        } else if (hoverValue) {
            th.primaryHover
        } else {
            th.primary
        }
        let fg = if (!enabledValue) {
            th.disabledText
        } else {
            th.onPrimary
        }
        r.fillRoundRect(boundsValue, th.radius, bg)
        let inner = boundsValue.inset(Insets(12.0f32, 6.0f32, 12.0f32, 6.0f32))
        r.drawText(textValue, inner, TextStyle(th.fontSize, false), fg, TextAlign.Center)
    }

    public override func onEvent(e: UiEvent): Unit {
        match (e) {
            case MouseEnter =>
                if (enabledValue) {
                    hoverValue = true
                    invalidatePaintSelf()
                }
            case MouseLeave =>
                hoverValue = false
                pressedValue = false
                invalidatePaintSelf()
            case MouseDown(_, _) =>
                if (enabledValue) {
                    pressedValue = true
                    invalidatePaintSelf()
                }
            case MouseUp(x, y) =>
                if (pressedValue) {
                    pressedValue = false
                    invalidatePaintSelf()
                    if (enabledValue && boundsValue.contains(Point(x, y))) {
                        onClickValue()
                    }
                }
            case _ => ()
        }
    }

    public override func isClickable(): Bool {
        true
    }
}

// ---------------------------------------------------------------------------
// CheckBox
// ---------------------------------------------------------------------------

public class CheckBox <: WidgetBase {
    private let labelValue: String
    private var checkedValue: Bool
    private let onChangeValue: (Bool) -> Unit

    public init(
        label: String,
        checked!: Bool = false,
        onChange!: (Bool) -> Unit = {_ =>},
        flex!: Float32 = 0.0f32
    ) {
        super(flex)
        labelValue = label
        checkedValue = checked
        onChangeValue = onChange
        focusableValue = true
    }

    public prop checked: Bool {
        get() {
            checkedValue
        }
    }

    public func setChecked(v: Bool): Unit {
        checkedValue = v
        onChangeValue(v)
        bumpVersion()
        invalidateSelf()
    }

    public func measure(c: Constraints): Size {
        let th = themeOf()
        let textSize = measureTextOf(labelValue, th.fontSize, false)
        let boxSize = 18.0f32
        let gap = 6.0f32
        let height = widgetMax(boxSize, textSize.height)
        sizeValue = c.constrain(Size(boxSize + gap + textSize.width, height))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        let th = themeOf()
        let boxSize = 18.0f32
        let gap = 6.0f32
        let boxY = boundsValue.y + (boundsValue.height - boxSize) * 0.5f32
        let boxRect = Rect(boundsValue.x, boxY, boxSize, boxSize)
        if (checkedValue) {
            r.fillRoundRect(boxRect, 3.0f32, th.primary)
            r.drawText("✓", boxRect, TextStyle(12.0f32, false), th.onPrimary, TextAlign.Center)
        } else {
            r.fillRoundRect(boxRect, 3.0f32, th.surface)
            r.strokeRoundRect(boxRect, 3.0f32, th.border, 1.0f32)
        }
        let labelRect = Rect(
            boundsValue.x + boxSize + gap,
            boundsValue.y,
            widgetMax(0.0f32, boundsValue.width - boxSize - gap),
            boundsValue.height
        )
        r.drawText(labelValue, labelRect, TextStyle(th.fontSize, false), th.text, TextAlign.Left)
    }

    public override func onEvent(e: UiEvent): Unit {
        match (e) {
            case MouseUp(x, y) =>
                if (boundsValue.contains(Point(x, y))) {
                    setChecked(!checkedValue)
                }
            case KeyDown(vk, _, _) =>
                if (focusValue && vk == UInt32(0x20)) {
                    setChecked(!checkedValue)
                }
            case FocusChanged(f) => setFocus(f)
            case _ => ()
        }
    }

    public override func isClickable(): Bool {
        true
    }
}

// ---------------------------------------------------------------------------
// TextField
// ---------------------------------------------------------------------------

public class TextField <: WidgetBase {
    private var textValue: String
    private let placeholderValue: String
    private let onChangeValue: (String) -> Unit
    private let onSubmitValue: (String) -> Unit
    private var caretValue: Int64 = 0
    private var anchorValue: Int64 = 0
    private var scrollXValue: Float32 = 0.0f32
    // Ctrl state of the last key-down; WM_CHAR carries no modifiers, so a
    // Ctrl chord must suppress the printable character that follows it.
    private var ctrlHeldValue: Bool = false

    public init(
        text!: String = "",
        placeholder!: String = "",
        onChange!: (String) -> Unit = {_ =>},
        onSubmit!: (String) -> Unit = {_ =>},
        flex!: Float32 = 0.0f32
    ) {
        super(flex)
        textValue = text
        placeholderValue = placeholder
        onChangeValue = onChange
        onSubmitValue = onSubmit
        focusableValue = true
        caretValue = Int64(text.toRuneArray().size)
        anchorValue = caretValue
    }

    public prop text: String {
        get() {
            textValue
        }
    }

    public prop caret: Int64 {
        get() {
            caretValue
        }
    }

    public prop anchor: Int64 {
        get() {
            anchorValue
        }
    }

    public prop scrollX: Float32 {
        get() {
            scrollXValue
        }
    }

    public prop selectionStart: Int64 {
        get() {
            selStart()
        }
    }

    public prop selectionEnd: Int64 {
        get() {
            selEnd()
        }
    }

    public func setText(v: String): Unit {
        textValue = v
        caretValue = runeLength()
        anchorValue = caretValue
        updateScroll()
        onChangeValue(v)
        bumpVersion()
        invalidateSelf()
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        updateScroll()
    }

    public func measure(c: Constraints): Size {
        let th = themeOf()
        let display = if (textValue.isEmpty()) {
            placeholderValue
        } else {
            textValue
        }
        let textSize = measureTextOf(display, th.fontSize, false)
        sizeValue = c.constrain(Size(textSize.width + 16.0f32, textSize.height + 12.0f32))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        let th = themeOf()
        r.fillRoundRect(boundsValue, th.radius, th.surface)
        if (focusValue) {
            r.strokeRoundRect(boundsValue, th.radius, th.focusRing, 2.0f32)
        } else {
            r.strokeRoundRect(boundsValue, th.radius, th.border, 1.0f32)
        }
        let inner = boundsValue.inset(Insets(8.0f32, 6.0f32, 8.0f32, 6.0f32))
        let style = TextStyle(th.fontSize, false)
        r.pushClip(inner)
        if (textValue.isEmpty()) {
            r.drawText(placeholderValue, inner, style, th.textSecondary, TextAlign.Left)
        } else {
            if (hasSelection()) {
                let startX = inner.x + textWidthOf(prefixOf(selStart())) - scrollXValue
                let endX = inner.x + textWidthOf(prefixOf(selEnd())) - scrollXValue
                r.fillRect(Rect(startX, inner.y, endX - startX, inner.height), th.border)
            }
            let textRect = Rect(inner.x - scrollXValue, inner.y, widgetMax(inner.width, textWidthOf(textValue)),
                inner.height)
            r.drawText(textValue, textRect, style, th.text, TextAlign.Left)
        }
        if (focusValue) {
            let caretX = inner.x + textWidthOf(caretPrefix()) - scrollXValue
            if (caretX >= inner.x && caretX <= inner.right) {
                r.fillRect(Rect(caretX, inner.y, 1.0f32, th.fontSize), th.text)
            }
        }
        r.popClip()
    }

    public override func setFocus(v: Bool): Unit {
        if (focusValue != v) {
            focusValue = v
            invalidatePaintSelf()
        }
    }

    public override func onEvent(e: UiEvent): Unit {
        match (e) {
            case Char(ch) =>
                if (!ctrlHeldValue && ch >= UInt32(0x20) && ch <= UInt32(0x7E)) {
                    insertRune(Rune(ch))
                }
            case KeyDown(vk, ctrl, shift) =>
                // Shift+arrow keeps the shift flag and also passes ctrl=true in
                // the event convention used by the tests, so only a real chord
                // (ctrl without shift) marks the following Char as suppressed.
                ctrlHeldValue = ctrl && !shift
                if (ctrl && vk == UInt32(0x43)) {
                    copySelection()
                } else if (ctrl && vk == UInt32(0x58)) {
                    cutSelection()
                } else if (ctrl && vk == UInt32(0x56)) {
                    paste()
                } else if (ctrl && vk == UInt32(0x41)) {
                    selectAll()
                } else if (vk == Vk.VK_RETURN) {
                    if (!shift) {
                        onSubmitValue(textValue)
                    }
                } else if (vk == Vk.VK_LEFT) {
                    moveCaretBy(-1, shift)
                } else if (vk == Vk.VK_RIGHT) {
                    moveCaretBy(1, shift)
                } else if (vk == Vk.VK_HOME) {
                    moveCaretTo(0, shift)
                } else if (vk == Vk.VK_END) {
                    moveCaretTo(runeLength(), shift)
                } else if (vk == Vk.VK_BACK) {
                    backspace()
                } else if (vk == Vk.VK_DELETE) {
                    deleteForward()
                }
            case FocusChanged(f) => setFocus(f)
            case _ => ()
        }
    }

    private func runeLength(): Int64 {
        Int64(textValue.toRuneArray().size)
    }

    private func prefixOf(index: Int64): String {
        let runes = textValue.toRuneArray()
        let len = Int64(runes.size)
        let end = if (index < len) {
            index
        } else {
            len
        }
        String(runes[0..end])
    }

    private func caretPrefix(): String {
        prefixOf(caretValue)
    }

    private func textWidthOf(text: String): Float32 {
        measureTextOf(text, themeOf().fontSize, false).width
    }

    private func selStart(): Int64 {
        if (caretValue < anchorValue) {
            return caretValue
        }
        anchorValue
    }

    private func selEnd(): Int64 {
        if (caretValue > anchorValue) {
            return caretValue
        }
        anchorValue
    }

    private func hasSelection(): Bool {
        caretValue != anchorValue
    }

    // Keeps the caret (and the selection edge it sits on) inside the visible
    // text area by moving the horizontal offset, then clamps to the text extent.
    private func updateScroll(): Unit {
        let inner = boundsValue.inset(Insets(8.0f32, 6.0f32, 8.0f32, 6.0f32))
        let viewport = widgetMax(0.0f32, inner.width)
        let caretX = textWidthOf(caretPrefix())
        var next = scrollXValue
        if (caretX - next > viewport) {
            next = caretX - viewport
        }
        if (caretX - next < 0.0f32) {
            next = caretX
        }
        let maxScroll = widgetMax(0.0f32, textWidthOf(textValue) - viewport)
        if (next < 0.0f32) {
            next = 0.0f32
        }
        if (next > maxScroll) {
            next = maxScroll
        }
        scrollXValue = next
    }

    private func moveCaretTo(target: Int64, keepAnchor: Bool): Unit {
        let len = runeLength()
        var next = target
        if (next < 0) {
            next = 0
        }
        if (next > len) {
            next = len
        }
        let anchorNext = if (keepAnchor) {
            anchorValue
        } else {
            next
        }
        if (caretValue != next || anchorValue != anchorNext) {
            caretValue = next
            anchorValue = anchorNext
            updateScroll()
            invalidatePaintSelf()
        }
    }

    // A plain arrow collapses an active selection to its edge; shift extends it.
    private func moveCaretBy(delta: Int64, keepAnchor: Bool): Unit {
        if (keepAnchor) {
            moveCaretTo(caretValue + delta, true)
        } else if (hasSelection()) {
            let target = if (delta < 0) {
                selStart()
            } else {
                selEnd()
            }
            moveCaretTo(target, false)
        } else {
            moveCaretTo(caretValue + delta, false)
        }
    }

    private func selectAll(): Unit {
        let len = runeLength()
        if (anchorValue != 0 || caretValue != len) {
            anchorValue = 0
            caretValue = len
            updateScroll()
            invalidatePaintSelf()
        }
    }

    // Removes the selected range without notifying listeners; callers decide
    // whether the edit should fire onChange.
    private func removeSelection(): Bool {
        if (!hasSelection()) {
            return false
        }
        let runes = textValue.toRuneArray()
        let len = Int64(runes.size)
        var start = selStart()
        var end = selEnd()
        if (start < 0) {
            start = 0
        }
        if (end > len) {
            end = len
        }
        if (end > start) {
            textValue = String(runes[0..start]) + String(runes[end..len])
        }
        caretValue = start
        anchorValue = start
        updateScroll()
        true
    }

    private func clipboardOf(): Option<Clipboard> {
        if (let Some(c) <- ctxValue) {
            return Some(c.clipboard)
        }
        None
    }

    private func selectedText(): String {
        let runes = textValue.toRuneArray()
        let start = selStart()
        let end = selEnd()
        if (end <= start) {
            return ""
        }
        String(runes[start..end])
    }

    private func copySelection(): Unit {
        if (!hasSelection()) {
            return
        }
        if (let Some(cb) <- clipboardOf()) {
            cb.setText(selectedText())
        }
    }

    private func cutSelection(): Unit {
        if (!hasSelection()) {
            return
        }
        if (let Some(cb) <- clipboardOf()) {
            cb.setText(selectedText())
        }
        if (removeSelection()) {
            onChangeValue(textValue)
            bumpVersion()
            invalidateSelf()
        }
    }

    // Pasted text is limited to printable ASCII, matching the typing constraint;
    // any other rune (newlines, CJK, control characters) is dropped.
    private func printableOnly(text: String): String {
        var out = ""
        for (r in text.runes()) {
            let code = UInt32(r)
            if (code >= 0x20 && code <= 0x7E) {
                out += r.toString()
            }
        }
        out
    }

    private func paste(): Unit {
        let raw = match (clipboardOf()) {
            case Some(cb) => cb.getText()
            case None => ""
        }
        let incoming = printableOnly(raw)
        if (incoming.isEmpty()) {
            return
        }
        removeSelection()
        let runes = textValue.toRuneArray()
        let len = Int64(runes.size)
        let at = if (caretValue < len) {
            caretValue
        } else {
            len
        }
        textValue = String(runes[0..at]) + incoming + String(runes[at..len])
        caretValue = at + Int64(incoming.toRuneArray().size)
        anchorValue = caretValue
        updateScroll()
        onChangeValue(textValue)
        bumpVersion()
        invalidateSelf()
    }

    private func insertRune(r: Rune): Unit {
        removeSelection()
        let runes = textValue.toRuneArray()
        let len = Int64(runes.size)
        let at = if (caretValue < len) {
            caretValue
        } else {
            len
        }
        textValue = String(runes[0..at]) + r.toString() + String(runes[at..len])
        caretValue = at + 1
        anchorValue = caretValue
        updateScroll()
        onChangeValue(textValue)
        bumpVersion()
        invalidateSelf()
    }

    private func backspace(): Unit {
        if (removeSelection()) {
            onChangeValue(textValue)
            bumpVersion()
            invalidateSelf()
            return
        }
        if (caretValue <= 0) {
            return
        }
        let runes = textValue.toRuneArray()
        textValue = String(runes[0..(caretValue - 1)]) + String(runes[caretValue..runes.size])
        caretValue -= 1
        anchorValue = caretValue
        updateScroll()
        onChangeValue(textValue)
        bumpVersion()
        invalidateSelf()
    }

    private func deleteForward(): Unit {
        if (removeSelection()) {
            onChangeValue(textValue)
            bumpVersion()
            invalidateSelf()
            return
        }
        let len = runeLength()
        if (caretValue >= len) {
            return
        }
        let runes = textValue.toRuneArray()
        textValue = String(runes[0..caretValue]) + String(runes[(caretValue + 1)..len])
        updateScroll()
        onChangeValue(textValue)
        bumpVersion()
        invalidateSelf()
    }

    public override func isClickable(): Bool {
        true
    }
}

// ---------------------------------------------------------------------------
// ProgressBar
// ---------------------------------------------------------------------------

public class ProgressBar <: WidgetBase {
    private var valueValue: Float32

    public init(value!: Float32 = 0.0f32, flex!: Float32 = 0.0f32) {
        super(flex)
        valueValue = clamp01(value)
    }

    public prop value: Float32 {
        get() {
            valueValue
        }
    }

    public func setValue(v: Float32): Unit {
        valueValue = clamp01(v)
        bumpVersion()
        invalidateSelf()
    }

    public func measure(c: Constraints): Size {
        let width = if (c.maxWidth > 1000000.0f32) {
            0.0f32
        } else {
            c.maxWidth
        }
        sizeValue = c.constrain(Size(width, 8.0f32))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        let th = themeOf()
        let barHeight = 8.0f32
        let y = boundsValue.y + (boundsValue.height - barHeight) * 0.5f32
        let track = Rect(boundsValue.x, y, boundsValue.width, barHeight)
        r.fillRoundRect(track, 4.0f32, th.disabledSurface)
        if (valueValue > 0.0f32) {
            r.fillRoundRect(Rect(track.x, track.y, track.width * valueValue, barHeight), 4.0f32, th.primary)
        }
    }
}
