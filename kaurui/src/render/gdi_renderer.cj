package kaurui.render

import std.collection.*
import std.math.*
import kaurui.ffi.*
import kaurui.layout.*

// ---------------------------------------------------------------------------
// GDI constants (not present in kaurui.ffi)
// ---------------------------------------------------------------------------

let MM_TEXT_MM: Int32 = 1
let MM_ANISOTROPIC_MM: Int32 = 8
let STOCK_NULL_BRUSH: Int32 = 5
let STOCK_NULL_PEN: Int32 = 8
let FONT_ANTIALIASED_QUALITY: UInt32 = 4
let FONT_FACE_PRIMARY: String = "Microsoft YaHei UI"
let FONT_FACE_FALLBACK: String = "Segoe UI"
let FONT_FACE_LAST: String = "Arial"
let MEASURE_CACHE_LIMIT: Int64 = 4096
let IMAGE_BITMAP_TYPE: UInt32 = 0
let LR_LOADFROMFILE: UInt32 = 0x10
let LR_CREATEDIBSECTION: UInt32 = 0x2000
let COLORONCOLOR_MODE: Int32 = 3

// ---------------------------------------------------------------------------
// C structures
// ---------------------------------------------------------------------------

@C
struct Bitmap {
    var bmType: Int32 = 0
    var bmWidth: Int32 = 0
    var bmHeight: Int32 = 0
    var bmWidthBytes: Int32 = 0
    var bmPlanes: UInt16 = 0
    var bmBitsPixel: UInt16 = 0
    var bmBits: CPointer<Unit> = CPointer<Unit>()
}

// ---------------------------------------------------------------------------
// Numeric helpers (logic pixel <-> device integer)
// ---------------------------------------------------------------------------

func renderMaxF(a: Float32, b: Float32): Float32 {
    if (a >= b) {
        return a
    }
    return b
}

func renderMinF(a: Float32, b: Float32): Float32 {
    if (a <= b) {
        return a
    }
    return b
}

func renderAbsF(a: Float32, b: Float32): Float32 {
    if (a >= b) {
        return a - b
    }
    return b - a
}

func renderToI32(v: Float32): Int32 {
    if (v != v) {
        return 0
    }
    if (v > 2147483000.0f32) {
        return 2147483000
    }
    if (v < -2147483000.0f32) {
        return -2147483000
    }
    return Int32(round(v))
}

func renderMaxI32(a: Int32, b: Int32): Int32 {
    if (a >= b) {
        return a
    }
    return b
}

func renderUtf16Len(s: String): Int64 {
    var n: Int64 = 0
    for (r in s.runes()) {
        if (UInt32(r) > 0xFFFF) {
            n += 2
        } else {
            n += 1
        }
    }
    return n
}

func renderColorRef(c: Color): UInt32 {
    return colorRef(c.r, c.g, c.b)
}

// Last-resort text metrics used only when no usable measurement DC exists.
func estimateTextMetrics(text: String, style: TextStyle): Size {
    let chars = Float32(text.size)
    return Size(chars * style.fontSize * 0.6f32, style.fontSize * 1.4f32)
}

// ---------------------------------------------------------------------------
// gdi32 entry points resolved through kaurui.ffi (no import library needed)
// ---------------------------------------------------------------------------

