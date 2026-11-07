package kaurui.widget

import kaurui.layout.*

@Test
func wrapPanelWrapsAtMaxWidthTest(): Unit {
    let a = SizedBox(width: 60.0f32, height: 20.0f32)
    let b = SizedBox(width: 60.0f32, height: 20.0f32)
    let c = SizedBox(width: 60.0f32, height: 20.0f32)
    let panel = WrapPanel([a, b, c], horizontalSpacing: 10.0f32, verticalSpacing: 6.0f32)
    let size = panel.measure(Constraints.loose(150.0f32, 1000.0f32))
    // Row 1: 60 + 10 + 60 = 130, row 2: 60 -> width 130, height 20 + 6 + 20 = 46.
    @Expect(widgetApprox(size.width, 130.0f32, 0.5f32), true)
    @Expect(widgetApprox(size.height, 46.0f32, 0.5f32), true)

    panel.arrange(Rect(0.0f32, 0.0f32, 150.0f32, 46.0f32))
    @Expect(widgetApprox(a.bounds.x, 0.0f32, 0.5f32), true)
    @Expect(widgetApprox(a.bounds.y, 0.0f32, 0.5f32), true)
    @Expect(widgetApprox(b.bounds.x, 70.0f32, 0.5f32), true)
    @Expect(widgetApprox(b.bounds.y, 0.0f32, 0.5f32), true)
    @Expect(widgetApprox(c.bounds.x, 0.0f32, 0.5f32), true)
    @Expect(widgetApprox(c.bounds.y, 26.0f32, 0.5f32), true)
}

@Test
func wrapPanelSingleRowWhenWideTest(): Unit {
    let a = SizedBox(width: 60.0f32, height: 20.0f32)
    let b = SizedBox(width: 60.0f32, height: 20.0f32)
    let c = SizedBox(width: 60.0f32, height: 20.0f32)
    let panel = WrapPanel([a, b, c], horizontalSpacing: 10.0f32, verticalSpacing: 6.0f32)
    let size = panel.measure(Constraints.loose(1000.0f32, 1000.0f32))
    // 3 * 60 + 2 * 10 = 200 on a single row.
    @Expect(widgetApprox(size.width, 200.0f32, 0.5f32), true)
    @Expect(widgetApprox(size.height, 20.0f32, 0.5f32), true)

    panel.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 20.0f32))
    @Expect(widgetApprox(a.bounds.x, 0.0f32, 0.5f32), true)
    @Expect(widgetApprox(b.bounds.x, 70.0f32, 0.5f32), true)
    @Expect(widgetApprox(c.bounds.x, 140.0f32, 0.5f32), true)
    @Expect(widgetApprox(c.bounds.y, 0.0f32, 0.5f32), true)
}

@Test
func wrapPanelHitTestAcrossRowsTest(): Unit {
    let a = SizedBox(width: 60.0f32, height: 20.0f32)
    let b = SizedBox(width: 60.0f32, height: 20.0f32)
    let c = SizedBox(width: 60.0f32, height: 20.0f32)
    let panel = WrapPanel([a, b, c], horizontalSpacing: 10.0f32, verticalSpacing: 6.0f32)
    panel.measure(Constraints.loose(150.0f32, 1000.0f32))
    panel.arrange(Rect(0.0f32, 0.0f32, 150.0f32, 46.0f32))

    let hit = panel.hitTest(Point(10.0f32, 36.0f32))
    @Expect(hit.isSome(), true)
    if (let Some(w) <- hit) {
        @Expect(widgetApprox(w.bounds.x, 0.0f32, 0.5f32), true)
        @Expect(widgetApprox(w.bounds.y, 26.0f32, 0.5f32), true)
        @Expect(widgetApprox(w.bounds.width, 60.0f32, 0.5f32), true)
    }
}

@Test
func wrapPanelIgnoresFlexForWrappingTest(): Unit {
    let a = SizedBox(width: 60.0f32, height: 20.0f32, flex: 1.0f32)
    let b = SizedBox(width: 60.0f32, height: 20.0f32, flex: 1.0f32)
    let c = SizedBox(width: 60.0f32, height: 20.0f32, flex: 1.0f32)
    let panel = WrapPanel([a, b, c], horizontalSpacing: 10.0f32, verticalSpacing: 6.0f32)
    let size = panel.measure(Constraints.loose(150.0f32, 1000.0f32))
    @Expect(widgetApprox(size.width, 130.0f32, 0.5f32), true)
    @Expect(widgetApprox(size.height, 46.0f32, 0.5f32), true)

    panel.arrange(Rect(0.0f32, 0.0f32, 150.0f32, 46.0f32))
    @Expect(widgetApprox(c.bounds.y, 26.0f32, 0.5f32), true)
    @Expect(widgetApprox(a.bounds.width, 60.0f32, 0.5f32), true)
    @Expect(widgetApprox(b.bounds.width, 60.0f32, 0.5f32), true)
}
