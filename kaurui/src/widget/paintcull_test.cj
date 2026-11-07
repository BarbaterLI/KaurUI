package kaurui.widget

import std.collection.*
import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// CullRenderer: a Renderer with an explicitly settable clip rectangle.
// ---------------------------------------------------------------------------

class CullRenderer <: Renderer {
    public var clipValue: Option<Rect> = None
    public var fillRectCalls: Int64 = 0
    private var drawCallCount: Int64 = 0

    public func beginFrame(width: Float32, height: Float32): Unit {}

    public func fillRect(rect: Rect, color: Color): Unit {
        fillRectCalls += 1
    }

    public func fillRoundRect(rect: Rect, radius: Float32, color: Color): Unit {
        drawCallCount += 1
    }

    public func strokeRect(rect: Rect, color: Color, width: Float32): Unit {
        drawCallCount += 1
    }

    public func strokeRoundRect(rect: Rect, radius: Float32, color: Color, width: Float32): Unit {
        drawCallCount += 1
    }

    public func drawText(text: String, rect: Rect, style: TextStyle, color: Color, align: TextAlign): Unit {
        drawCallCount += 1
    }

    public func measureText(text: String, style: TextStyle): Size {
        Size(0.0f32, 0.0f32)
    }

    public func pushClip(rect: Rect): Unit {}

    public func popClip(): Unit {}

    public func endFrame(): Unit {}

    public func loadImage(path: String): Option<ImageHandle> {
        None
    }

    public func drawImage(image: ImageHandle, dst: Rect): Unit {}

    public prop imageCacheSize: Int64 {
        get() {
            0
        }
    }

    public prop drawCalls: Int64 {
        get() {
            drawCallCount
        }
    }

    public prop lastPaintedArea: Size {
        get() {
            Size.ZERO
        }
    }

    public prop currentClip: Option<Rect> {
        get() {
            clipValue
        }
    }
}

// ---------------------------------------------------------------------------
// PaintProbe: counts how many times its paint() is reached.
// ---------------------------------------------------------------------------

class PaintProbe <: WidgetBase {
    public var paintCalls: Int64 = 0
    private let widthValue: Float32
    private let heightValue: Float32

    public init(width: Float32, height: Float32) {
        super(0.0f32)
        widthValue = width
        heightValue = height
    }

    public func measure(c: Constraints): Size {
        sizeValue = c.constrain(Size(widthValue, heightValue))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        paintCalls += 1
    }
}

func cullProbes(count: Int64, width: Float32, height: Float32): Array<PaintProbe> {
    let out = ArrayList<PaintProbe>()
    for (i in 0..count) {
        out.add(PaintProbe(width, height))
    }
    out.toArray()
}

func cullBoxes(probes: Array<PaintProbe>, width: Float32, height: Float32): Array<Widget> {
    let out = ArrayList<Widget>()
    for (p in probes) {
        out.add(SizedBox(width: width, height: height, child: p))
    }
    out.toArray()
}

// Vertical panel with 100px gaps: children occupy y = 0, 140, 280, 420, 560.
func cullPanelFixture(probes: Array<PaintProbe>): Panel {
    let panel = Panel(cullBoxes(probes, 40.0f32, 40.0f32), axis: MainAxis.Vertical, spacing: 100.0f32)
    panel.measure(Constraints.loose(200.0f32, 700.0f32))
    panel.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 700.0f32))
    panel
}

func cullWrapFixture(probes: Array<PaintProbe>): WrapPanel {
    let panel = WrapPanel(
        cullBoxes(probes, 60.0f32, 20.0f32),
        horizontalSpacing: 10.0f32,
        verticalSpacing: 6.0f32
    )
    panel.measure(Constraints.loose(200.0f32, 1000.0f32))
    panel.arrange(Rect(0.0f32, 0.0f32, 200.0f32, 60.0f32))
    panel
}

