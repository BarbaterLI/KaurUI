package kaurui.ffi

import std.collection.*

// ---------------------------------------------------------------------------
// kernel32 bootstrap
// ---------------------------------------------------------------------------

foreign {
    func LoadLibraryA(lpLibFileName: CString): CPointer<Unit>

    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CString): CPointer<UInt8>

    func FreeLibrary(hModule: CPointer<Unit>): Int32
}

public class Win32Error <: Exception {
    public init(message: String) {
        super(message)
    }
}

public class NativeDll {
    public let handle: CPointer<Unit>
    private let libName: String
    private let procs: HashMap<String, CPointer<UInt8>>

    private init(name: String, hModule: CPointer<Unit>) {
        libName = name
        handle = hModule
        procs = HashMap<String, CPointer<UInt8>>()
    }

    public static func open(name: String): NativeDll {
        let cName = unsafe { LibC.mallocCString(name) }
        let hModule = unsafe { LoadLibraryA(cName) }
        unsafe { LibC.free(cName) }
        if (hModule.isNull()) {
            throw Win32Error("failed to load DLL: ${name}")
        }
        return NativeDll(name, hModule)
    }

    public func proc(name: String): CPointer<UInt8> {
        match (tryProc(name)) {
            case Some(p) => p
            case None => throw Win32Error("failed to resolve symbol '${name}' in ${libName}")
        }
    }

    public func tryProc(name: String): Option<CPointer<UInt8>> {
        match (procs.get(name)) {
            case Some(p) => Some(p)
            case None =>
                let cName = unsafe { LibC.mallocCString(name) }
                let p = unsafe { GetProcAddress(handle, cName) }
                unsafe { LibC.free(cName) }
                if (p.isNull()) {
                    None
                } else {
                    procs[name] = p
                    Some(p)
                }
        }
    }
}

public class Libs {
    private static var user32Dll: Option<NativeDll> = None
    private static var gdi32Dll: Option<NativeDll> = None
    private static var kernel32Dll: Option<NativeDll> = None

    public static func user32(): NativeDll {
        if (let Some(d) <- user32Dll) {
            return d
        }
        let d = NativeDll.open("user32.dll")
        user32Dll = Some(d)
        return d
    }

    public static func gdi32(): NativeDll {
        if (let Some(d) <- gdi32Dll) {
            return d
        }
        let d = NativeDll.open("gdi32.dll")
        gdi32Dll = Some(d)
        return d
    }

    public static func kernel32(): NativeDll {
        if (let Some(d) <- kernel32Dll) {
            return d
        }
        let d = NativeDll.open("kernel32.dll")
        kernel32Dll = Some(d)
        return d
    }
}

// ---------------------------------------------------------------------------
// C structures
// ---------------------------------------------------------------------------

@C
public struct WinPoint {
    public var x: Int32 = 0
    public var y: Int32 = 0
}

@C
public struct WinRect {
    public var left: Int32 = 0
    public var top: Int32 = 0
    public var right: Int32 = 0
    public var bottom: Int32 = 0
}

@C
public struct WinSize {
    public var cx: Int32 = 0
    public var cy: Int32 = 0
}

@C
public struct MinMaxInfo {
    public var ptReserved: WinPoint = WinPoint()
    public var ptMaxSize: WinPoint = WinPoint()
    public var ptMaxPosition: WinPoint = WinPoint()
    public var ptMinTrackSize: WinPoint = WinPoint()
    public var ptMaxTrackSize: WinPoint = WinPoint()
}

@C
public struct WinMsg {
    public var hwnd: CPointer<Unit> = CPointer<Unit>()
    public var message: UInt32 = 0
    public var wParam: UInt64 = 0
    public var lParam: Int64 = 0
    public var time: UInt32 = 0
    public var pt: WinPoint = WinPoint()
    public var lPrivate: UInt32 = 0
}

