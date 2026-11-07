package kaurui.platform

import std.collection.*
import kaurui.ffi.*
import kaurui.layout.*

public let MODULE_NAME: String = "kaurui.platform"

// ---------------------------------------------------------------------------
// constants that are not covered by kaurui.ffi
// ---------------------------------------------------------------------------

let WM_RBUTTONDOWN: UInt32 = 0x0204
let WM_RBUTTONUP: UInt32 = 0x0205
let WM_MBUTTONDOWN: UInt32 = 0x0207
let WM_MBUTTONUP: UInt32 = 0x0208
let VK_SHIFT_CODE: Int32 = 0x10
let VK_CONTROL_CODE: Int32 = 0x11
let WM_SETCURSOR: UInt32 = 0x0020
let HTCLIENT_CODE: UInt64 = 1
let IDC_ARROW_RESOURCE: Int64 = 32512
let IDC_HAND_RESOURCE: Int64 = 32649
let TME_LEAVE: UInt32 = 0x00000002
let DPI_PER_MONITOR_AWARE_V2_OFFSET: Int64 = 4
let DEFAULT_DPI: UInt32 = 96
let WINDOW_CLASS_NAME: String = "KaurUIWindow"

// ---------------------------------------------------------------------------
// Win32 structures that are not covered by kaurui.ffi
// ---------------------------------------------------------------------------

@C
struct TrackMouseEventData {
    var cbSize: UInt32 = 0
    var dwFlags: UInt32 = 0
    var hwndTrack: CPointer<Unit> = CPointer<Unit>()
    var dwHoverTime: UInt32 = 0
}

// ---------------------------------------------------------------------------
// public contract
// ---------------------------------------------------------------------------

public struct WindowConfig {
    public var title: String = "KaurUI"
    public var width: Int64 = 800
    public var height: Int64 = 600
    public var resizable: Bool = true
    public var minWidth: Int64 = 0
    public var minHeight: Int64 = 0
}

public enum MouseButton {
    | Left
    | Right
    | Middle
}

public struct MouseEvent {
    public var x: Float32 = 0.0f32
    public var y: Float32 = 0.0f32
    public var button: MouseButton = MouseButton.Left
}

public struct KeyEvent {
    public var vk: UInt32 = 0
    public var ctrl: Bool = false
    public var shift: Bool = false
}

public struct CharEvent {
    public var ch: UInt32 = 0
}

public interface WindowHandler {
    func onPaint(hdc: CPointer<Unit>, clientSize: Size, scale: Float32): Unit
    func onResize(clientSize: Size, scale: Float32): Unit
    func onMouseMove(e: MouseEvent): Unit
    func onMouseDown(e: MouseEvent): Unit
    func onMouseUp(e: MouseEvent): Unit
    func onMouseLeave(): Unit
    func onWheel(delta: Float32, x: Float32, y: Float32): Unit
    func onKeyDown(e: KeyEvent): Unit
    func onChar(e: CharEvent): Unit
    func onDeactivate(): Unit
    func onTimer(id: UInt64): Unit
    func onClose(): Bool
    func wantsHandCursor(x: Float32, y: Float32): Bool
}

// ---------------------------------------------------------------------------
// process/global state
// ---------------------------------------------------------------------------

let WINDOW_REGISTRY: HashMap<IntNative, Window> = HashMap<IntNative, Window>()
var windowClassRegistered: Bool = false

// ---------------------------------------------------------------------------
// top level C callback
// ---------------------------------------------------------------------------

@C
func kaurWndProc(hwnd: CPointer<Unit>, message: UInt32, wParam: UInt64, lParam: Int64): Int64 {
    try {
        if (let Some(window) <- WINDOW_REGISTRY.get(IntNative(hwnd.toUIntNative()))) {
            return window.dispatchMessage(message, wParam, lParam)
        }
        return defWindowProc(hwnd, message, wParam, lParam)
    } catch (e: Exception) {
        // never let a Cangjie exception cross the C boundary
        println("KaurUI platform: window callback failed: ${e.message}")
        return 0
    }
}

