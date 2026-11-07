package kaurui.widget

import kaurui.layout.*

@Test
func scrollViewOffsetClampTest(): Unit {
    let content = SizedBox(width: 100.0f32, height: 300.0f32)
    let view = ScrollView(content)
    view.measure(Constraints.loose(100.0f32, 100.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 100.0f32))

    view.scrollBy(50.0f32)
    @Expect(widgetApprox(view.offset, 50.0f32, 0.1f32), true)
    view.scrollBy(500.0f32)
    @Expect(widgetApprox(view.offset, 200.0f32, 0.1f32), true)
    view.scrollBy(-500.0f32)
    @Expect(widgetApprox(view.offset, 0.0f32, 0.1f32), true)
}

@Test
func scrollViewWheelTest(): Unit {
    let content = SizedBox(width: 100.0f32, height: 300.0f32)
    let view = ScrollView(content)
    view.measure(Constraints.loose(100.0f32, 100.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 100.0f32))
    view.setOffset(100.0f32)

    view.onEvent(UiEvent.Wheel(1.0f32, 10.0f32, 10.0f32))
    @Expect(widgetApprox(view.offset, 60.0f32, 0.1f32), true)
    view.onEvent(UiEvent.Wheel(-1.0f32, 10.0f32, 10.0f32))
    @Expect(widgetApprox(view.offset, 100.0f32, 0.1f32), true)
}

@Test
func labelWrapMeasureTest(): Unit {
    let text = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    let label = Label(text, wrap: true)
    let size = label.measure(Constraints.loose(100.0f32, 1000.0f32))
    let singleLineHeight = 14.0f32 * 1.4f32
    @Expect(size.height > singleLineHeight, true)
    @Expect(size.width <= 100.0f32, true)
}

@Test
func labelWrapExplicitNewlinesTest(): Unit {
    let label = Label("a\nb\nc", wrap: true)
    let size = label.measure(Constraints.loose(200.0f32, 1000.0f32))
    @Expect(widgetApprox(size.height, 3.0f32 * 14.0f32 * 1.4f32, 0.5f32), true)
}
