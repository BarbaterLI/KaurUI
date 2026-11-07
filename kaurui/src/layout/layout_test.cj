package kaurui.layout

class DummyItem <: LayoutItem {
    private let naturalWidth: Float32
    private let naturalHeight: Float32
    private let weight: Float32
    private var cachedSize: Size = Size(0.0f32, 0.0f32)
    public var lastRect: Rect = Rect(0.0f32, 0.0f32, 0.0f32, 0.0f32)
    public var measureCount: Int64 = 0

    public init(width: Float32, height: Float32) {
        this.naturalWidth = width
        this.naturalHeight = height
        this.weight = 0.0f32
    }

    public init(width: Float32, height: Float32, flex: Float32) {
        this.naturalWidth = width
        this.naturalHeight = height
        this.weight = flex
    }

    public func measure(c: Constraints): Size {
        measureCount += 1
        cachedSize = c.constrain(Size(naturalWidth, naturalHeight))
        cachedSize
    }

    public func arrange(rect: Rect): Unit {
        lastRect = rect
    }

    public prop size: Size {
        get() {
            cachedSize
        }
    }

    public prop flex: Float32 {
        get() {
            weight
        }
    }
}

func approxEq(actual: Float32, expected: Float32, tolerance: Float32): Bool {
    let diff = actual - expected
    diff <= tolerance && diff >= -tolerance
}

@Test
func columnMeasureFixedItemsTest(): Unit {
    let d1 = DummyItem(100.0f32, 40.0f32)
    let d2 = DummyItem(120.0f32, 40.0f32)
    let d3 = DummyItem(80.0f32, 40.0f32)
    let a: LayoutItem = d1
    let b: LayoutItem = d2
    let c: LayoutItem = d3
    let items = [a, b, c]
    let config = StackConfig(8.0f32, CrossAlign.Start, MainAlign.Start)
    let size = StackLayout.measure(items, Constraints.unbounded(), MainAxis.Vertical, config)
    @Expect(approxEq(size.height, 136.0f32, 0.5f32), true)
    @Expect(approxEq(size.width, 120.0f32, 0.5f32), true)

    StackLayout.arrange(items, Rect(0.0f32, 0.0f32, 120.0f32, 136.0f32), MainAxis.Vertical, config)
    @Expect(approxEq(d1.lastRect.y, 0.0f32, 0.5f32), true)
    @Expect(approxEq(d2.lastRect.y, 48.0f32, 0.5f32), true)
    @Expect(approxEq(d3.lastRect.y, 96.0f32, 0.5f32), true)
}

@Test
func columnArrangeDoesNotMeasureTest(): Unit {
    let d = DummyItem(100.0f32, 40.0f32)
    let a: LayoutItem = d
    let items = [a]
    let config = StackConfig(0.0f32)
    let size = StackLayout.measure(items, Constraints.unbounded(), MainAxis.Vertical, config)
    @Expect(approxEq(size.height, 40.0f32, 0.5f32), true)
    let callsAfterMeasure = d.measureCount
    StackLayout.arrange(items, Rect(0.0f32, 0.0f32, 100.0f32, 40.0f32), MainAxis.Vertical, config)
    @Expect(d.measureCount, callsAfterMeasure)
}

@Test
func rowFlexDistributionTest(): Unit {
    let d1 = DummyItem(0.0f32, 10.0f32, 1.0f32)
    let d2 = DummyItem(0.0f32, 10.0f32, 2.0f32)
    let a: LayoutItem = d1
    let b: LayoutItem = d2
    let items = [a, b]
    let config = StackConfig(0.0f32, CrossAlign.Start, MainAlign.Start)
    let size = StackLayout.measure(items, Constraints.tight(300.0f32, 10.0f32), MainAxis.Horizontal, config)
    @Expect(approxEq(size.width, 300.0f32, 0.5f32), true)
    StackLayout.arrange(items, Rect(0.0f32, 0.0f32, 300.0f32, 10.0f32), MainAxis.Horizontal, config)
    @Expect(approxEq(d1.lastRect.width, 100.0f32, 1.0f32), true)
    @Expect(approxEq(d2.lastRect.width, 200.0f32, 1.0f32), true)
    @Expect(approxEq(d1.lastRect.x, 0.0f32, 1.0f32), true)
    @Expect(approxEq(d2.lastRect.x, 100.0f32, 1.0f32), true)
}