@C
public struct PaintStruct {
    public var hdc: CPointer<Unit> = CPointer<Unit>()
    public var fErase: Int32 = 0
    public var rcPaint: WinRect = WinRect()
    public var fRestore: Int32 = 0
    public var fIncUpdate: Int32 = 0
    public var rgbReserved: VArray<UInt8, $32> = VArray<UInt8, $32>(repeat: 0)
}

@C
public struct WndClassEx {
    public var cbSize: UInt32 = 0
    public var style: UInt32 = 0
    public var lpfnWndProc: CFunc<(CPointer<Unit>, UInt32, UInt64, Int64) -> Int64> = CFunc<(CPointer<Unit>, UInt32,
            UInt64, Int64) -> Int64>(CPointer<Unit>())
    public var cbClsExtra: Int32 = 0
    public var cbWndExtra: Int32 = 0
    public var hInstance: CPointer<Unit> = CPointer<Unit>()
    public var hIcon: CPointer<Unit> = CPointer<Unit>()
    public var hCursor: CPointer<Unit> = CPointer<Unit>()
    public var hbrBackground: CPointer<Unit> = CPointer<Unit>()
    public var lpszMenuName: CString = CString(CPointer<UInt8>())
    public var lpszClassName: CString = CString(CPointer<UInt8>())
    public var hIconSm: CPointer<Unit> = CPointer<Unit>()
}

@C
public struct BitmapInfoHeader {
    public var biSize: UInt32 = 0
    public var biWidth: Int32 = 0
    public var biHeight: Int32 = 0
    public var biPlanes: UInt16 = 0
    public var biBitCount: UInt16 = 0
    public var biCompression: UInt32 = 0
    public var biSizeImage: UInt32 = 0
    public var biXPelsPerMeter: Int32 = 0
    public var biYPelsPerMeter: Int32 = 0
    public var biClrUsed: UInt32 = 0
    public var biClrImportant: UInt32 = 0
}

@C
public struct RgbQuad {
    public var rgbBlue: UInt8 = 0
    public var rgbGreen: UInt8 = 0
    public var rgbRed: UInt8 = 0
    public var rgbReserved: UInt8 = 0
}

@C
public struct BitmapInfo {
    public var bmiHeader: BitmapInfoHeader = BitmapInfoHeader()
    public var bmiColors: RgbQuad = RgbQuad()
}

// ---------------------------------------------------------------------------
// Win32 constants
// ---------------------------------------------------------------------------

public class Cs {
    public static let CS_HREDRAW: UInt32 = 0x0002
    public static let CS_VREDRAW: UInt32 = 0x0004
    public static let CS_DBLCLKS: UInt32 = 0x0008
}

public class Ws {
    public static let WS_OVERLAPPED: UInt32 = 0x00000000
    public static let WS_POPUP: UInt32 = 0x80000000
    public static let WS_CHILD: UInt32 = 0x40000000
    public static let WS_CLIPSIBLINGS: UInt32 = 0x04000000
    public static let WS_CLIPCHILDREN: UInt32 = 0x02000000
    public static let WS_VISIBLE: UInt32 = 0x10000000
    public static let WS_DISABLED: UInt32 = 0x08000000
    public static let WS_BORDER: UInt32 = 0x00800000
    public static let WS_CAPTION: UInt32 = 0x00C00000
    public static let WS_TABSTOP: UInt32 = 0x00010000
    public static let WS_MINIMIZEBOX: UInt32 = 0x00020000
    public static let WS_MAXIMIZEBOX: UInt32 = 0x00010000
    public static let WS_THICKFRAME: UInt32 = 0x00040000
    public static let WS_SYSMENU: UInt32 = 0x00080000
    public static let WS_OVERLAPPEDWINDOW: UInt32 = 0x00CF0000
}