class GdiApi {
    let createCompatibleDc: CFunc<(CPointer<Unit>) -> CPointer<Unit>>
    let createCompatibleBitmap: CFunc<(CPointer<Unit>, Int32, Int32) -> CPointer<Unit>>
    let getDc: Option<CFunc<(CPointer<Unit>) -> CPointer<Unit>>>
    let releaseDc: Option<CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32>>
    let selectObject: CFunc<(CPointer<Unit>, CPointer<Unit>) -> CPointer<Unit>>
    let deleteObject: CFunc<(CPointer<Unit>) -> Int32>
    let deleteDc: CFunc<(CPointer<Unit>) -> Int32>
    let bitBlt: CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32, CPointer<Unit>, Int32, Int32, UInt32) -> Int32>
    let setMapMode: CFunc<(CPointer<Unit>, Int32) -> Int32>
    let setWindowExtEx: CFunc<(CPointer<Unit>, Int32, Int32, CPointer<WinSize>) -> Int32>
    let setViewportExtEx: CFunc<(CPointer<Unit>, Int32, Int32, CPointer<WinSize>) -> Int32>
    let getStockObject: CFunc<(Int32) -> CPointer<Unit>>
    let createSolidBrush: CFunc<(UInt32) -> CPointer<Unit>>
    let createPen: CFunc<(Int32, Int32, UInt32) -> CPointer<Unit>>
    let createFont: CFunc<(Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, CString) -> CPointer<Unit>>
    let setTextColor: CFunc<(CPointer<Unit>, UInt32) -> UInt32>
    let setBkMode: CFunc<(CPointer<Unit>, Int32) -> Int32>
    let textOut: CFunc<(CPointer<Unit>, Int32, Int32, CPointer<UInt16>, Int32) -> Int32>
    let getTextExtent: CFunc<(CPointer<Unit>, CPointer<UInt16>, Int32, CPointer<WinSize>) -> Int32>
    let rectangle: CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32) -> Int32>
    let roundRect: CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32, Int32, Int32) -> Int32>
    let saveDc: CFunc<(CPointer<Unit>) -> Int32>
    let restoreDc: CFunc<(CPointer<Unit>, Int32) -> Int32>
    let intersectClipRect: CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32) -> Int32>
    let loadImage: Option<CFunc<(CPointer<Unit>, CString, UInt32, Int32, Int32, UInt32) -> CPointer<Unit>>>
    let getObject: CFunc<(CPointer<Unit>, Int32, CPointer<Bitmap>) -> Int32>
    let setStretchBltMode: CFunc<(CPointer<Unit>, Int32) -> Int32>
    let stretchBlt: CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32, CPointer<Unit>, Int32, Int32, Int32, Int32,
        UInt32) -> Int32>

    init() {
        let lib = Libs.gdi32()
        createCompatibleDc = CFunc<(CPointer<Unit>) -> CPointer<Unit>>(lib.proc("CreateCompatibleDC"))
        createCompatibleBitmap = CFunc<(CPointer<Unit>, Int32, Int32) -> CPointer<Unit>>(
            lib.proc("CreateCompatibleBitmap"))
        getDc = match (Libs.user32().tryProc("GetDC")) {
            case Some(p) => Some(CFunc<(CPointer<Unit>) -> CPointer<Unit>>(p))
            case None => None
        }
        releaseDc = match (Libs.user32().tryProc("ReleaseDC")) {
            case Some(p) => Some(CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32>(p))
            case None => None
        }
        selectObject = CFunc<(CPointer<Unit>, CPointer<Unit>) -> CPointer<Unit>>(lib.proc("SelectObject"))
        deleteObject = CFunc<(CPointer<Unit>) -> Int32>(lib.proc("DeleteObject"))
        deleteDc = CFunc<(CPointer<Unit>) -> Int32>(lib.proc("DeleteDC"))
        bitBlt = CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32, CPointer<Unit>, Int32, Int32, UInt32) -> Int32>(
            lib.proc("BitBlt"))
        setMapMode = CFunc<(CPointer<Unit>, Int32) -> Int32>(lib.proc("SetMapMode"))
        setWindowExtEx = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<WinSize>) -> Int32>(lib.proc("SetWindowExtEx"))
        setViewportExtEx = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<WinSize>) -> Int32>(
            lib.proc("SetViewportExtEx"))
        getStockObject = CFunc<(Int32) -> CPointer<Unit>>(lib.proc("GetStockObject"))
        createSolidBrush = CFunc<(UInt32) -> CPointer<Unit>>(lib.proc("CreateSolidBrush"))
        createPen = CFunc<(Int32, Int32, UInt32) -> CPointer<Unit>>(lib.proc("CreatePen"))
        createFont = CFunc<(Int32, Int32, Int32, Int32, Int32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
                UInt32, CString) -> CPointer<Unit>>(lib.proc("CreateFontW"))
        setTextColor = CFunc<(CPointer<Unit>, UInt32) -> UInt32>(lib.proc("SetTextColor"))
        setBkMode = CFunc<(CPointer<Unit>, Int32) -> Int32>(lib.proc("SetBkMode"))
        textOut = CFunc<(CPointer<Unit>, Int32, Int32, CPointer<UInt16>, Int32) -> Int32>(lib.proc("TextOutW"))
        getTextExtent = CFunc<(CPointer<Unit>, CPointer<UInt16>, Int32, CPointer<WinSize>) -> Int32>(
            lib.proc("GetTextExtentPoint32W"))
        rectangle = CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32) -> Int32>(lib.proc("Rectangle"))
        roundRect = CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32, Int32, Int32) -> Int32>(lib.proc("RoundRect"))
        saveDc = CFunc<(CPointer<Unit>) -> Int32>(lib.proc("SaveDC"))
        restoreDc = CFunc<(CPointer<Unit>, Int32) -> Int32>(lib.proc("RestoreDC"))
        intersectClipRect = CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32) -> Int32>(lib.proc("IntersectClipRect"))
        loadImage = match (Libs.user32().tryProc("LoadImageW")) {
            case Some(p) => Some(CFunc<(CPointer<Unit>, CString, UInt32, Int32, Int32, UInt32) -> CPointer<Unit>>(p))
            case None => None
        }
        getObject = CFunc<(CPointer<Unit>, Int32, CPointer<Bitmap>) -> Int32>(lib.proc("GetObjectW"))
        setStretchBltMode = CFunc<(CPointer<Unit>, Int32) -> Int32>(lib.proc("SetStretchBltMode"))
        stretchBlt = CFunc<(CPointer<Unit>, Int32, Int32, Int32, Int32, CPointer<Unit>, Int32, Int32, Int32, Int32,
                UInt32) -> Int32>(lib.proc("StretchBlt"))
    }
}