@Test
func constraintsDeflateTest(): Unit {
    let base = Constraints.loose(200.0f32, 200.0f32)
    let inner = base.deflate(Insets.all(10.0f32))
    @Expect(approxEq(inner.minWidth, 0.0f32, 0.01f32), true)
    @Expect(approxEq(inner.maxWidth, 180.0f32, 0.01f32), true)
    @Expect(approxEq(inner.maxHeight, 180.0f32, 0.01f32), true)
    let clamped = inner.constrain(Size(200.0f32, 200.0f32))
    @Expect(approxEq(clamped.width, 180.0f32, 0.01f32), true)
    @Expect(approxEq(clamped.height, 180.0f32, 0.01f32), true)
}

@Test
func crossAlignCenterTest(): Unit {
    let d = DummyItem(100.0f32, 40.0f32)
    let a: LayoutItem = d
    let items = [a]
    let config = StackConfig(0.0f32, CrossAlign.Center, MainAlign.Start)
    let size = StackLayout.measure(items, Constraints.tight(200.0f32, 100.0f32), MainAxis.Vertical, config)
    @Expect(approxEq(size.width, 200.0f32, 0.5f32), true)
    StackLayout.arrange(items, Rect(0.0f32, 0.0f32, 200.0f32, 100.0f32), MainAxis.Vertical, config)
    @Expect(approxEq(d.lastRect.x, 50.0f32, 0.5f32), true)
    @Expect(approxEq(d.lastRect.width, 100.0f32, 0.5f32), true)
    @Expect(approxEq(d.lastRect.y, 0.0f32, 0.5f32), true)
}

@Test
func crossAlignStretchTest(): Unit {
    let d = DummyItem(100.0f32, 40.0f32)
    let a: LayoutItem = d
    let items = [a]
    let config = StackConfig(0.0f32, CrossAlign.Stretch, MainAlign.Start)
    StackLayout.measure(items, Constraints.tight(200.0f32, 100.0f32), MainAxis.Vertical, config)
    StackLayout.arrange(items, Rect(0.0f32, 0.0f32, 200.0f32, 100.0f32), MainAxis.Vertical, config)
    @Expect(approxEq(d.lastRect.width, 200.0f32, 0.5f32), true)
    @Expect(approxEq(d.lastRect.x, 0.0f32, 0.5f32), true)
}

@Test
func mainAlignSpaceBetweenTest(): Unit {
    let d1 = DummyItem(50.0f32, 10.0f32)
    let d2 = DummyItem(50.0f32, 10.0f32)
    let a: LayoutItem = d1
    let b: LayoutItem = d2
    let items = [a, b]
    let config = StackConfig(100.0f32, CrossAlign.Start, MainAlign.SpaceBetween)
    StackLayout.measure(items, Constraints.tight(200.0f32, 10.0f32), MainAxis.Horizontal, config)
    StackLayout.arrange(items, Rect(0.0f32, 0.0f32, 200.0f32, 10.0f32), MainAxis.Horizontal, config)
    @Expect(approxEq(d1.lastRect.x, 0.0f32, 0.5f32), true)
    @Expect(approxEq(d2.lastRect.x, 150.0f32, 0.5f32), true)
}