func defWindowProc(hwnd: CPointer<Unit>, message: UInt32, wParam: UInt64, lParam: Int64): Int64 {
    try {
        let f = CFunc<(CPointer<Unit>, UInt32, UInt64, Int64) -> Int64>(Libs.user32().proc("DefWindowProcW"))
        return unsafe { f(hwnd, message, wParam, lParam) }
    } catch (e: Exception) {
        0
    }
}

// ---------------------------------------------------------------------------
// DPI helpers
// ---------------------------------------------------------------------------

public func enableDpiAwareness(): Unit {
    try {
        if (let Some(p) <- Libs.user32().tryProc("SetProcessDpiAwarenessContext")) {
            let f = CFunc<(CPointer<Unit>) -> Int32>(p)
            let context = CPointer<Unit>(unsafe { CPointer<UInt8>() - DPI_PER_MONITOR_AWARE_V2_OFFSET })
            if (unsafe { f(context) } != 0) {
                return
            }
        }
    } catch (e: Exception) {
        // fall through to the legacy API
    }
    try {
        if (let Some(p) <- Libs.user32().tryProc("SetProcessDPIAware")) {
            let f = CFunc<() -> Int32>(p)
            unsafe { f() }
        }
    } catch (e: Exception) {
        // DPI awareness is best effort, never fail window creation because of it
    }
}

func scaleOfDpi(dpi: UInt32): Float32 {
    if (dpi == 0) {
        return 1.0f32
    }
    Float32(dpi) / Float32(DEFAULT_DPI)
}

func systemScale(): Float32 {
    try {
        if (let Some(p) <- Libs.user32().tryProc("GetDpiForSystem")) {
            let f = CFunc<() -> UInt32>(p)
            return scaleOfDpi(unsafe { f() })
        }
    } catch (e: Exception) {
        // ignore and fall back below
    }
    1.0f32
}

func dpiScaleForWindow(hwnd: CPointer<Unit>): Float32 {
    try {
        if (let Some(p) <- Libs.user32().tryProc("GetDpiForWindow")) {
            let f = CFunc<(CPointer<Unit>) -> UInt32>(p)
            let dpi = unsafe { f(hwnd) }
            if (dpi > 0) {
                return scaleOfDpi(dpi)
            }
        }
    } catch (e: Exception) {
        // ignore and fall back below
    }
    1.0f32
}

// ---------------------------------------------------------------------------
// window class registration
// ---------------------------------------------------------------------------

func ensureWindowClassRegistered(): Unit {
    if (windowClassRegistered) {
        return
    }
    let hInstance = moduleHandle()
    let className = toUtf16(WINDOW_CLASS_NAME)
    var wc = WndClassEx()
    wc.cbSize = UInt32(sizeOf<WndClassEx>())
    wc.style = Cs.CS_HREDRAW
    wc.lpfnWndProc = kaurWndProc
    wc.hInstance = hInstance
    wc.lpszClassName = className
    let f = CFunc<(CPointer<WndClassEx>) -> UInt16>(Libs.user32().proc("RegisterClassExW"))
    let atom = unsafe { f(inout wc) }
    freeCString(className)
    if (atom == 0) {
        throw Win32Error("failed to register the KaurUI window class")
    }
    windowClassRegistered = true
}

func moduleHandle(): CPointer<Unit> {
    let f = CFunc<(CString) -> CPointer<Unit>>(Libs.kernel32().proc("GetModuleHandleW"))
    unsafe { f(CString(CPointer<UInt8>())) }
}

func windowStyle(resizable: Bool): UInt32 {
    if (resizable) {
        Ws.WS_OVERLAPPEDWINDOW
    } else {
        Ws.WS_CAPTION | Ws.WS_SYSMENU | Ws.WS_MINIMIZEBOX
    }
}

func adjustedWindowRect(rc: WinRect, style: UInt32, exStyle: UInt32): WinRect {
    var r = rc
    let f = CFunc<(CPointer<WinRect>, UInt32, Int32, UInt32) -> Int32>(Libs.user32().proc("AdjustWindowRectEx"))
    unsafe { f(inout r, style, 0, exStyle) }
    r
}