// ---------------------------------------------------------------------------
// GDI renderer (double buffered, logical-coordinate drawing)
// ---------------------------------------------------------------------------

public class GdiRenderer <: Renderer {
    private let api: GdiApi = GdiApi()

    private var hdcWindow: CPointer<Unit> = CPointer<Unit>()
    private var memDc: CPointer<Unit> = CPointer<Unit>()
    private var memBitmap: CPointer<Unit> = CPointer<Unit>()
    private var defaultBitmap: CPointer<Unit> = CPointer<Unit>()
    private var measureDcHandle: CPointer<Unit> = CPointer<Unit>()
    private var measureBitmap: CPointer<Unit> = CPointer<Unit>()
    private var measureFromScreen: Bool = false
    private var nullPen: CPointer<Unit> = CPointer<Unit>()
    private var nullBrush: CPointer<Unit> = CPointer<Unit>()

    private var scaleValue: Float32 = 1.0f32
    private var logicalWidth: Float32 = 0.0f32
    private var logicalHeight: Float32 = 0.0f32
    private var physicalWidth: Int32 = 0
    private var physicalHeight: Int32 = 0
    private var mappingActive: Bool = false
    private var clipDepthValue: Int64 = 0
    private var drawCallCount: Int64 = 0
    private var paintedWidth: Float32 = 0.0f32
    private var paintedHeight: Float32 = 0.0f32

    // Back buffer is reused across frames as long as its physical size is stable.
    private var bufferWidth: Int32 = 0
    private var bufferHeight: Int32 = 0
    private var bufferRebuildCount: Int64 = 0

    // Text metrics are cached by "text|fontSize|bold" to avoid repeated GDI queries.
    private let measureCache: HashMap<String, Size> = HashMap<String, Size>()
    private var measureCallCount: Int64 = 0

    // Effective logical clip per nesting level (intersection of all pushed clips).
    private let clipStack: ArrayList<Rect> = ArrayList<Rect>()

    private let fontCache: HashMap<Int64, CPointer<Unit>> = HashMap<Int64, CPointer<Unit>>()
    private let penCache: HashMap<Int64, CPointer<Unit>> = HashMap<Int64, CPointer<Unit>>()
    private let brushCache: HashMap<UInt32, CPointer<Unit>> = HashMap<UInt32, CPointer<Unit>>()

    // Images are cached by path so repeated frames reuse the same HBITMAP.
    private let imageCache: HashMap<String, ImageHandle> = HashMap<String, ImageHandle>()
    private var imageDcHandle: CPointer<Unit> = CPointer<Unit>()

    public init() {
        this.nullPen = unsafe { api.getStockObject(STOCK_NULL_PEN) }
        this.nullBrush = unsafe { api.getStockObject(STOCK_NULL_BRUSH) }
        if (this.nullPen.isNull() || this.nullBrush.isNull()) {
            throw Win32Error("failed to obtain GDI stock objects")
        }
    }