func cullPaintCounts(probes: Array<PaintProbe>): Array<Int64> {
    let out = ArrayList<Int64>()
    for (p in probes) {
        out.add(p.paintCalls)
    }
    out.toArray()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@Test
func paintCullPanelSkipsOutsideClipTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()
    r.clipValue = Some(panel.children[2].bounds)

    panel.paint(r)

    @Expect(cullPaintCounts(probes), [0, 0, 1, 0, 0])
    @Expect(LayoutStats.paintSkips, 4)
}

@Test
func paintCullPanelNoClipPaintsAllTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()

    panel.paint(r)

    @Expect(cullPaintCounts(probes), [1, 1, 1, 1, 1])
    @Expect(LayoutStats.paintSkips, 0)
}

@Test
func paintCullWrapPanelSkipsAcrossRowsTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 60.0f32, 20.0f32)
    let panel = cullWrapFixture(probes)
    let r = CullRenderer()
    r.clipValue = Some(panel.children[3].bounds)

    panel.paint(r)

    @Expect(cullPaintCounts(probes), [0, 0, 0, 1, 0])
    @Expect(LayoutStats.paintSkips, 4)
}

@Test
func paintCullPartialIntersectionStillPaintsTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()
    // Covers children 0-2 fully and only the top half of child 2's 40px box.
    r.clipValue = Some(Rect(0.0f32, 0.0f32, 200.0f32, 300.0f32))

    panel.paint(r)

    // Child 2 is only partially visible but must still be painted.
    @Expect(cullPaintCounts(probes), [1, 1, 1, 0, 0])
    @Expect(LayoutStats.paintSkips, 2)
}

@Test
func paintCullStatsResetClearsSkipsTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()
    r.clipValue = Some(panel.children[2].bounds)
    panel.paint(r)
    @Expect(LayoutStats.paintSkips, 4)

    LayoutStats.reset()
    @Expect(LayoutStats.paintSkips, 0)
    @Expect(LayoutStats.measureCalls, 0)
    @Expect(LayoutStats.cacheHits, 0)
}

@Test
func paintCullClipCoversAllChildrenTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()
    r.clipValue = Some(Rect(0.0f32, 0.0f32, 200.0f32, 700.0f32))

    panel.paint(r)

    @Expect(cullPaintCounts(probes), [1, 1, 1, 1, 1])
    @Expect(LayoutStats.paintSkips, 0)
}

@Test
func paintCullWrapPanelNoClipPaintsAllTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 60.0f32, 20.0f32)
    let panel = cullWrapFixture(probes)
    let r = CullRenderer()

    panel.paint(r)

    @Expect(cullPaintCounts(probes), [1, 1, 1, 1, 1])
    @Expect(LayoutStats.paintSkips, 0)
}

@Test
func paintCullClipOutsideAllSkipsAllTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()
    r.clipValue = Some(Rect(0.0f32, 900.0f32, 200.0f32, 50.0f32))

    panel.paint(r)

    @Expect(cullPaintCounts(probes), [0, 0, 0, 0, 0])
    @Expect(LayoutStats.paintSkips, 5)
}

@Test
func paintCullClipCoversTwoChildrenTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()
    // Spans child 1 (y 140..180) and child 2 (y 280..320) only.
    r.clipValue = Some(Rect(0.0f32, 140.0f32, 200.0f32, 180.0f32))

    panel.paint(r)

    @Expect(cullPaintCounts(probes), [0, 1, 1, 0, 0])
    @Expect(LayoutStats.paintSkips, 3)
}

@Test
func paintCullSkipsAccumulateAcrossPaintCallsTest(): Unit {
    LayoutStats.reset()
    let probes = cullProbes(5, 40.0f32, 40.0f32)
    let panel = cullPanelFixture(probes)
    let r = CullRenderer()
    r.clipValue = Some(panel.children[2].bounds)

    panel.paint(r)
    panel.paint(r)

    @Expect(probes[2].paintCalls, 2)
    @Expect(LayoutStats.paintSkips, 8)
}
