package kaurui.widget

import kaurui.layout.*

class CallCounter {
    public var value: Int64 = 0

    public func bump(): Unit {
        value += 1
    }
}

class BoolHolder {
    public var value: Bool = false
}

func widgetApprox(actual: Float32, expected: Float32, tolerance: Float32): Bool {
    let diff = actual - expected
    diff <= tolerance && diff >= -tolerance
}

@Test
func panelColumnFixedHeightTest(): Unit {
    let panel = Panel([SizedBox(height: 40.0f32), SizedBox(height: 40.0f32), SizedBox(height: 40.0f32)], spacing: 8.0f32)
    let size = panel.measure(Constraints.unbounded())
    @Expect(widgetApprox(size.height, 136.0f32, 0.5f32), true)
}

@Test
func panelRowFlexDistributionTest(): Unit {
    let left = SizedBox(flex: 1.0f32)
    let right = SizedBox(flex: 2.0f32)
    let panel = Panel([left, right], axis: MainAxis.Horizontal, spacing: 0.0f32)
    panel.measure(Constraints.tight(300.0f32, 10.0f32))
    panel.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 10.0f32))
    @Expect(widgetApprox(left.bounds.width, 100.0f32, 1.0f32), true)
    @Expect(widgetApprox(right.bounds.width, 200.0f32, 1.0f32), true)
}

@Test
func panelHitTestTopmostTest(): Unit {
    let bottom = SizedBox(width: 100.0f32, height: 100.0f32)
    let top = SizedBox(width: 50.0f32, height: 50.0f32)
    let panel = Panel([bottom, top], spacing: 0.0f32)
    panel.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 200.0f32))
    bottom.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 100.0f32))
    top.arrange(Rect(0.0f32, 0.0f32, 50.0f32, 50.0f32))

    let topHit = panel.hitTest(Point(10.0f32, 10.0f32))
    @Expect(topHit.isSome(), true)
    if (let Some(w) <- topHit) {
        @Expect(widgetApprox(w.bounds.width, 50.0f32, 1.0f32), true)
    }
    let bottomHit = panel.hitTest(Point(60.0f32, 60.0f32))
    @Expect(bottomHit.isSome(), true)
    if (let Some(w) <- bottomHit) {
        @Expect(widgetApprox(w.bounds.width, 100.0f32, 1.0f32), true)
    }
}

@Test
func buttonClickStateMachineTest(): Unit {
    let clicks = CallCounter()
    let button = Button("OK", onClick: {=> clicks.bump()})
    button.arrange(Rect(0.0f32, 0.0f32, 100.0f32, 30.0f32))

    button.onEvent(UiEvent.MouseDown(5.0f32, 5.0f32))
    button.onEvent(UiEvent.MouseUp(5.0f32, 5.0f32))
    @Expect(clicks.value, 1)

    button.onEvent(UiEvent.MouseDown(5.0f32, 5.0f32))
    button.onEvent(UiEvent.MouseLeave)
    button.onEvent(UiEvent.MouseUp(5.0f32, 5.0f32))
    @Expect(clicks.value, 1)
}

@Test
func textFieldInputTest(): Unit {
    let changes = CallCounter()
    let field = TextField(onChange: {_ => changes.bump()})
    field.onEvent(UiEvent.Char(0x61))
    field.onEvent(UiEvent.Char(0x62))
    field.onEvent(UiEvent.KeyDown(UInt32(8), false, false))
    @Expect(field.text == "a", true)
    @Expect(changes.value, 3)
}

@Test
func checkBoxToggleTest(): Unit {
    let received = BoolHolder()
    let box = CheckBox("Enable", onChange: {v => received.value = v})
    box.arrange(Rect(0.0f32, 0.0f32, 120.0f32, 24.0f32))
    box.onEvent(UiEvent.MouseUp(5.0f32, 5.0f32))
    @Expect(box.checked, true)
    @Expect(received.value, true)
}

@Test
func focusOrderDepthFirstTest(): Unit {
    let field = TextField()
    let button = Button("Save")
    let box = CheckBox("Remember")
    let nested = Panel([button, box])
    let root = Panel([field, nested])

    let order = root.focusOrder()
    @Expect(order.size, 2)
    @Expect(order[0] is TextField, true)
    @Expect(order[1] is CheckBox, true)
    @Expect(order[0].focusable, true)
    @Expect(order[1].focusable, true)
}

@Test
func progressBarValueClampTest(): Unit {
    let bar = ProgressBar()
    bar.setValue(-1.0f32)
    @Expect(widgetApprox(bar.value, 0.0f32, 0.001f32), true)
    bar.setValue(2.0f32)
    @Expect(widgetApprox(bar.value, 1.0f32, 0.001f32), true)
}