    // -- lifecycle ---------------------------------------------------------

    public func bind(hdc: CPointer<Unit>, scale: Float32): Unit {
        if (hdc.isNull()) {
            deleteBuffers()
            hdcWindow = CPointer<Unit>()
            return
        }
        let newScale = if (scale > 0.0f32) {
            scale
        } else {
            1.0f32
        }
        let scaleChanged = renderAbsF(newScale, scaleValue) > 0.001f32
        let sameWindow = !hdcWindow.isNull() && hdc.toUIntNative() == hdcWindow.toUIntNative()
        if (scaleChanged) {
            deleteBuffers()
            releaseFonts()
            measureCache.clear()
            scaleValue = newScale
        }
        if (!sameWindow) {
            deleteBuffers()
            hdcWindow = hdc
        }
    }

    public func release(): Unit {
        releaseImages()
        deleteBuffers()
        if (!measureDcHandle.isNull()) {
            if (measureFromScreen) {
                if (let Some(rel) <- api.releaseDc) {
                    unsafe { rel(CPointer<Unit>(), measureDcHandle) }
                }
            } else {
                unsafe { api.deleteDc(measureDcHandle) }
            }
            measureDcHandle = CPointer<Unit>()
        }
        measureFromScreen = false
        if (!measureBitmap.isNull()) {
            unsafe { api.deleteObject(measureBitmap) }
            measureBitmap = CPointer<Unit>()
        }
        releaseFonts()
        releaseGdiObjects(penCache)
        releaseGdiObjects(brushCache)
        hdcWindow = CPointer<Unit>()
        scaleValue = 1.0f32
        logicalWidth = 0.0f32
        logicalHeight = 0.0f32
        paintedWidth = 0.0f32
        paintedHeight = 0.0f32
        mappingActive = false
        clipDepthValue = 0
        drawCallCount = 0
        clipStack.clear()
        measureCache.clear()
        measureCallCount = 0
        bufferRebuildCount = 0
    }

    private func deleteBufferObjects(): Unit {
        if (!memDc.isNull()) {
            if (!memBitmap.isNull()) {
                if (!defaultBitmap.isNull()) {
                    unsafe { api.selectObject(memDc, defaultBitmap) }
                }
                unsafe { api.deleteObject(memBitmap) }
            }
            unsafe { api.deleteDc(memDc) }
        }
        memDc = CPointer<Unit>()
        memBitmap = CPointer<Unit>()
        defaultBitmap = CPointer<Unit>()
        bufferWidth = 0
        bufferHeight = 0
    }

    private func deleteBuffers(): Unit {
        deleteBufferObjects()
        physicalWidth = 0
        physicalHeight = 0
        mappingActive = false
        clipDepthValue = 0
        clipStack.clear()
    }

    private func releaseFonts(): Unit {
        for ((_, font) in fontCache) {
            unsafe { api.deleteObject(font) }
        }
        fontCache.clear()
    }

    private func releaseGdiObjects(cache: HashMap<Int64, CPointer<Unit>>): Unit {
        for ((_, obj) in cache) {
            unsafe { api.deleteObject(obj) }
        }
        cache.clear()
    }

    private func releaseGdiObjects(cache: HashMap<UInt32, CPointer<Unit>>): Unit {
        for ((_, obj) in cache) {
            unsafe { api.deleteObject(obj) }
        }
        cache.clear()
    }

    private func releaseImages(): Unit {
        // Delete the source DC first so no cached bitmap stays selected.
        if (!imageDcHandle.isNull()) {
            unsafe { api.deleteDc(imageDcHandle) }
            imageDcHandle = CPointer<Unit>()
        }
        for ((_, image) in imageCache) {
            unsafe { api.deleteObject(image.ptr) }
        }
        imageCache.clear()
    }

    // -- frame -------------------------------------------------------------