// ---------------------------------------------------------------------------
// event decoding helpers
// ---------------------------------------------------------------------------

func keyEventFrom(wParam: UInt64): KeyEvent {
    let getKeyState = CFunc<(Int32) -> Int16>(Libs.user32().proc("GetKeyState"))
    let ctrlState = unsafe { getKeyState(VK_CONTROL_CODE) }
    let shiftState = unsafe { getKeyState(VK_SHIFT_CODE) }
    var e = KeyEvent()
    e.vk = UInt32(wParam)
    e.ctrl = ctrlState < 0
    e.shift = shiftState < 0
    e
}

// Win32 packs two signed 16-bit values into a 32/64-bit word. Cangjie checked
// casts reject out-of-range constants, so decode with arithmetic instead.
func signedWordFromInt(v: Int64): Int32 {
    let raw = v & 0xFFFF
    if (raw >= 0x8000) {
        Int32(raw) - 65536
    } else {
        Int32(raw)
    }
}

func signedWordFromUInt(v: UInt64): Int32 {
    let raw = v & 0xFFFF
    if (raw >= 0x8000) {
        Int32(raw) - 65536
    } else {
        Int32(raw)
    }
}

// ---------------------------------------------------------------------------
// Window
// ---------------------------------------------------------------------------

public class Window {
    private let handler: WindowHandler
    private let hwndValue: CPointer<Unit>
    private let minWidthValue: Int64
    private let minHeightValue: Int64
    private var scaleValue: Float32
    private var trackingMouse: Bool = false

    init(handler: WindowHandler, hwnd: CPointer<Unit>, scale: Float32, minWidth: Int64, minHeight: Int64) {
        this.handler = handler
        this.hwndValue = hwnd
        this.minWidthValue = minWidth
        this.minHeightValue = minHeight
        this.scaleValue = scale
        this.trackingMouse = false
    }

    public static func create(config: WindowConfig, handler: WindowHandler): Window {
        enableDpiAwareness()
        ensureWindowClassRegistered()
        let style = windowStyle(config.resizable)
        let sysScale = systemScale()
        var clientRect = WinRect()
        clientRect.right = Int32(Float32(config.width) * sysScale)
        clientRect.bottom = Int32(Float32(config.height) * sysScale)
        let rect = adjustedWindowRect(clientRect, style, 0)
        let cTitle = toUtf16(config.title)
        let cClass = toUtf16(WINDOW_CLASS_NAME)
        let hInstance = moduleHandle()
        let createFn = CFunc<(UInt32, CString, CString, UInt32, Int32, Int32, Int32, Int32, CPointer<Unit>, CPointer<Unit>,
                CPointer<Unit>, CPointer<Unit>) -> CPointer<Unit>>(Libs.user32().proc("CreateWindowExW"))
        let hwnd = unsafe {
            createFn(0, cClass, cTitle, style, 0, 0, rect.right - rect.left, rect.bottom - rect.top, CPointer<Unit>(),
                CPointer<Unit>(), hInstance, CPointer<Unit>())
        }
        freeCString(cTitle)
        freeCString(cClass)
        if (hwnd.isNull()) {
            throw Win32Error("CreateWindowExW failed for window '${config.title}'")
        }
        let scale = dpiScaleForWindow(hwnd)
        let window = Window(handler, hwnd, scale, config.minWidth, config.minHeight)
        WINDOW_REGISTRY[IntNative(hwnd.toUIntNative())] = window
        window
    }

    public func show(): Unit {
        let showWindow = CFunc<(CPointer<Unit>, UInt32) -> Int32>(Libs.user32().proc("ShowWindow"))
        let updateWindow = CFunc<(CPointer<Unit>) -> Int32>(Libs.user32().proc("UpdateWindow"))
        unsafe { showWindow(hwndValue, Sw.SW_SHOW) }
        unsafe { updateWindow(hwndValue) }
    }