public class Ex {
    public static let WS_EX_TOPMOST: UInt32 = 0x00000008
    public static let WS_EX_ACCEPTFILES: UInt32 = 0x00000010
    public static let WS_EX_TRANSPARENT: UInt32 = 0x00000020
    public static let WS_EX_TOOLWINDOW: UInt32 = 0x00000080
    public static let WS_EX_APPWINDOW: UInt32 = 0x00040000
    public static let WS_EX_LAYERED: UInt32 = 0x00080000
    public static let WS_EX_NOACTIVATE: UInt32 = 0x08000000
    public static let WS_EX_OVERLAPPEDWINDOW: UInt32 = 0x00000300
}

public class Msg {
    public static let WM_CREATE: UInt32 = 0x0001
    public static let WM_DESTROY: UInt32 = 0x0002
    public static let WM_SIZE: UInt32 = 0x0005
    public static let WM_SETFOCUS: UInt32 = 0x0007
    public static let WM_KILLFOCUS: UInt32 = 0x0008
    public static let WM_PAINT: UInt32 = 0x000F
    public static let WM_CLOSE: UInt32 = 0x0010
    public static let WM_QUIT: UInt32 = 0x0012
    public static let WM_SETCURSOR: UInt32 = 0x0020
    public static let WM_GETMINMAXINFO: UInt32 = 0x0024
    public static let WM_KEYDOWN: UInt32 = 0x0100
    public static let WM_KEYUP: UInt32 = 0x0101
    public static let WM_CHAR: UInt32 = 0x0102
    public static let WM_TIMER: UInt32 = 0x0113
    public static let WM_MOUSEMOVE: UInt32 = 0x0200
    public static let WM_LBUTTONDOWN: UInt32 = 0x0201
    public static let WM_LBUTTONUP: UInt32 = 0x0202
    public static let WM_LBUTTONDBLCLK: UInt32 = 0x0203
    public static let WM_MOUSEWHEEL: UInt32 = 0x020A
    public static let WM_CAPTURECHANGED: UInt32 = 0x0215
    public static let WM_MOUSELEAVE: UInt32 = 0x02A3
}

public class Vk {
    public static let VK_BACK: UInt32 = 0x08
    public static let VK_TAB: UInt32 = 0x09
    public static let VK_RETURN: UInt32 = 0x0D
    public static let VK_ESCAPE: UInt32 = 0x1B
    public static let VK_SPACE: UInt32 = 0x20
    public static let VK_END: UInt32 = 0x23
    public static let VK_HOME: UInt32 = 0x24
    public static let VK_LEFT: UInt32 = 0x25
    public static let VK_UP: UInt32 = 0x26
    public static let VK_RIGHT: UInt32 = 0x27
    public static let VK_DOWN: UInt32 = 0x28
    public static let VK_DELETE: UInt32 = 0x2E
}

public class Sw {
    public static let SW_SHOWNORMAL: UInt32 = 1
    public static let SW_SHOW: UInt32 = 5
}

public class Gdi {
    public static let TRANSPARENT: UInt32 = 1
    public static let PS_SOLID: UInt32 = 0
    public static let DEFAULT_CHARSET: UInt32 = 1
    public static let FW_NORMAL: UInt32 = 400
    public static let FW_BOLD: UInt32 = 700
    public static let SRCCOPY: UInt32 = 0x00CC0020
}

public class ColorRef {
    public static let BLACK: UInt32 = 0x00000000
    public static let WHITE: UInt32 = 0x00FFFFFF
    public static let RED: UInt32 = 0x000000FF
    public static let GREEN: UInt32 = 0x0000FF00
    public static let BLUE: UInt32 = 0x00FF0000
}

// ---------------------------------------------------------------------------
// UTF-16 helpers
// ---------------------------------------------------------------------------