    public func beginFrame(width: Float32, height: Float32): Unit {
        drawCallCount = 0
        clipDepthValue = 0
        clipStack.clear()
        logicalWidth = width
        logicalHeight = height
        paintedWidth = if (width > 0.0f32) {
            width
        } else {
            0.0f32
        }
        paintedHeight = if (height > 0.0f32) {
            height
        } else {
            0.0f32
        }
        if (width <= 0.0f32 || height <= 0.0f32) {
            mappingActive = false
            return
        }
        if (hdcWindow.isNull()) {
            mappingActive = false
            return
        }
        physicalWidth = renderMaxI32(1, renderToI32(width * scaleValue))
        physicalHeight = renderMaxI32(1, renderToI32(height * scaleValue))
        if (!ensureBuffer()) {
            mappingActive = false
            return
        }
        unsafe {
            api.setMapMode(memDc, MM_ANISOTROPIC_MM)
            api.setWindowExtEx(memDc, renderMaxI32(1, renderToI32(width)), renderMaxI32(1, renderToI32(height)),
                CPointer<WinSize>())
            api.setViewportExtEx(memDc, physicalWidth, physicalHeight, CPointer<WinSize>())
        }
        mappingActive = true
        let white = brushFor(Color.WHITE)
        unsafe {
            api.selectObject(memDc, white)
            api.selectObject(memDc, nullPen)
            api.rectangle(memDc, 0, 0, renderToI32(width) + 1, renderToI32(height) + 1)
        }
    }

    public func endFrame(): Unit {
        if (memDc.isNull() || hdcWindow.isNull() || !mappingActive) {
            mappingActive = false
            return
        }
        while (clipDepthValue > 0) {
            unsafe { api.restoreDc(memDc, -1) }
            clipDepthValue -= 1
        }
        mappingActive = false
        unsafe {
            api.setMapMode(memDc, MM_TEXT_MM)
            api.bitBlt(hdcWindow, 0, 0, physicalWidth, physicalHeight, memDc, 0, 0, Gdi.SRCCOPY)
        }
    }

    // Reuse the memory DC / bitmap while the physical size is unchanged; only
    // rebuild (deleting the old objects first) when the size actually changes.
    private func ensureBuffer(): Bool {
        if (hdcWindow.isNull()) {
            return false
        }
        if (!memDc.isNull() && !memBitmap.isNull() && physicalWidth == bufferWidth && physicalHeight == bufferHeight) {
            return true
        }
        deleteBufferObjects()
        let dc = unsafe { api.createCompatibleDc(hdcWindow) }
        if (dc.isNull()) {
            throw Win32Error("CreateCompatibleDC failed")
        }
        let bitmap = unsafe { api.createCompatibleBitmap(hdcWindow, physicalWidth, physicalHeight) }
        if (bitmap.isNull()) {
            unsafe { api.deleteDc(dc) }
            throw Win32Error("CreateCompatibleBitmap failed")
        }
        defaultBitmap = unsafe { api.selectObject(dc, bitmap) }
        memDc = dc
        memBitmap = bitmap
        bufferWidth = physicalWidth
        bufferHeight = physicalHeight
        bufferRebuildCount += 1
        return true
    }

    private func ready(): Bool {
        return !memDc.isNull() && !memBitmap.isNull() && mappingActive
    }

    // Effective clip rectangle: the intersection of the pushed clip stack, or
    // the whole frame when nothing has been pushed.
    private func effectiveClip(): Rect {
        if (clipStack.size > 0) {
            return clipStack[clipStack.size - 1]
        }
        return Rect(0.0f32, 0.0f32, logicalWidth, logicalHeight)
    }

    // A primitive entirely outside the effective clip is skipped without any
    // GDI call and without counting towards drawCalls.
    private func clippedOut(rect: Rect): Bool {
        return effectiveClip().intersect(rect).isNone()
    }

    // -- drawing -----------------------------------------------------------

    public func fillRect(rect: Rect, color: Color): Unit {
        if (color.a == 0 || rect.width <= 0.0f32 || rect.height <= 0.0f32) {
            return
        }
        if (!ready()) {
            return
        }
        if (clippedOut(rect)) {
            return
        }
        let brush = brushFor(color)
        unsafe {
            api.selectObject(memDc, brush)
            api.selectObject(memDc, nullPen)
            api.rectangle(memDc, renderToI32(rect.x), renderToI32(rect.y), renderToI32(rect.right),
                renderToI32(rect.bottom))
        }
        drawCallCount += 1
    }

