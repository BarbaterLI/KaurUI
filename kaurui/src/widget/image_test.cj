package kaurui.widget

import std.collection.*
import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// FakeRenderer: records image/drawing calls without touching GDI.
// ---------------------------------------------------------------------------

class FakeRenderer <: Renderer {
    public var loadImageCalls: Int64 = 0
    public var drawImageCalls: Int64 = 0
    public var fillRectCalls: Int64 = 0
    public var strokeRectCalls: Int64 = 0
    public var loadResult: Option<ImageHandle> = None
    public var lastDst: ?Rect = None
    public var lastPath: String = ""
    public var pushClipCalls: Int64 = 0
    public var popClipCalls: Int64 = 0
    public var lastClip: ?Rect = None
    public var ops: ArrayList<String> = ArrayList<String>()
    private var drawCallCount: Int64 = 0

    public func beginFrame(width: Float32, height: Float32): Unit {}

    public func fillRect(rect: Rect, color: Color): Unit {
        fillRectCalls += 1
        ops.add("fillRect")
    }

    public func fillRoundRect(rect: Rect, radius: Float32, color: Color): Unit {
        drawCallCount += 1
    }

    public func strokeRect(rect: Rect, color: Color, width: Float32): Unit {
        strokeRectCalls += 1
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

    public func pushClip(rect: Rect): Unit {
        pushClipCalls += 1
        lastClip = rect
        ops.add("pushClip")
    }

    public func popClip(): Unit {
        popClipCalls += 1
        ops.add("popClip")
    }

    public func endFrame(): Unit {}

    public func loadImage(path: String): Option<ImageHandle> {
        loadImageCalls += 1
        lastPath = path
        loadResult
    }

    public func drawImage(image: ImageHandle, dst: Rect): Unit {
        drawImageCalls += 1
        lastDst = dst
        ops.add("drawImage")
    }

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
}

func imagePaintFixture(img: Image, r: Renderer): Unit {
    img.bind(WidgetContext(Theme.light()))
    img.measure(Constraints.loose(800.0f32, 600.0f32))
    img.arrange(Rect(10.0f32, 20.0f32, img.size.width, img.size.height))
    img.paint(r)
}

func approxRect(r: Rect, x: Float32, y: Float32, w: Float32, h: Float32): Bool {
    widgetApprox(r.x, x, 0.1f32) && widgetApprox(r.y, y, 0.1f32) && widgetApprox(r.width, w, 0.1f32) && widgetApprox(
        r.height, h, 0.1f32)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@Test
func imageMeasureExplicitSizeTest(): Unit {
    let img = Image(path: "x.bmp", width: 40.0f32, height: 30.0f32)
    let size = img.measure(Constraints.loose(800.0f32, 600.0f32))
    @Expect(widgetApprox(size.width, 40.0f32, 0.1f32), true)
    @Expect(widgetApprox(size.height, 30.0f32, 0.1f32), true)
}

@Test
func imageMeasureDefaultSizeTest(): Unit {
    let img = Image(path: "x.bmp")
    let size = img.measure(Constraints.loose(800.0f32, 600.0f32))
    @Expect(widgetApprox(size.width, 120.0f32, 0.1f32), true)
    @Expect(widgetApprox(size.height, 80.0f32, 0.1f32), true)
}

@Test
func imageDrawsLoadedHandleTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = Some(ImageHandle(CPointer<Unit>(), 64.0f32, 64.0f32))
    let img = Image(path: "x.bmp", width: 40.0f32, height: 30.0f32)
    imagePaintFixture(img, r)

    @Expect(r.loadImageCalls, 1)
    @Expect(r.drawImageCalls, 1)
    @Expect(r.lastDst.isSome(), true)
    if (let Some(dst) <- r.lastDst) {
        @Expect(widgetApprox(dst.x, img.bounds.x, 0.1f32), true)
        @Expect(widgetApprox(dst.y, img.bounds.y, 0.1f32), true)
        @Expect(widgetApprox(dst.width, img.bounds.width, 0.1f32), true)
        @Expect(widgetApprox(dst.height, img.bounds.height, 0.1f32), true)
    }
}

@Test
func imageFallsBackWhenLoadFailsTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = None
    let img = Image(path: "missing.bmp", width: 40.0f32, height: 30.0f32)
    imagePaintFixture(img, r)