    public func close(): Unit {
        try {
            let destroyWindow = CFunc<(CPointer<Unit>) -> Int32>(Libs.user32().proc("DestroyWindow"))
            unsafe { destroyWindow(hwndValue) }
        } catch (e: Exception) {
            // closing an already destroyed window is a no-op
        }
    }

    public func invalidate(rect: Rect): Unit {
        let s = scaleValue
        var r = WinRect()
        r.left = Int32(rect.x * s)
        r.top = Int32(rect.y * s)
        r.right = Int32((rect.x + rect.width) * s)
        r.bottom = Int32((rect.y + rect.height) * s)
        let invalidateRect = CFunc<(CPointer<Unit>, CPointer<WinRect>, Int32) -> Int32>(
            Libs.user32().proc("InvalidateRect"))
        unsafe { invalidateRect(hwndValue, inout r, 0) }
    }

    public func invalidateAll(): Unit {
        let invalidateRect = CFunc<(CPointer<Unit>, CPointer<WinRect>, Int32) -> Int32>(
            Libs.user32().proc("InvalidateRect"))
        unsafe { invalidateRect(hwndValue, CPointer<WinRect>(), 0) }
    }

    public func clientSize(): Size {
        logicalClientSize()
    }

    public func scale(): Float32 {
        scaleValue
    }

    public func setTitle(title: String): Unit {
        let cTitle = toUtf16(title)
        let setWindowText = CFunc<(CPointer<Unit>, CString) -> Int32>(Libs.user32().proc("SetWindowTextW"))
        unsafe { setWindowText(hwndValue, cTitle) }
        freeCString(cTitle)
    }

    public func hwnd(): CPointer<Unit> {
        hwndValue
    }

    public func setTimer(id: UInt64, intervalMs: UInt32): Unit {
        let setTimerFn = CFunc<(CPointer<Unit>, UIntNative, UInt32, CPointer<Unit>) -> UIntNative>(
            Libs.user32().proc("SetTimer"))
        unsafe { setTimerFn(hwndValue, UIntNative(id), intervalMs, CPointer<Unit>()) }
    }

    public func killTimer(id: UInt64): Unit {
        let killTimerFn = CFunc<(CPointer<Unit>, UIntNative) -> Int32>(Libs.user32().proc("KillTimer"))
        unsafe { killTimerFn(hwndValue, UIntNative(id)) }
    }

    // -----------------------------------------------------------------------
    // internal plumbing
    // -----------------------------------------------------------------------

    func dispatchMessage(message: UInt32, wParam: UInt64, lParam: Int64): Int64 {
        if (message == Msg.WM_PAINT) {
            handlePaint()
            return 0
        } else if (message == Msg.WM_GETMINMAXINFO) {
            handleGetMinMaxInfo(lParam)
            return 0
        } else if (message == Msg.WM_KILLFOCUS) {
            handler.onDeactivate()
            return 0
        } else if (message == Msg.WM_SIZE) {
            handler.onResize(logicalClientSize(), scaleValue)
            invalidateAll()
            return 0
        } else if (message == WM_SETCURSOR) {
            return handleSetCursor(wParam, lParam)
        } else if (message == Msg.WM_MOUSEMOVE) {
            handler.onMouseMove(mouseEventFrom(lParam, MouseButton.Left))
            if (!trackingMouse) {
                trackingMouse = true
                requestMouseLeaveTracking()
            }
            return 0
        } else if (message == Msg.WM_LBUTTONDOWN) {
            handler.onMouseDown(mouseEventFrom(lParam, MouseButton.Left))
            return 0
        } else if (message == Msg.WM_LBUTTONUP) {
            handler.onMouseUp(mouseEventFrom(lParam, MouseButton.Left))
            return 0
        } else if (message == WM_RBUTTONDOWN) {
            handler.onMouseDown(mouseEventFrom(lParam, MouseButton.Right))
            return 0
        } else if (message == WM_RBUTTONUP) {
            handler.onMouseUp(mouseEventFrom(lParam, MouseButton.Right))
            return 0
        } else if (message == WM_MBUTTONDOWN) {
            handler.onMouseDown(mouseEventFrom(lParam, MouseButton.Middle))
            return 0
        } else if (message == WM_MBUTTONUP) {
            handler.onMouseUp(mouseEventFrom(lParam, MouseButton.Middle))
            return 0
        } else if (message == Msg.WM_MOUSELEAVE) {
            trackingMouse = false
            handler.onMouseLeave()
            return 0
        } else if (message == Msg.WM_MOUSEWHEEL) {
            handleWheel(wParam, lParam)
            return 0
        } else if (message == Msg.WM_KEYDOWN) {
            handler.onKeyDown(keyEventFrom(wParam))
            return 0
        } else if (message == Msg.WM_CHAR) {
            var e = CharEvent()
            e.ch = UInt32(wParam)
            handler.onChar(e)
            return 0
        } else if (message == Msg.WM_TIMER) {
            handler.onTimer(wParam)
            return 0
        } else if (message == Msg.WM_CLOSE) {
            if (handler.onClose()) {
                let destroyWindow = CFunc<(CPointer<Unit>) -> Int32>(Libs.user32().proc("DestroyWindow"))
                unsafe { destroyWindow(hwndValue) }
            }
            return 0
        } else if (message == Msg.WM_DESTROY) {
            WINDOW_REGISTRY.remove(IntNative(hwndValue.toUIntNative()))
            let postQuitMessage = CFunc<(Int32) -> Unit>(Libs.user32().proc("PostQuitMessage"))
            unsafe { postQuitMessage(0) }
            return 0
        }
        defWindowProc(hwndValue, message, wParam, lParam)
    }