    public func fillRoundRect(rect: Rect, radius: Float32, color: Color): Unit {
        if (color.a == 0 || rect.width <= 0.0f32 || rect.height <= 0.0f32) {
            return
        }
        if (!ready()) {
            return
        }
        if (clippedOut(rect)) {
            return
        }
        let r = renderMinF(renderMaxF(0.0f32, radius), renderMinF(rect.width, rect.height) * 0.5f32)
        let brush = brushFor(color)
        let diameter = renderToI32(r * 2.0f32)
        unsafe {
            api.selectObject(memDc, brush)
            api.selectObject(memDc, nullPen)
            api.roundRect(memDc, renderToI32(rect.x), renderToI32(rect.y), renderToI32(rect.right),
                renderToI32(rect.bottom), diameter, diameter)
        }
        drawCallCount += 1
    }

    public func strokeRect(rect: Rect, color: Color, width: Float32): Unit {
        if (color.a == 0 || rect.width <= 0.0f32 || rect.height <= 0.0f32) {
            return
        }
        if (!ready()) {
            return
        }
        if (clippedOut(rect)) {
            return
        }
        let pen = penFor(color, renderToI32(width))
        unsafe {
            api.selectObject(memDc, pen)
            api.selectObject(memDc, nullBrush)
            api.rectangle(memDc, renderToI32(rect.x), renderToI32(rect.y), renderToI32(rect.right),
                renderToI32(rect.bottom))
        }
        drawCallCount += 1
    }

    public func strokeRoundRect(rect: Rect, radius: Float32, color: Color, width: Float32): Unit {
        if (color.a == 0 || rect.width <= 0.0f32 || rect.height <= 0.0f32) {
            return
        }
        if (!ready()) {
            return
        }
        if (clippedOut(rect)) {
            return
        }
        let r = renderMinF(renderMaxF(0.0f32, radius), renderMinF(rect.width, rect.height) * 0.5f32)
        let pen = penFor(color, renderToI32(width))
        let diameter = renderToI32(r * 2.0f32)
        unsafe {
            api.selectObject(memDc, pen)
            api.selectObject(memDc, nullBrush)
            api.roundRect(memDc, renderToI32(rect.x), renderToI32(rect.y), renderToI32(rect.right),
                renderToI32(rect.bottom), diameter, diameter)
        }
        drawCallCount += 1
    }

    public func drawText(text: String, rect: Rect, style: TextStyle, color: Color, align: TextAlign): Unit {
        if (text.size == 0 || color.a == 0) {
            return
        }
        if (!ready()) {
            return
        }
        if (clippedOut(rect)) {
            return
        }
        let font = fontFor(style)
        unsafe {
            api.selectObject(memDc, font)
            api.setTextColor(memDc, renderColorRef(color))
            api.setBkMode(memDc, Int32(Gdi.TRANSPARENT))
        }
        let extent = measureText(text, style)
        let tx = match (align) {
            case Left => rect.x
            case Center => rect.x + (rect.width - extent.width) * 0.5f32
            case Right => rect.right - extent.width
        }
        let ty = rect.y + (rect.height - extent.height) * 0.5f32
        let wide = toUtf16(text)
        unsafe { api.textOut(memDc, renderToI32(tx), renderToI32(ty), CPointer<UInt16>(wide.getChars()),
            Int32(renderUtf16Len(text))) }
        freeCString(wide)
        drawCallCount += 1
    }

    public func measureText(text: String, style: TextStyle): Size {
        if (text.size == 0) {
            return Size(0.0f32, style.fontSize)
        }
        let key = "${text}|${style.fontSize}|${style.bold}"
        match (measureCache.get(key)) {
            case Some(cached) => return cached
            case None => ()
        }
        let mapped = !memDc.isNull() && mappingActive
        let dc = if (mapped) {
            memDc
        } else {
            measurementDc()
        }
        if (dc.isNull()) {
            return estimateTextMetrics(text, style)
        }
        let font = fontFor(style)
        unsafe { api.selectObject(dc, font) }
        let wide = toUtf16(text)
        var extent = WinSize()
        let ok = unsafe { api.getTextExtent(dc, CPointer<UInt16>(wide.getChars()), Int32(renderUtf16Len(text)),
            inout extent) }
        freeCString(wide)
        measureCallCount += 1
        let result = if (ok == 0) {
            estimateTextMetrics(text, style)
        } else {
            let w = Float32(extent.cx)
            let h = Float32(extent.cy)
            if (mapped) {
                Size(w, h)
            } else {
                let s = if (scaleValue > 0.0f32) {
                    scaleValue
                } else {
                    1.0f32
                }
                Size(w / s, h / s)
            }
        }
        if (measureCache.size >= MEASURE_CACHE_LIMIT) {
            measureCache.clear()
        }
        measureCache[key] = result
        return result
    }