    @Expect(r.drawImageCalls, 0)
    @Expect(r.fillRectCalls, 1)
    @Expect(r.strokeRectCalls, 1)
}

@Test
func imageLoadsOnlyOnceTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = Some(ImageHandle(CPointer<Unit>(), 64.0f32, 64.0f32))
    let img = Image(path: "x.bmp", width: 40.0f32, height: 30.0f32)
    imagePaintFixture(img, r)
    img.paint(r)
    img.paint(r)

    @Expect(r.loadImageCalls, 1)
    @Expect(r.drawImageCalls, 3)
}

@Test
func imageSetPathReloadsTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = Some(ImageHandle(CPointer<Unit>(), 64.0f32, 64.0f32))
    let img = Image(path: "x.bmp", width: 40.0f32, height: 30.0f32)
    imagePaintFixture(img, r)
    @Expect(r.loadImageCalls, 1)

    img.setPath("y.bmp")
    img.paint(r)
    @Expect(r.loadImageCalls, 2)
    @Expect(r.lastPath, "y.bmp")
}

@Test
func imageIsNotClickableTest(): Unit {
    let img = Image(path: "x.bmp")
    @Expect(img.isClickable(), false)
}

// ---------------------------------------------------------------------------
// fitRect geometry
// ---------------------------------------------------------------------------

@Test
func imageFitRectFillSquareTest(): Unit {
    let r = Image.fitRect(100.0f32, 100.0f32, Rect(0.0f32, 0.0f32, 200.0f32, 100.0f32), ImageFit.Fill)
    @Expect(approxRect(r, 0.0f32, 0.0f32, 200.0f32, 100.0f32), true)
}

@Test
func imageFitRectContainSquareTest(): Unit {
    let r = Image.fitRect(100.0f32, 100.0f32, Rect(0.0f32, 0.0f32, 200.0f32, 100.0f32), ImageFit.Contain)
    @Expect(approxRect(r, 50.0f32, 0.0f32, 100.0f32, 100.0f32), true)
}

@Test
func imageFitRectCoverSquareTest(): Unit {
    let r = Image.fitRect(100.0f32, 100.0f32, Rect(0.0f32, 0.0f32, 200.0f32, 100.0f32), ImageFit.Cover)
    @Expect(approxRect(r, 0.0f32, -50.0f32, 200.0f32, 200.0f32), true)
}

@Test
func imageFitRectContainWideSourceTest(): Unit {
    let r = Image.fitRect(200.0f32, 100.0f32, Rect(0.0f32, 0.0f32, 100.0f32, 100.0f32), ImageFit.Contain)
    @Expect(approxRect(r, 0.0f32, 25.0f32, 100.0f32, 50.0f32), true)
}

@Test
func imageFitRectCoverWideSourceTest(): Unit {
    let r = Image.fitRect(200.0f32, 100.0f32, Rect(0.0f32, 0.0f32, 100.0f32, 100.0f32), ImageFit.Cover)
    @Expect(approxRect(r, -50.0f32, 0.0f32, 200.0f32, 100.0f32), true)
}

@Test
func imageFitRectCentersInOffsetDstTest(): Unit {
    let dst = Rect(10.0f32, 20.0f32, 200.0f32, 100.0f32)
    let contain = Image.fitRect(100.0f32, 100.0f32, dst, ImageFit.Contain)
    @Expect(approxRect(contain, 60.0f32, 20.0f32, 100.0f32, 100.0f32), true)
    let cover = Image.fitRect(100.0f32, 100.0f32, dst, ImageFit.Cover)
    @Expect(approxRect(cover, 10.0f32, -30.0f32, 200.0f32, 200.0f32), true)
}

