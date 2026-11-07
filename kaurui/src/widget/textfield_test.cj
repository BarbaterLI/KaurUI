package kaurui.widget

import kaurui.layout.*
import kaurui.ffi.*

class TextFieldChangeCounter {
    public var value: Int64 = 0

    public func bump(): Unit {
        value += 1
    }
}

@Test
func textFieldTypingAdvancesCaretTest(): Unit {
    let changes = TextFieldChangeCounter()
    let field = TextField(onChange: {_ => changes.bump()})

    field.onEvent(UiEvent.Char(0x61))
    field.onEvent(UiEvent.Char(0x62))
    field.onEvent(UiEvent.Char(0x63))

    @Expect(field.text == "abc", true)
    @Expect(field.caret, 3)
    @Expect(changes.value, 3)
}

@Test
func textFieldHomeInsertTest(): Unit {
    let field = TextField(text: "abc")

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    @Expect(field.caret, 0)

    field.onEvent(UiEvent.Char(0x58))
    @Expect(field.text == "Xabc", true)
    @Expect(field.caret, 1)
}

@Test
func textFieldEndKeyTest(): Unit {
    let field = TextField(text: "abc")

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_END, false, false))
    @Expect(field.caret, 3)
}

@Test
func textFieldLeftMoveClampTest(): Unit {
    let field = TextField(text: "abc")

    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, false, false))
    @Expect(field.caret, 1)

    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, false, false))
    @Expect(field.caret, 0)

    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, false, false))
    @Expect(field.caret, 0)
}

@Test
func textFieldRightMoveClampTest(): Unit {
    let field = TextField(text: "abc")

    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    @Expect(field.caret, 3)

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    @Expect(field.caret, 3)
}

@Test
func textFieldBackspaceMiddleTest(): Unit {
    let field = TextField(text: "abc")

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    @Expect(field.caret, 2)

    field.onEvent(UiEvent.KeyDown(Vk.VK_BACK, false, false))
    @Expect(field.text == "ac", true)
    @Expect(field.caret, 1)
}

@Test
func textFieldDeleteMiddleTest(): Unit {
    let field = TextField(text: "abc")

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    @Expect(field.caret, 1)

    field.onEvent(UiEvent.KeyDown(Vk.VK_DELETE, false, false))
    @Expect(field.text == "ac", true)
    @Expect(field.caret, 1)
}

@Test
func textFieldSetTextAndEmptyEditTest(): Unit {
    let changes = TextFieldChangeCounter()
    let field = TextField(onChange: {_ => changes.bump()})

    field.setText("hello")
    @Expect(field.text == "hello", true)
    @Expect(field.caret, 5)

    let emptyChanges = TextFieldChangeCounter()
    let empty = TextField(onChange: {_ => emptyChanges.bump()})
    empty.onEvent(UiEvent.KeyDown(Vk.VK_BACK, false, false))
    empty.onEvent(UiEvent.KeyDown(Vk.VK_DELETE, false, false))
    @Expect(empty.text.isEmpty(), true)
    @Expect(empty.caret, 0)
    @Expect(emptyChanges.value, 0)
}

@Test
func textFieldMoveDoesNotFireOnChangeTest(): Unit {
    let changes = TextFieldChangeCounter()
    let layout = TextFieldChangeCounter()
    let paint = TextFieldChangeCounter()
    let ctx = WidgetContext(Theme.light())
    ctx.invalidateHandler = {_ => layout.bump()}
    ctx.paintInvalidateHandler = {_ => paint.bump()}

    let field = TextField(text: "abc", onChange: {_ => changes.bump()})
    field.bind(ctx)
    field.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 30.0f32))

    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_END, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    @Expect(changes.value, 0)
    @Expect(layout.value, 0)
    @Expect(paint.value, 3)

    field.onEvent(UiEvent.Char(0x21))
    @Expect(changes.value, 1)
    @Expect(layout.value, 1)
}

// ---------------------------------------------------------------------------
// Selection (anchor / selection endpoints)
// ---------------------------------------------------------------------------

@Test
func textFieldShiftRightSelectionTest(): Unit {
    let field = TextField(text: "abc")
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))

    @Expect(field.selectionStart, 1)
    @Expect(field.selectionEnd, 3)
    @Expect(field.anchor, 1)
    @Expect(field.caret, 3)
}

@Test
func textFieldShiftHomeEndSelectionTest(): Unit {
    let field = TextField(text: "abcdef")
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    @Expect(field.caret, 4)

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, true, true))
    @Expect(field.selectionStart, 0)
    @Expect(field.selectionEnd, 4)
    @Expect(field.anchor, 4)

    field.onEvent(UiEvent.KeyDown(Vk.VK_END, true, true))
    @Expect(field.selectionStart, 4)
    @Expect(field.selectionEnd, 6)
}

@Test
func textFieldPlainLeftCollapsesSelectionTest(): Unit {
    let field = TextField(text: "abc")
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    @Expect(field.selectionStart, 0)
    @Expect(field.selectionEnd, 2)

    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, false, false))
    @Expect(field.caret, 0)
    @Expect(field.anchor, 0)
}

@Test
func textFieldPlainRightCollapsesSelectionTest(): Unit {
    let field = TextField(text: "abc")
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))

    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    @Expect(field.caret, 2)
    @Expect(field.anchor, 2)
    @Expect(field.selectionStart, 2)
    @Expect(field.selectionEnd, 2)
}