    // -- images ------------------------------------------------------------

    public func loadImage(path: String): Option<ImageHandle> {
        if (path.size == 0) {
            return None
        }
        match (imageCache.get(path)) {
            case Some(cached) => return Some(cached)
            case None => ()
        }
        let loadFn = match (api.loadImage) {
            case Some(fn) => fn
            case None => return None
        }
        let wide = toUtf16(path)
        let bitmap = unsafe { loadFn(CPointer<Unit>(), wide, IMAGE_BITMAP_TYPE, 0, 0,
            LR_LOADFROMFILE | LR_CREATEDIBSECTION) }
        freeCString(wide)
        if (bitmap.isNull()) {
            return None
        }
        var info = Bitmap()
        let ok = unsafe { api.getObject(bitmap, Int32(sizeOf<Bitmap>()), inout info) }
        if (ok == 0) {
            unsafe { api.deleteObject(bitmap) }
            return None
        }
        let width = renderAbsF(Float32(info.bmWidth), 0.0f32)
        let height = renderAbsF(Float32(info.bmHeight), 0.0f32)
        let handle = ImageHandle(bitmap, width, height)
        imageCache[path] = handle
        Some(handle)
    }

    public func drawImage(image: ImageHandle, dst: Rect): Unit {
        if (dst.width <= 0.0f32 || dst.height <= 0.0f32) {
            return
        }
        if (!ready()) {
            return
        }
        if (clippedOut(dst)) {
            return
        }
        let dc = imageDc()
        if (dc.isNull()) {
            return
        }
        let srcWidth = renderMaxI32(1, renderToI32(image.width))
        let srcHeight = renderMaxI32(1, renderToI32(image.height))
        unsafe {
            api.selectObject(dc, image.ptr)
            api.setStretchBltMode(dc, COLORONCOLOR_MODE)
            api.stretchBlt(
                memDc,
                renderToI32(dst.x),
                renderToI32(dst.y),
                renderToI32(dst.width),
                renderToI32(dst.height),
                dc,
                0,
                0,
                srcWidth,
                srcHeight,
                Gdi.SRCCOPY
            )
        }
        drawCallCount += 1
    }

    // Shared memory DC used as the StretchBlt source; the active image bitmap is
    // selected into it for each draw.
    private func imageDc(): CPointer<Unit> {
        if (!imageDcHandle.isNull()) {
            return imageDcHandle
        }
        let base = if (!memDc.isNull()) {
            memDc
        } else {
            hdcWindow
        }
        let dc = unsafe { api.createCompatibleDc(base) }
        if (dc.isNull()) {
            return CPointer<Unit>()
        }
        imageDcHandle = dc
        dc
    }

    // -- clipping ----------------------------------------------------------

    public func pushClip(rect: Rect): Unit {
        if (memDc.isNull() || !mappingActive) {
            return
        }
        let saved = unsafe { api.saveDc(memDc) }
        if (saved <= 0) {
            throw Win32Error("SaveDC failed")
        }
        clipDepthValue += 1
        let effective = match (effectiveClip().intersect(rect)) {
            case Some(r) => r
            case None => Rect.ZERO
        }
        clipStack.add(effective)
        unsafe { api.intersectClipRect(memDc, renderToI32(rect.x), renderToI32(rect.y), renderToI32(rect.right),
            renderToI32(rect.bottom)) }
    }

    public func popClip(): Unit {
        if (clipDepthValue <= 0 || memDc.isNull()) {
            return
        }
        unsafe { api.restoreDc(memDc, -1) }
        clipDepthValue -= 1
        if (clipStack.size > 0) {
            clipStack.remove(at: clipStack.size - 1)
        }
    }

    // -- statistics --------------------------------------------------------

    public prop drawCalls: Int64 {
        get() {
            drawCallCount
        }
    }

