package kaurui.render

import kaurui.layout.*

public let MODULE_NAME: String = "kaurui.render"

// ---------------------------------------------------------------------------
// Public value types
// ---------------------------------------------------------------------------

public struct Color {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        this.r = r
        this.g = g
        this.b = b
        this.a = a
    }

    public static func rgb(r: UInt8, g: UInt8, b: UInt8): Color {
        Color(r, g, b, 255)
    }

    public static func rgba(r: UInt8, g: UInt8, b: UInt8, a: UInt8): Color {
        Color(r, g, b, a)
    }

    public static let WHITE: Color = Color(255, 255, 255, 255)
    public static let BLACK: Color = Color(0, 0, 0, 255)
    public static let TRANSPARENT: Color = Color(0, 0, 0, 0)
}

public struct TextStyle {
    public var fontSize: Float32
    public var bold: Bool

    public init() {
        this.fontSize = 14.0f32
        this.bold = false
    }

    public init(fontSize: Float32) {
        this.fontSize = fontSize
        this.bold = false
    }

    public init(fontSize: Float32, bold: Bool) {
        this.fontSize = fontSize
        this.bold = bold
    }
}

public enum TextAlign {
    | Left
    | Center
    | Right
}

// ---------------------------------------------------------------------------
// Image handle
// ---------------------------------------------------------------------------

public class ImageHandle {
    private let ptrValue: CPointer<Unit>
    private let widthValue: Float32
    private let heightValue: Float32

    public init(ptr: CPointer<Unit>, width: Float32, height: Float32) {
        this.ptrValue = ptr
        this.widthValue = width
        this.heightValue = height
    }

    public prop ptr: CPointer<Unit> {
        get() {
            ptrValue
        }
    }

    public prop width: Float32 {
        get() {
            widthValue
        }
    }

    public prop height: Float32 {
        get() {
            heightValue
        }
    }
}

// ---------------------------------------------------------------------------
// Renderer contract
// ---------------------------------------------------------------------------

public interface Renderer {
    func beginFrame(width: Float32, height: Float32): Unit
    func fillRect(rect: Rect, color: Color): Unit
    func fillRoundRect(rect: Rect, radius: Float32, color: Color): Unit
    func strokeRect(rect: Rect, color: Color, width: Float32): Unit
    func strokeRoundRect(rect: Rect, radius: Float32, color: Color, width: Float32): Unit
    func drawText(text: String, rect: Rect, style: TextStyle, color: Color, align: TextAlign): Unit
    func measureText(text: String, style: TextStyle): Size
    func pushClip(rect: Rect): Unit
    func popClip(): Unit
    func endFrame(): Unit
    func loadImage(path: String): Option<ImageHandle>
    func drawImage(image: ImageHandle, dst: Rect): Unit
    prop imageCacheSize: Int64
    prop drawCalls: Int64
    prop lastPaintedArea: Size
    // Topmost clip rectangle; None means no clipping (the whole frame is visible).
    // Renderers that never clip may rely on this default.
    prop currentClip: Option<Rect> {
        get() {
            None
        }
    }
}