    // WM_GETMINMAXINFO carries a pointer to a MINMAXINFO owned by Windows; only
    // the minimum tracking size is overridden, everything else stays default.
    func handleGetMinMaxInfo(lParam: Int64): Unit {
        if (lParam == 0) {
            return
        }
        let info = CPointer<MinMaxInfo>(unsafe { CPointer<UInt8>() + lParam })
        var mmi = unsafe { info.read() }
        if (minWidthValue > 0) {
            mmi.ptMinTrackSize.x = Int32(Float32(minWidthValue) * scaleValue)
        }
        if (minHeightValue > 0) {
            mmi.ptMinTrackSize.y = Int32(Float32(minHeightValue) * scaleValue)
        }
        unsafe { info.write(mmi) }
    }

    func handlePaint(): Unit {
        let beginPaint = CFunc<(CPointer<Unit>, CPointer<PaintStruct>) -> CPointer<Unit>>(
            Libs.user32().proc("BeginPaint"))
        let endPaint = CFunc<(CPointer<Unit>, CPointer<PaintStruct>) -> Int32>(Libs.user32().proc("EndPaint"))
        let ps = unsafe { LibC.malloc<PaintStruct>(count: 1) }
        let hdc = unsafe { beginPaint(hwndValue, ps) }
        try {
            handler.onPaint(hdc, logicalClientSize(), scaleValue)
        } finally {
            unsafe { endPaint(hwndValue, ps) }
            unsafe { LibC.free(ps) }
        }
    }

    func logicalClientSize(): Size {
        var rc = WinRect()
        let getClientRect = CFunc<(CPointer<Unit>, CPointer<WinRect>) -> Int32>(Libs.user32().proc("GetClientRect"))
        unsafe { getClientRect(hwndValue, inout rc) }
        Size(Float32(rc.right) / scaleValue, Float32(rc.bottom) / scaleValue)
    }

    func mouseEventFrom(lParam: Int64, button: MouseButton): MouseEvent {
        var e = MouseEvent()
        e.x = Float32(lParam & 0xFFFF) / scaleValue
        e.y = Float32((lParam >> 16) & 0xFFFF) / scaleValue
        e.button = button
        e
    }

    func handleWheel(wParam: UInt64, lParam: Int64): Unit {
        let delta = Float32(signedWordFromUInt((wParam >> 16) & 0xFFFF)) / 120.0f32
        // WM_MOUSEWHEEL carries screen coordinates; widgets work in client space.
        var pt = WinPoint()
        pt.x = signedWordFromInt(lParam)
        pt.y = signedWordFromInt(lParam >> 16)
        let screenToClient = CFunc<(CPointer<Unit>, CPointer<WinPoint>) -> Int32>(Libs.user32().proc("ScreenToClient"))
        unsafe { screenToClient(hwndValue, inout pt) }
        handler.onWheel(delta, Float32(pt.x) / scaleValue, Float32(pt.y) / scaleValue)
    }

