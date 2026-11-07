package kaurui.widget

import std.collection.*
import kaurui.layout.*

func sizedBoxApprox(actual: Float32, expected: Float32, tolerance: Float32): Bool {
    let diff = actual - expected
    diff <= tolerance && diff >= -tolerance
}

func buildScrollContent(): Panel {
    let rows = ArrayList<Widget>()
    for (i in 0..20) {
        rows.add(SizedBox(width: 300.0f32, height: 35.0f32))
    }
    Panel(rows.toArray(), axis: MainAxis.Vertical, spacing: 6.0f32)
}

@Test
func sizedBoxFixedHeightClampsScrollViewportTest(): Unit {
    let content = buildScrollContent()
    let view = ScrollView(content, background: Some(Theme.light().surface))
    let box = SizedBox(width: 300.0f32, height: 160.0f32, child: view)

    let ctx = WidgetContext(Theme.light())
    box.bind(ctx)
    box.measure(Constraints.loose(800.0f32, 600.0f32))
    box.arrange(Rect(0.0f32, 0.0f32, 800.0f32, 600.0f32))

    @Expect(sizedBoxApprox(view.bounds.height, 160.0f32, 0.5f32), true)
    @Expect(sizedBoxApprox(view.size.height, 160.0f32, 0.5f32), true)
    // Scrolling can travel the whole content minus the 160px viewport.
    view.scrollBy(1000.0f32)
    @Expect(sizedBoxApprox(view.offset, 20.0f32 * 35.0f32 + 19.0f32 * 6.0f32 - 160.0f32, 0.5f32), true)
}

@Test
func sizedBoxSiblingFollowsFixedHeightTest(): Unit {
    let content = buildScrollContent()
    let view = ScrollView(content)
    let box = SizedBox(width: 300.0f32, height: 160.0f32, child: view)
    let paragraph = Label("段落首行", fontSize: 13.0f32, wrap: true)
    let panel = Panel([box, paragraph], axis: MainAxis.Vertical, spacing: 6.0f32)

    let ctx = WidgetContext(Theme.light())
    panel.bind(ctx)
    panel.measure(Constraints.loose(800.0f32, 600.0f32))
    panel.arrange(Rect(0.0f32, 0.0f32, 800.0f32, 600.0f32))

    @Expect(sizedBoxApprox(view.bounds.height, 160.0f32, 0.5f32), true)
    @Expect(paragraph.bounds.y >= 160.0f32 - 0.5f32, true)
}

@Test
func sizedBoxFixedWidthConstrainsChildTest(): Unit {
    let inner = SizedBox(height: 40.0f32)
    let box = SizedBox(width: 300.0f32, child: inner)

    box.measure(Constraints.loose(800.0f32, 600.0f32))
    box.arrange(Rect(0.0f32, 0.0f32, 800.0f32, 600.0f32))

    @Expect(sizedBoxApprox(inner.size.width, 300.0f32, 0.5f32), true)
    @Expect(sizedBoxApprox(inner.bounds.width, 300.0f32, 0.5f32), true)
}
