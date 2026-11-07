package kaurui.widget

import kaurui.layout.*

class InvalidateCounter {
    public var value: Int64 = 0

    public func bump(): Unit {
        value += 1
    }
}

@Test
func buttonHoverInvalidatesPaintOnlyTest(): Unit {
    let layout = InvalidateCounter()
    let paint = InvalidateCounter()
    let ctx = WidgetContext(Theme.light())
    ctx.invalidateHandler = {_ => layout.bump()}
    ctx.paintInvalidateHandler = {_ => paint.bump()}

    let button = Button("OK")
    button.bind(ctx)
    button.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 30.0f32))

    button.onEvent(UiEvent.MouseEnter)
    @Expect(paint.value, 1)
    @Expect(layout.value, 0)

    button.onEvent(UiEvent.MouseLeave)
    @Expect(paint.value, 2)
    @Expect(layout.value, 0)

    button.onEvent(UiEvent.MouseDown(5.0f32, 5.0f32))
    @Expect(paint.value, 3)
    @Expect(layout.value, 0)

    button.onEvent(UiEvent.MouseUp(5.0f32, 5.0f32))
    @Expect(paint.value, 4)
    @Expect(layout.value, 0)

    // Disabling can change size-affecting state, so it stays layout-level.
    button.setEnabled(false)
    @Expect(layout.value, 1)
    @Expect(paint.value, 4)
}

@Test
func scrollByInvalidatesPaintOnlyTest(): Unit {
    let layout = InvalidateCounter()
    let paint = InvalidateCounter()
    let ctx = WidgetContext(Theme.light())
    ctx.invalidateHandler = {_ => layout.bump()}
    ctx.paintInvalidateHandler = {_ => paint.bump()}

    let content = SizedBox(width: 100.0f32, height: 300.0f32)
    let view = ScrollView(content)
    view.bind(ctx)
    view.measure(Constraints.loose(100.0f32, 100.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 100.0f32))

    view.scrollBy(50.0f32)
    @Expect(paint.value, 1)
    @Expect(layout.value, 0)

    view.setOffset(120.0f32)
    @Expect(paint.value, 2)
    @Expect(layout.value, 0)

    // Clamping to the current offset is a no-op and must not invalidate at all.
    view.setOffset(120.0f32)
    @Expect(paint.value, 2)
    @Expect(layout.value, 0)
}