@Test
func constraintsClampTest(): Unit {
    let c = Constraints(50.0f32, 100.0f32, 20.0f32, 80.0f32)
    let small = c.constrain(Size(10.0f32, 10.0f32))
    @Expect(approxEq(small.width, 50.0f32, 0.01f32), true)
    @Expect(approxEq(small.height, 20.0f32, 0.01f32), true)
    let big = c.constrain(Size(500.0f32, 500.0f32))
    @Expect(approxEq(big.width, 100.0f32, 0.01f32), true)
    @Expect(approxEq(big.height, 80.0f32, 0.01f32), true)

    let tight = Constraints.tight(300.0f32, 200.0f32)
    @Expect(approxEq(tight.minWidth, 300.0f32, 0.01f32), true)
    @Expect(approxEq(tight.maxWidth, 300.0f32, 0.01f32), true)
    @Expect(approxEq(tight.minHeight, 200.0f32, 0.01f32), true)

    let loosened = c.loosen()
    @Expect(approxEq(loosened.minWidth, 0.0f32, 0.01f32), true)
    @Expect(approxEq(loosened.maxWidth, 100.0f32, 0.01f32), true)
}

@Test
func rectGeometryTest(): Unit {
    let r = Rect(10.0f32, 20.0f32, 100.0f32, 50.0f32)
    @Expect(approxEq(r.left, 10.0f32, 0.01f32), true)
    @Expect(approxEq(r.top, 20.0f32, 0.01f32), true)
    @Expect(approxEq(r.right, 110.0f32, 0.01f32), true)
    @Expect(approxEq(r.bottom, 70.0f32, 0.01f32), true)

    @Expect(r.contains(Point(10.0f32, 20.0f32)), true)
    @Expect(r.contains(Point(109.5f32, 69.5f32)), true)
    @Expect(r.contains(Point(110.0f32, 20.0f32)), false)
    @Expect(r.contains(Point(10.0f32, 70.0f32)), false)
    @Expect(r.contains(Point(9.0f32, 20.0f32)), false)

    let hit = r.intersect(Rect(50.0f32, 30.0f32, 100.0f32, 10.0f32))
    @Expect(hit.isSome(), true)
    if (let Some(v) <- hit) {
        @Expect(approxEq(v.x, 50.0f32, 0.01f32), true)
        @Expect(approxEq(v.y, 30.0f32, 0.01f32), true)
        @Expect(approxEq(v.width, 60.0f32, 0.01f32), true)
        @Expect(approxEq(v.height, 10.0f32, 0.01f32), true)
    }
    let miss = r.intersect(Rect(200.0f32, 200.0f32, 10.0f32, 10.0f32))
    @Expect(miss.isNone(), true)

    let u = r.union(Rect(0.0f32, 0.0f32, 20.0f32, 100.0f32))
    @Expect(approxEq(u.x, 0.0f32, 0.01f32), true)
    @Expect(approxEq(u.y, 0.0f32, 0.01f32), true)
    @Expect(approxEq(u.width, 110.0f32, 0.01f32), true)
    @Expect(approxEq(u.height, 100.0f32, 0.01f32), true)

    let inset = r.inset(Insets.all(10.0f32))
    @Expect(approxEq(inset.x, 20.0f32, 0.01f32), true)
    @Expect(approxEq(inset.y, 30.0f32, 0.01f32), true)
    @Expect(approxEq(inset.width, 80.0f32, 0.01f32), true)
    @Expect(approxEq(inset.height, 30.0f32, 0.01f32), true)
}

@Test
func sizeHelpersTest(): Unit {
    @Expect(Size.ZERO.isZero, true)
    @Expect(Size(10.0f32, 0.0f32).isZero, false)
    let maximum = Size(10.0f32, 30.0f32).max(Size(20.0f32, 5.0f32))
    @Expect(approxEq(maximum.width, 20.0f32, 0.01f32), true)
    @Expect(approxEq(maximum.height, 30.0f32, 0.01f32), true)
    let minimum = Size(10.0f32, 30.0f32).min(Size(20.0f32, 5.0f32))
    @Expect(approxEq(minimum.width, 10.0f32, 0.01f32), true)
    @Expect(approxEq(minimum.height, 5.0f32, 0.01f32), true)
}
