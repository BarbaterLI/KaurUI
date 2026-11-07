package kaurui.widget

import kaurui.layout.*
import kaurui.render.*

// ---------------------------------------------------------------------------
// ImageFit: how a bitmap is mapped into its layout bounds.
// ---------------------------------------------------------------------------

public enum ImageFit {
    | Fill
    | Contain
    | Cover
}

// ---------------------------------------------------------------------------
// Image: draws a bitmap through the renderer's image cache, falling back to a
// surface rectangle with a border when the file cannot be loaded.
// ---------------------------------------------------------------------------

public class Image <: WidgetBase {
    private let DEFAULT_WIDTH: Float32 = 120.0f32
    private let DEFAULT_HEIGHT: Float32 = 80.0f32

    private var pathValue: String
    private let widthValue: Float32
    private let heightValue: Float32
    private let fitValue: ImageFit
    private let backgroundValue: ?Color
    private var loadedValue: ?ImageHandle = None
    private var attemptedValue: Bool = false

    public init(
        path!: String,
        width!: Float32 = 0.0f32,
        height!: Float32 = 0.0f32,
        flex!: Float32 = 0.0f32,
        fit!: ImageFit = ImageFit.Fill,
        background!: ?Color = None
    ) {
        super(flex)
        pathValue = path
        widthValue = width
        heightValue = height
        fitValue = fit
        backgroundValue = background
    }

    // Maps a source bitmap of srcW x srcH into dst according to fit. Fill
    // stretches to the full box; Contain scales down (or up) to fit inside and
    // centers; Cover scales to cover the box and centers, leaving the caller to
    // clip the overflow.
    public static func fitRect(srcW: Float32, srcH: Float32, dst: Rect, fit: ImageFit): Rect {
        if (srcW <= 0.0f32 || srcH <= 0.0f32) {
            return Rect(dst.x, dst.y, dst.width, dst.height)
        }
        let scale = match (fit) {
            case ImageFit.Fill => 0.0f32
            case ImageFit.Contain => Float32.min(dst.width / srcW, dst.height / srcH)
            case ImageFit.Cover => Float32.max(dst.width / srcW, dst.height / srcH)
        }
        if (scale <= 0.0f32) {
            return Rect(dst.x, dst.y, dst.width, dst.height)
        }
        let w = srcW * scale
        let h = srcH * scale
        Rect(dst.x + (dst.width - w) * 0.5f32, dst.y + (dst.height - h) * 0.5f32, w, h)
    }

    public func setPath(p: String): Unit {
        pathValue = p
        loadedValue = None
        attemptedValue = false
        bumpVersion()
        invalidateSelf()
    }

    public func measure(c: Constraints): Size {
        let width = if (widthValue > 0.0f32) {
            widthValue
        } else {
            DEFAULT_WIDTH
        }
        let height = if (heightValue > 0.0f32) {
            heightValue
        } else {
            DEFAULT_HEIGHT
        }
        sizeValue = c.constrain(Size(width, height))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        if (!attemptedValue) {
            attemptedValue = true
            loadedValue = r.loadImage(pathValue)
        }
        match (loadedValue) {
            case Some(image) =>
                let dst = fitRect(image.width, image.height, boundsValue, fitValue)
                match (fitValue) {
                    case ImageFit.Cover =>
                        r.pushClip(boundsValue)
                        r.drawImage(image, dst)
                        r.popClip()
                    case ImageFit.Contain =>
                        match (backgroundValue) {
                            case Some(bg) => r.fillRect(boundsValue, bg)
                            case None => ()
                        }
                        r.drawImage(image, dst)
                    case ImageFit.Fill => r.drawImage(image, dst)
                }
            case None =>
                let th = themeOf()
                r.fillRect(boundsValue, th.surface)
                r.strokeRect(boundsValue, th.border, 1.0f32)
        }
    }

    public override func isClickable(): Bool {
        false
    }
}
