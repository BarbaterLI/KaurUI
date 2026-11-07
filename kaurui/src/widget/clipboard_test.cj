package kaurui.widget

import kaurui.layout.*
import kaurui.ffi.*

class TextFieldSubmitCapture {
    public var value: String = ""
    public var count: Int64 = 0

    public init() {}

    public func capture(v: String): Unit {
        value = v
        count += 1
    }
}

func boundClipboardField(text: String, clip: Clipboard): TextField {
    let ctx = WidgetContext(Theme.light())
    ctx.clipboard = clip
    let field = TextField(text: text)
    field.bind(ctx)
    field.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 30.0f32))
    field
}

func selectRange(field: TextField, start: Int64, end: Int64): Unit {
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    var i: Int64 = 0
    while (i < start) {
        field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
        i += 1
    }
    while (i < end) {
        field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
        i += 1
    }
}

@Test
func textFieldCtrlCCopiesSelectionTest(): Unit {
    let clip = MemoryClipboard()
    let field = boundClipboardField("abcd", clip)

    selectRange(field, 1, 3)
    @Expect(field.selectionStart, 1)
    @Expect(field.selectionEnd, 3)

    field.onEvent(UiEvent.KeyDown(0x43, true, false))
    @Expect(clip.getText() == "bc", true)
    @Expect(field.text == "abcd", true)
    @Expect(field.caret, 3)
}

@Test
func textFieldCtrlCWithoutSelectionKeepsClipboardTest(): Unit {
    let clip = MemoryClipboard()
    clip.setText("keep")
    let field = boundClipboardField("abcd", clip)

    field.onEvent(UiEvent.KeyDown(0x43, true, false))
    @Expect(clip.getText() == "keep", true)
    @Expect(field.text == "abcd", true)
}

@Test
func textFieldCtrlXCutsSelectionTest(): Unit {
    let clip = MemoryClipboard()
    let changes = TextFieldChangeCounter()
    let ctx = WidgetContext(Theme.light())
    ctx.clipboard = clip
    let field = TextField(text: "abcd", onChange: {_ => changes.bump()})
    field.bind(ctx)
    field.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 30.0f32))

    selectRange(field, 1, 3)
    field.onEvent(UiEvent.KeyDown(0x58, true, false))
    @Expect(field.text == "ad", true)
    @Expect(clip.getText() == "bc", true)
    @Expect(field.caret, 1)
    @Expect(field.anchor, 1)
    @Expect(changes.value, 1)
}

@Test
func textFieldCtrlVPastesAtEndTest(): Unit {
    let clip = MemoryClipboard()
    clip.setText("XY")
    let changes = TextFieldChangeCounter()
    let ctx = WidgetContext(Theme.light())
    ctx.clipboard = clip
    let field = TextField(text: "abcd", onChange: {_ => changes.bump()})
    field.bind(ctx)
    field.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 30.0f32))

    field.onEvent(UiEvent.KeyDown(0x56, true, false))
    @Expect(field.text == "abcdXY", true)
    @Expect(field.caret, 6)
    @Expect(field.anchor, 6)
    @Expect(changes.value, 1)
}

@Test
func textFieldCtrlVReplacesSelectionTest(): Unit {
    let clip = MemoryClipboard()
    clip.setText("XY")
    let field = boundClipboardField("abcd", clip)

    selectRange(field, 1, 3)
    field.onEvent(UiEvent.KeyDown(0x56, true, false))
    @Expect(field.text == "aXYd", true)
    @Expect(field.caret, 3)
    @Expect(field.anchor, 3)
}

@Test
func textFieldCtrlVFiltersNonPrintableTest(): Unit {
    let clip = MemoryClipboard()
    clip.setText("\nabc\n")
    let field = boundClipboardField("abcd", clip)
    field.onEvent(UiEvent.KeyDown(0x56, true, false))
    @Expect(field.text == "abcdabc", true)

    let cjk = MemoryClipboard()
    cjk.setText("中文")
    let cjkField = boundClipboardField("abcd", cjk)
    cjkField.onEvent(UiEvent.KeyDown(0x56, true, false))
    @Expect(cjkField.text == "abcd", true)
    @Expect(cjkField.caret, 4)
}

@Test
func textFieldEnterSubmitsCurrentTextTest(): Unit {
    let capture = TextFieldSubmitCapture()
    let changes = TextFieldChangeCounter()
    let field = TextField(text: "abc", onChange: {_ => changes.bump()}, onSubmit: {v => capture.capture(v)})

    field.onEvent(UiEvent.KeyDown(Vk.VK_RETURN, false, false))
    @Expect(capture.value == "abc", true)
    @Expect(capture.count, 1)
    @Expect(field.text == "abc", true)
    @Expect(changes.value, 0)
}

@Test
func textFieldCtrlLetterDoesNotInsertTest(): Unit {
    let changes = TextFieldChangeCounter()
    let field = TextField(text: "abc", onChange: {_ => changes.bump()})

    field.onEvent(UiEvent.KeyDown(0x42, true, false))
    field.onEvent(UiEvent.Char(0x42))
    @Expect(field.text == "abc", true)
    @Expect(field.caret, 3)
    @Expect(changes.value, 0)
}