@Test
func textFieldCtrlASelectAllTest(): Unit {
    let field = TextField(text: "abc")
    @Expect(field.caret, 3)

    field.onEvent(UiEvent.KeyDown(0x41, true, false))
    @Expect(field.anchor, 0)
    @Expect(field.caret, 3)
    @Expect(field.selectionStart, 0)
    @Expect(field.selectionEnd, 3)
}

@Test
func textFieldTypingReplacesSelectionTest(): Unit {
    let changes = TextFieldChangeCounter()
    let field = TextField(text: "abc", onChange: {_ => changes.bump()})
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    @Expect(field.selectionStart, 0)
    @Expect(field.selectionEnd, 2)

    field.onEvent(UiEvent.Char(0x58))
    @Expect(field.text == "Xc", true)
    @Expect(field.caret, 1)
    @Expect(field.anchor, 1)
    @Expect(changes.value, 1)
}

@Test
func textFieldBackspaceDeletesSelectionTest(): Unit {
    let changes = TextFieldChangeCounter()
    let field = TextField(text: "abc", onChange: {_ => changes.bump()})
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))

    field.onEvent(UiEvent.KeyDown(Vk.VK_BACK, false, false))
    @Expect(field.text == "c", true)
    @Expect(field.caret, 0)
    @Expect(field.anchor, 0)
    @Expect(changes.value, 1)
}

@Test
func textFieldDeleteForwardDeletesSelectionTest(): Unit {
    let changes = TextFieldChangeCounter()
    let field = TextField(text: "abcd", onChange: {_ => changes.bump()})
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    field.onEvent(UiEvent.KeyDown(Vk.VK_RIGHT, true, true))
    @Expect(field.selectionStart, 1)
    @Expect(field.selectionEnd, 3)

    field.onEvent(UiEvent.KeyDown(Vk.VK_DELETE, false, false))
    @Expect(field.text == "ad", true)
    @Expect(field.caret, 1)
    @Expect(field.anchor, 1)
    @Expect(changes.value, 1)
}

@Test
func textFieldSelectionMovesDoNotFireOnChangeTest(): Unit {
    let changes = TextFieldChangeCounter()
    let layout = TextFieldChangeCounter()
    let paint = TextFieldChangeCounter()
    let ctx = WidgetContext(Theme.light())
    ctx.invalidateHandler = {_ => layout.bump()}
    ctx.paintInvalidateHandler = {_ => paint.bump()}

    let field = TextField(text: "abc", onChange: {_ => changes.bump()})
    field.bind(ctx)
    field.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 30.0f32))

    field.onEvent(UiEvent.KeyDown(0x41, true, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, true, true))
    field.onEvent(UiEvent.KeyDown(Vk.VK_LEFT, false, false))
    @Expect(changes.value, 0)
    @Expect(layout.value, 0)
    @Expect(paint.value, 3)
}

// ---------------------------------------------------------------------------
// Horizontal scrolling
// ---------------------------------------------------------------------------

func estimatedTextWidth(text: String): Float32 {
    Float32(text.size) * 14.0f32 * 0.6f32
}

@Test
func textFieldEndScrollsToCaretTest(): Unit {
    let text = "abcdefghijklmnopqrstuvwxyz0123456789ABCD"
    let field = TextField(text: text)
    field.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 30.0f32))
    field.setFocus(true)

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    @Expect(field.scrollX, 0.0f32)

    field.onEvent(UiEvent.KeyDown(Vk.VK_END, false, false))
    let total = estimatedTextWidth(text)
    @Expect(field.scrollX > 0.0f32, true)
    @Expect(total - field.scrollX <= 84.0f32 + 0.5f32, true)
}

@Test
func textFieldHomeResetsScrollTest(): Unit {
    let text = "abcdefghijklmnopqrstuvwxyz0123456789ABCD"
    let field = TextField(text: text)
    field.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 30.0f32))
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_END, false, false))
    @Expect(field.scrollX > 0.0f32, true)

    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    @Expect(field.scrollX, 0.0f32)
    @Expect(field.caret, 0)
}

@Test
func textFieldScrollClampedToTextExtentTest(): Unit {
    let text = "abcdefghijklmnopqrstuvwxyz0123456789ABCD"
    let field = TextField(text: text)
    field.arrange(Rect(0.0f32, 0.0f32, 60.0f32, 30.0f32))
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_END, false, false))

    let total = estimatedTextWidth(text)
    @Expect(field.scrollX <= total - 44.0f32 + 0.5f32, true)
    @Expect(field.scrollX >= 0.0f32, true)
}

@Test
func textFieldShortTextDoesNotScrollTest(): Unit {
    let field = TextField(text: "abc")
    field.arrange(Rect(0.0f32, 0.0f32, 400.0f32, 30.0f32))
    field.onEvent(UiEvent.KeyDown(Vk.VK_HOME, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_END, false, false))
    @Expect(field.scrollX, 0.0f32)
}

@Test
func textFieldEmptyBackDeleteHasNoSideEffectsTest(): Unit {
    let changes = TextFieldChangeCounter()
    let field = TextField(onChange: {_ => changes.bump()})
    field.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 30.0f32))

    field.onEvent(UiEvent.KeyDown(Vk.VK_BACK, false, false))
    field.onEvent(UiEvent.KeyDown(Vk.VK_DELETE, false, false))

    @Expect(field.text.isEmpty(), true)
    @Expect(field.caret, 0)
    @Expect(field.anchor, 0)
    @Expect(field.scrollX, 0.0f32)
    @Expect(changes.value, 0)
}