public func toUtf16(s: String): CString {
    var units: Int64 = 0
    for (r in s.runes()) {
        if (UInt32(r) > 0xFFFF) {
            units += 2
        } else {
            units += 1
        }
    }
    let buf = unsafe { LibC.malloc<UInt8>(count: (units + 1) * 2) }
    var i: Int64 = 0
    for (r in s.runes()) {
        let cp = UInt32(r)
        if (cp <= 0xFFFF) {
            unsafe { buf.write(i, UInt8(cp & 0xFF)) }
            unsafe { buf.write(i + 1, UInt8((cp >> 8) & 0xFF)) }
            i += 2
        } else {
            let v = cp - 0x10000
            let hi: UInt32 = 0xD800 + (v >> 10)
            let lo: UInt32 = 0xDC00 + (v & 0x3FF)
            unsafe { buf.write(i, UInt8(hi & 0xFF)) }
            unsafe { buf.write(i + 1, UInt8((hi >> 8) & 0xFF)) }
            unsafe { buf.write(i + 2, UInt8(lo & 0xFF)) }
            unsafe { buf.write(i + 3, UInt8((lo >> 8) & 0xFF)) }
            i += 4
        }
    }
    unsafe { buf.write(i, UInt8(0)) }
    unsafe { buf.write(i + 1, UInt8(0)) }
    return CString(buf)
}

public func fromUtf16(p: CPointer<UInt16>): String {
    if (p.isNull()) {
        return ""
    }
    let runes = ArrayList<Rune>()
    var i: Int64 = 0
    var ended = false
    while (!ended) {
        let cu = unsafe { p.read(i) }
        if (cu == 0) {
            ended = true
        } else if (cu >= 0xD800 && cu <= 0xDBFF) {
            let lo = unsafe { p.read(i + 1) }
            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                let cp: UInt32 = 0x10000 + ((UInt32(cu) - 0xD800) << 10) + (UInt32(lo) - 0xDC00)
                runes.add(Rune(cp))
                i += 2
            } else {
                runes.add(Rune(UInt32(0xFFFD)))
                i += 1
            }
        } else if (cu >= 0xDC00 && cu <= 0xDFFF) {
            runes.add(Rune(UInt32(0xFFFD)))
            i += 1
        } else {
            runes.add(Rune(UInt32(cu)))
            i += 1
        }
    }
    return String(runes.toArray())
}

public func freeCString(c: CString): Unit {
    unsafe { LibC.free(c) }
}

public func colorRef(r: UInt8, g: UInt8, b: UInt8): UInt32 {
    return UInt32(r) | (UInt32(g) << 8) | (UInt32(b) << 16)
}

// ---------------------------------------------------------------------------
// Diagnostics
// ---------------------------------------------------------------------------

func expectSize(name: String, actual: UIntNative, expected: UIntNative): Unit {
    if (actual != expected) {
        throw Win32Error("layout mismatch: ${name} is ${actual} bytes, expected ${expected}")
    }
}

public func layoutSelfCheck(): Unit {
    expectSize("POINT", sizeOf<WinPoint>(), 8)
    expectSize("RECT", sizeOf<WinRect>(), 16)
    expectSize("SIZE", sizeOf<WinSize>(), 8)
    expectSize("MINMAXINFO", sizeOf<MinMaxInfo>(), 40)
    expectSize("MSG", sizeOf<WinMsg>(), 48)
    expectSize("PAINTSTRUCT", sizeOf<PaintStruct>(), 72)
    expectSize("WNDCLASSEXW", sizeOf<WndClassEx>(), 80)
    expectSize("BITMAPINFOHEADER", sizeOf<BitmapInfoHeader>(), 40)
}

func hexAddress(p: CPointer<UInt8>): String {
    var v = p.toUIntNative()
    if (v == 0) {
        return "0x0"
    }
    let digits = "0123456789ABCDEF"
    var out = ""
    while (v > 0) {
        let d = Int64(v % 16)
        out = digits[d..(d + 1)] + out
        v = v / 16
    }
    return "0x" + out
}

public func smokeCheck(): String {
    let createWindow = Libs.user32().proc("CreateWindowExW")
    let createDc = Libs.gdi32().proc("CreateDCW")
    let tickCount = Libs.kernel32().proc("GetTickCount64")
    return "user32!CreateWindowExW=${hexAddress(createWindow)}, gdi32!CreateDCW=${hexAddress(createDc)}, kernel32!GetTickCount64=${hexAddress(tickCount)}"
}