@Test
func imageFitRectDegenerateSourceTest(): Unit {
    let dst = Rect(10.0f32, 20.0f32, 200.0f32, 100.0f32)
    let contain = Image.fitRect(0.0f32, 0.0f32, dst, ImageFit.Contain)
    @Expect(approxRect(contain, 10.0f32, 20.0f32, 200.0f32, 100.0f32), true)
    let cover = Image.fitRect(0.0f32, 0.0f32, dst, ImageFit.Cover)
    @Expect(approxRect(cover, 10.0f32, 20.0f32, 200.0f32, 100.0f32), true)
}

// ---------------------------------------------------------------------------
// Painting per fit mode
// ---------------------------------------------------------------------------

@Test
func imageDefaultsToFillTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = Some(ImageHandle(CPointer<Unit>(), 100.0f32, 100.0f32))
    let img = Image(path: "x.bmp", width: 200.0f32, height: 100.0f32)
    imagePaintFixture(img, r)

    @Expect(r.drawImageCalls, 1)
    @Expect(r.fillRectCalls, 0)
    @Expect(r.pushClipCalls, 0)
    @Expect(r.popClipCalls, 0)
    if (let Some(dst) <- r.lastDst) {
        @Expect(approxRect(dst, img.bounds.x, img.bounds.y, img.bounds.width, img.bounds.height), true)
    }
}

@Test
func imageContainDrawsBackgroundBeforeImageTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = Some(ImageHandle(CPointer<Unit>(), 100.0f32, 100.0f32))
    let img = Image(
        path: "x.bmp",
        width: 200.0f32,
        height: 100.0f32,
        fit: ImageFit.Contain,
        background: Color.rgb(30, 30, 30)
    )
    imagePaintFixture(img, r)

    @Expect(r.fillRectCalls, 1)
    @Expect(r.drawImageCalls, 1)
    @Expect(r.ops.size, 2)
    @Expect(r.ops[0], "fillRect")
    @Expect(r.ops[1], "drawImage")
    if (let Some(dst) <- r.lastDst) {
        @Expect(approxRect(dst, 60.0f32, 20.0f32, 100.0f32, 100.0f32), true)
    }
}

@Test
func imageContainWithoutBackgroundSkipsFillTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = Some(ImageHandle(CPointer<Unit>(), 200.0f32, 100.0f32))
    let img = Image(path: "x.bmp", width: 100.0f32, height: 100.0f32, fit: ImageFit.Contain)
    imagePaintFixture(img, r)

    @Expect(r.fillRectCalls, 0)
    @Expect(r.drawImageCalls, 1)
    if (let Some(dst) <- r.lastDst) {
        @Expect(approxRect(dst, 10.0f32, 45.0f32, 100.0f32, 50.0f32), true)
    }
}

@Test
func imageCoverClipsToBoundsTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = Some(ImageHandle(CPointer<Unit>(), 100.0f32, 100.0f32))
    let img = Image(path: "x.bmp", width: 200.0f32, height: 100.0f32, fit: ImageFit.Cover)
    imagePaintFixture(img, r)

    @Expect(r.pushClipCalls, 1)
    @Expect(r.popClipCalls, 1)
    @Expect(r.ops.size, 3)
    @Expect(r.ops[0], "pushClip")
    @Expect(r.ops[1], "drawImage")
    @Expect(r.ops[2], "popClip")
    if (let Some(clip) <- r.lastClip) {
        @Expect(approxRect(clip, img.bounds.x, img.bounds.y, img.bounds.width, img.bounds.height), true)
    }
    if (let Some(dst) <- r.lastDst) {
        @Expect(approxRect(dst, 10.0f32, -30.0f32, 200.0f32, 200.0f32), true)
    }
}

@Test
func imageLoadFailureIgnoresFitTest(): Unit {
    let r = FakeRenderer()
    r.loadResult = None
    let img = Image(
        path: "missing.bmp",
        width: 200.0f32,
        height: 100.0f32,
        fit: ImageFit.Cover,
        background: Color.rgb(30, 30, 30)
    )
    imagePaintFixture(img, r)

    @Expect(r.drawImageCalls, 0)
    @Expect(r.fillRectCalls, 1)
    @Expect(r.strokeRectCalls, 1)
    @Expect(r.pushClipCalls, 0)
    @Expect(r.popClipCalls, 0)
}
