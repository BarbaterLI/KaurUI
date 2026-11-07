package kaurui.widget

import kaurui.layout.*

class LayoutCachePaintCounter {
    public var value: Int64 = 0

    public func bump(): Unit {
        value += 1
    }
}

@Test
func panelRepeatedMeasureHitsCacheTest(): Unit {
    LayoutStats.reset()
    let a = SizedBox(width: 40.0f32, height: 20.0f32)
    let b = SizedBox(width: 40.0f32, height: 20.0f32)
    let panel = Panel([a, b], axis: MainAxis.Horizontal, spacing: 4.0f32)
    let c = Constraints.loose(200.0f32, 100.0f32)

    let first = panel.measure(c)
    @Expect(widgetApprox(first.width, 84.0f32, 0.5f32), true)

    panel.measure(c)
    panel.measure(c)
    panel.measure(c)
    panel.measure(c)

    @Expect(LayoutStats.measureCalls, 1)
    @Expect(LayoutStats.cacheHits, 4)
}

@Test
func labelTextChangeRemasuresOnlyItsBranchTest(): Unit {
    LayoutStats.reset()
    let label = Label("A")
    let left = Panel([label])
    let right = Panel([SizedBox(width: 30.0f32, height: 10.0f32)])
    let root = Panel([left, right], spacing: 0.0f32)
    let c = Constraints.loose(300.0f32, 200.0f32)

    root.measure(c)
    // root + left + right all miss on the first pass.
    @Expect(LayoutStats.measureCalls, 3)
    @Expect(LayoutStats.cacheHits, 0)

    let callsBefore = LayoutStats.measureCalls
    label.setText("A much longer caption")
    root.measure(c)

    // root and the changed left branch re-measure; the untouched right branch hits.
    @Expect(LayoutStats.measureCalls - callsBefore, 2)
    @Expect(LayoutStats.cacheHits, 1)
}

@Test
func constraintChangeRemasuresTest(): Unit {
    LayoutStats.reset()
    let panel = Panel(
        [SizedBox(width: 40.0f32, height: 20.0f32), SizedBox(width: 40.0f32, height: 20.0f32)],
        axis: MainAxis.Horizontal,
        spacing: 4.0f32
    )
    panel.measure(Constraints.loose(100.0f32, 100.0f32))
    @Expect(LayoutStats.measureCalls, 1)
    @Expect(LayoutStats.cacheHits, 0)

    panel.measure(Constraints.loose(300.0f32, 100.0f32))
    @Expect(LayoutStats.measureCalls, 2)
    @Expect(LayoutStats.cacheHits, 0)
}

@Test
func paintOnlyInvalidationKeepsCacheTest(): Unit {
    LayoutStats.reset()
    let paint = LayoutCachePaintCounter()
    let ctx = WidgetContext(Theme.light())
    ctx.paintInvalidateHandler = {_ => paint.bump()}

    let button = Button("OK")
    button.bind(ctx)
    let panel = Panel([button])
    let c = Constraints.loose(200.0f32, 100.0f32)
    panel.measure(c)

    button.onEvent(UiEvent.MouseEnter)
    @Expect(paint.value, 1)
    panel.measure(c)

    button.onEvent(UiEvent.MouseLeave)
    @Expect(paint.value, 2)
    panel.measure(c)

    @Expect(LayoutStats.measureCalls, 1)
    @Expect(LayoutStats.cacheHits, 2)
}

@Test
func panelAddChildInvalidatesCacheTest(): Unit {
    LayoutStats.reset()
    let panel = Panel([SizedBox(width: 40.0f32, height: 20.0f32)])
    let c = Constraints.loose(200.0f32, 100.0f32)
    panel.measure(c)
    @Expect(LayoutStats.measureCalls, 1)

    panel.add(SizedBox(width: 40.0f32, height: 20.0f32))
    panel.measure(c)
    @Expect(LayoutStats.measureCalls, 2)
    @Expect(LayoutStats.cacheHits, 0)
}

@Test
func wrapPanelCacheAndSpacingChangeTest(): Unit {
    LayoutStats.reset()
    let a = SizedBox(width: 60.0f32, height: 20.0f32)
    let b = SizedBox(width: 60.0f32, height: 20.0f32)
    let d = SizedBox(width: 60.0f32, height: 20.0f32)
    let wrap = WrapPanel([a, b, d], horizontalSpacing: 10.0f32, verticalSpacing: 6.0f32)
    let c = Constraints.loose(150.0f32, 1000.0f32)

    let first = wrap.measure(c)
    @Expect(widgetApprox(first.height, 46.0f32, 0.5f32), true)
    wrap.measure(c)
    @Expect(LayoutStats.measureCalls, 1)
    @Expect(LayoutStats.cacheHits, 1)

    wrap.setSpacing(10.0f32, 16.0f32)
    let after = wrap.measure(c)
    @Expect(LayoutStats.measureCalls, 2)
    @Expect(LayoutStats.cacheHits, 1)
    @Expect(widgetApprox(after.height, 56.0f32, 0.5f32), true)
}

@Test
func layoutStatsResetClearsCountersTest(): Unit {
    LayoutStats.reset()
    let panel = Panel([SizedBox(width: 40.0f32, height: 20.0f32)])
    panel.measure(Constraints.loose(200.0f32, 100.0f32))
    @Expect(LayoutStats.measureCalls, 1)

    LayoutStats.reset()
    @Expect(LayoutStats.measureCalls, 0)
    @Expect(LayoutStats.cacheHits, 0)

    panel.measure(Constraints.loose(200.0f32, 100.0f32))
    @Expect(LayoutStats.cacheHits, 1)
}

@Test
func cachedSizeMatchesFirstMeasureTest(): Unit {
    LayoutStats.reset()
    let panel = Panel(
        [Label("cache exact size"), SizedBox(width: 12.0f32, height: 12.0f32)],
        axis: MainAxis.Horizontal,
        spacing: 3.0f32,
        padding: Insets.all(1.5f32)
    )
    let c = Constraints.loose(500.0f32, 200.0f32)
    let first = panel.measure(c)
    let second = panel.measure(c)

    @Expect(first.width == second.width, true)
    @Expect(first.height == second.height, true)
    @Expect(LayoutStats.cacheHits, 1)
}