    // Topmost clip rectangle, or None when nothing has been clipped.
    public prop currentClip: Option<Rect> {
        get() {
            if (clipStack.size > 0) {
                Some(clipStack[clipStack.size - 1])
            } else {
                None
            }
        }
    }

    // Number of GDI text measurement calls actually performed (cache misses).
    public prop measureCalls: Int64 {
        get() {
            measureCallCount
        }
    }

    // Number of times the back-buffer DC/bitmap pair had to be (re)created.
    public prop bufferRebuilds: Int64 {
        get() {
            bufferRebuildCount
        }
    }

    // Number of images currently held in the path cache.
    public prop imageCacheSize: Int64 {
        get() {
            Int64(imageCache.size)
        }
    }

    public prop lastPaintedArea: Size {
        get() {
            Size(paintedWidth, paintedHeight)
        }
    }

    // -- resource caches ---------------------------------------------------

    private func brushFor(color: Color): CPointer<Unit> {
        let key = renderColorRef(color)
        match (brushCache.get(key)) {
            case Some(brush) => brush
            case None =>
                let brush = unsafe { api.createSolidBrush(key) }
                if (brush.isNull()) {
                    throw Win32Error("CreateSolidBrush failed")
                }
                brushCache[key] = brush
                brush
        }
    }

    private func penFor(color: Color, width: Int32): CPointer<Unit> {
        let w = renderMaxI32(1, width)
        let key = (Int64(w) << 32) | Int64(renderColorRef(color))
        match (penCache.get(key)) {
            case Some(pen) => pen
            case None =>
                let pen = unsafe { api.createPen(Int32(Gdi.PS_SOLID), w, renderColorRef(color)) }
                if (pen.isNull()) {
                    throw Win32Error("CreatePen failed")
                }
                penCache[key] = pen
                pen
        }
    }

    private func fontFor(style: TextStyle): CPointer<Unit> {
        let pixel = renderMaxI32(1, renderToI32(style.fontSize * scaleValue))
        let weight = if (style.bold) {
            Gdi.FW_BOLD
        } else {
            Gdi.FW_NORMAL
        }
        let key = Int64(pixel) * 2 + (if (style.bold) {
            1
        } else {
            0
        })
        match (fontCache.get(key)) {
            case Some(font) => font
            case None =>
                var font = createFontFace(FONT_FACE_PRIMARY, pixel, weight)
                if (font.isNull()) {
                    font = createFontFace(FONT_FACE_FALLBACK, pixel, weight)
                }
                if (font.isNull()) {
                    font = createFontFace(FONT_FACE_LAST, pixel, weight)
                }
                if (font.isNull()) {
                    throw Win32Error("CreateFontW failed")
                }
                fontCache[key] = font
                font
        }
    }

    private func createFontFace(faceName: String, pixel: Int32, weight: UInt32): CPointer<Unit> {
        let face = toUtf16(faceName)
        let font = unsafe {
            api.createFont(
                -pixel,
                0,
                0,
                0,
                Int32(weight),
                0,
                0,
                0,
                Gdi.DEFAULT_CHARSET,
                0,
                0,
                FONT_ANTIALIASED_QUALITY,
                0,
                face
            )
        }
        freeCString(face)
        return font
    }

    private func measurementDc(): CPointer<Unit> {
        if (!measureDcHandle.isNull()) {
            return measureDcHandle
        }
        // Prefer a real screen DC: it yields device-pixel text metrics even when
        // the window back buffer has not been set up or mapped yet.
        if (let Some(getDcFn) <- api.getDc) {
            let screen = unsafe { getDcFn(CPointer<Unit>()) }
            if (!screen.isNull()) {
                measureDcHandle = screen
                measureFromScreen = true
                unsafe { api.setMapMode(screen, MM_TEXT_MM) }
                return screen
            }
        }
        let dc = unsafe { api.createCompatibleDc(CPointer<Unit>()) }
        if (dc.isNull()) {
            return CPointer<Unit>()
        }
        let bitmap = unsafe { api.createCompatibleBitmap(dc, 8, 8) }
        if (!bitmap.isNull()) {
            measureBitmap = bitmap
            unsafe { api.selectObject(dc, bitmap) }
        }
        unsafe { api.setMapMode(dc, MM_TEXT_MM) }
        measureDcHandle = dc
        return dc
    }
}