    func requestMouseLeaveTracking(): Unit {
        var track = TrackMouseEventData()
        track.cbSize = UInt32(sizeOf<TrackMouseEventData>())
        track.dwFlags = TME_LEAVE
        track.hwndTrack = hwndValue
        let trackMouseEvent = CFunc<(CPointer<TrackMouseEventData>) -> Int32>(Libs.user32().proc("TrackMouseEvent"))
        unsafe { trackMouseEvent(inout track) }
    }

    // -----------------------------------------------------------------------
    // cursor
    // -----------------------------------------------------------------------

    func handleSetCursor(wParam: UInt64, lParam: Int64): Int64 {
        // Only the client area belongs to the widget tree; caption and borders
        // keep the cursor supplied by DefWindowProc.
        if ((wParam & 0xFFFF) != HTCLIENT_CODE) {
            return defWindowProc(hwndValue, WM_SETCURSOR, wParam, lParam)
        }
        let p = cursorClientPosition()
        let resource = if (handler.wantsHandCursor(p.x, p.y)) {
            IDC_HAND_RESOURCE
        } else {
            IDC_ARROW_RESOURCE
        }
        let cursor = loadSystemCursor(resource)
        if (!cursor.isNull()) {
            let setCursorFn = CFunc<(CPointer<Unit>) -> CPointer<Unit>>(Libs.user32().proc("SetCursor"))
            unsafe { setCursorFn(cursor) }
        }
        // Returning non-zero tells Windows the cursor has been set already.
        1
    }

    func cursorClientPosition(): Point {
        var pt = WinPoint()
        let getCursorPos = CFunc<(CPointer<WinPoint>) -> Int32>(Libs.user32().proc("GetCursorPos"))
        unsafe { getCursorPos(inout pt) }
        let screenToClient = CFunc<(CPointer<Unit>, CPointer<WinPoint>) -> Int32>(Libs.user32().proc("ScreenToClient"))
        unsafe { screenToClient(hwndValue, inout pt) }
        Point(Float32(pt.x) / scaleValue, Float32(pt.y) / scaleValue)
    }

    // LoadCursorW takes an LPCWSTR; system cursors use MAKEINTRESOURCE-style
    // integer IDs. Cangjie has no pointer-from-integer constructor, so the
    // address is built with pointer arithmetic over a null pointer.
    func loadSystemCursor(resourceId: Int64): CPointer<Unit> {
        let loadCursorFn = CFunc<(CPointer<Unit>, CPointer<Unit>) -> CPointer<Unit>>(Libs.user32().proc("LoadCursorW"))
        let id = CPointer<Unit>(unsafe { CPointer<UInt8>() + resourceId })
        unsafe { loadCursorFn(CPointer<Unit>(), id) }
    }
}

// ---------------------------------------------------------------------------
// EventLoop
// ---------------------------------------------------------------------------

public class EventLoop {
    public static func run(window: Window): Int64 {
        let getMessage = CFunc<(CPointer<WinMsg>, CPointer<Unit>, UInt32, UInt32) -> Int32>(
            Libs.user32().proc("GetMessageW"))
        let translateMessage = CFunc<(CPointer<WinMsg>) -> Int32>(Libs.user32().proc("TranslateMessage"))
        let dispatchMessage = CFunc<(CPointer<WinMsg>) -> Int64>(Libs.user32().proc("DispatchMessageW"))
        var msg = WinMsg()
        while (unsafe { getMessage(inout msg, CPointer<Unit>(), 0, 0) } > 0) {
            unsafe { translateMessage(inout msg) }
            unsafe { dispatchMessage(inout msg) }
        }
        if (window.hwnd().isNull()) {
            return -1
        }
        Int64(msg.wParam)
    }
}
