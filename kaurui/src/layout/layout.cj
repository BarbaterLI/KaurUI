package kaurui.layout

import std.math.*

func maxF32(a: Float32, b: Float32): Float32 {
    if (a >= b) {
        a
    } else {
        b
    }
}

func minF32(a: Float32, b: Float32): Float32 {
    if (a <= b) {
        a
    } else {
        b
    }
}

func clampF32(lower: Float32, upper: Float32, value: Float32): Float32 {
    if (value < lower) {
        lower
    } else if (value > upper) {
        upper
    } else {
        value
    }
}

func mainExtentOf(size: Size, horizontal: Bool): Float32 {
    if (horizontal) {
        size.width
    } else {
        size.height
    }
}

func crossExtentOf(size: Size, horizontal: Bool): Float32 {
    if (horizontal) {
        size.height
    } else {
        size.width
    }
}

public struct Point {
    public var x: Float32
    public var y: Float32

    public init(x: Float32, y: Float32) {
        this.x = x
        this.y = y
    }
}

public struct Size {
    public var width: Float32
    public var height: Float32

    public static let ZERO: Size = Size(0.0f32, 0.0f32)

    public init(width: Float32, height: Float32) {
        this.width = width
        this.height = height
    }

    public prop isZero: Bool {
        get() {
            width <= 0.0f32 && height <= 0.0f32
        }
    }

    public func max(other: Size): Size {
        Size(maxF32(width, other.width), maxF32(height, other.height))
    }

    public func min(other: Size): Size {
        Size(minF32(width, other.width), minF32(height, other.height))
    }
}

public struct Insets {
    public var left: Float32
    public var top: Float32
    public var right: Float32
    public var bottom: Float32

    public init(left: Float32, top: Float32, right: Float32, bottom: Float32) {
        this.left = left
        this.top = top
        this.right = right
        this.bottom = bottom
    }

    public static func all(v: Float32): Insets {
        Insets(v, v, v, v)
    }

    public static func symmetric(horizontal: Float32, vertical: Float32): Insets {
        Insets(horizontal, vertical, horizontal, vertical)
    }

    public static func zero(): Insets {
        Insets(0.0f32, 0.0f32, 0.0f32, 0.0f32)
    }
}

public struct Rect {
    public var x: Float32
    public var y: Float32
    public var width: Float32
    public var height: Float32

    public static let ZERO: Rect = Rect(0.0f32, 0.0f32, 0.0f32, 0.0f32)

    public init(x: Float32, y: Float32, width: Float32, height: Float32) {
        this.x = x
        this.y = y
        this.width = width
        this.height = height
    }

    public prop left: Float32 {
        get() {
            x
        }
    }

    public prop top: Float32 {
        get() {
            y
        }
    }

    public prop right: Float32 {
        get() {
            x + width
        }
    }

    public prop bottom: Float32 {
        get() {
            y + height
        }
    }

    public func contains(p: Point): Bool {
        p.x >= left && p.x < right && p.y >= top && p.y < bottom
    }

    public func intersect(other: Rect): Option<Rect> {
        let l = maxF32(left, other.left)
        let t = maxF32(top, other.top)
        let r = minF32(right, other.right)
        let b = minF32(bottom, other.bottom)
        if (r <= l || b <= t) {
            None
        } else {
            Rect(l, t, r - l, b - t)
        }
    }

    public func union(other: Rect): Rect {
        let l = minF32(left, other.left)
        let t = minF32(top, other.top)
        let r = maxF32(right, other.right)
        let b = maxF32(bottom, other.bottom)
        Rect(l, t, r - l, b - t)
    }

    public func inset(insets: Insets): Rect {
        Rect(
            x + insets.left,
            y + insets.top,
            width - insets.left - insets.right,
            height - insets.top - insets.bottom
        )
    }

    public func offset(dx: Float32, dy: Float32): Rect {
        Rect(x + dx, y + dy, width, height)
    }

    public func round(): Rect {
        Rect(round(x), round(y), round(width), round(height))
    }
}

public struct Constraints {
    public var minWidth: Float32
    public var maxWidth: Float32
    public var minHeight: Float32
    public var maxHeight: Float32

    public init(minWidth: Float32, maxWidth: Float32, minHeight: Float32, maxHeight: Float32) {
        this.minWidth = minWidth
        this.maxWidth = maxWidth
        this.minHeight = minHeight
        this.maxHeight = maxHeight
    }

    public static func tight(width: Float32, height: Float32): Constraints {
        Constraints(width, width, height, height)
    }

    public static func loose(maxWidth: Float32, maxHeight: Float32): Constraints {
        Constraints(0.0f32, maxWidth, 0.0f32, maxHeight)
    }

    public static func unbounded(): Constraints {
        Constraints(0.0f32, Float32.Inf, 0.0f32, Float32.Inf)
    }

    public func constrain(size: Size): Size {
        Size(
            clampF32(minWidth, maxWidth, size.width),
            clampF32(minHeight, maxHeight, size.height)
        )
    }

    public func deflate(insets: Insets): Constraints {
        let horizontal = insets.left + insets.right
        let vertical = insets.top + insets.bottom
        Constraints(
            maxF32(0.0f32, minWidth - horizontal),
            maxF32(0.0f32, maxWidth - horizontal),
            maxF32(0.0f32, minHeight - vertical),
            maxF32(0.0f32, maxHeight - vertical)
        )
    }

    public func loosen(): Constraints {
        Constraints(0.0f32, maxWidth, 0.0f32, maxHeight)
    }
}

public interface LayoutItem {
    func measure(c: Constraints): Size
    func arrange(rect: Rect): Unit
    prop size: Size
    prop flex: Float32
}

public enum CrossAlign {
    | Start
    | Center
    | End
    | Stretch
}

public enum MainAlign {
    | Start
    | Center
    | End
    | SpaceBetween
}

public enum MainAxis {
    | Horizontal
    | Vertical
}

public struct StackConfig {
    public var spacing: Float32
    public var crossAlign: CrossAlign
    public var mainAlign: MainAlign

    public init() {
        this.spacing = 0.0f32
        this.crossAlign = CrossAlign.Start
        this.mainAlign = MainAlign.Start
    }

    public init(spacing: Float32) {
        this.spacing = spacing
        this.crossAlign = CrossAlign.Start
        this.mainAlign = MainAlign.Start
    }

    public init(spacing: Float32, crossAlign: CrossAlign, mainAlign: MainAlign) {
        this.spacing = spacing
        this.crossAlign = crossAlign
        this.mainAlign = mainAlign
    }
}

public class StackLayout {
    public static func measure(
        items: Array<LayoutItem>,
        constraints: Constraints,
        axis: MainAxis,
        config: StackConfig
    ): Size {
        let n = items.size
        if (n == 0) {
            return constraints.constrain(Size(0.0f32, 0.0f32))
        }
        let childConstraints = Constraints.loose(
            maxF32(0.0f32, constraints.maxWidth),
            maxF32(0.0f32, constraints.maxHeight)
        )
        var mainSum = 0.0f32
        var crossMax = 0.0f32
        for (item in items) {
            let childSize = item.measure(childConstraints)
            match (axis) {
                case MainAxis.Horizontal =>
                    mainSum += childSize.width
                    crossMax = maxF32(crossMax, childSize.height)
                case MainAxis.Vertical =>
                    mainSum += childSize.height
                    crossMax = maxF32(crossMax, childSize.width)
            }
        }
        let spacingTotal = if (n > 1) {
            config.spacing * Float32(n - 1)
        } else {
            0.0f32
        }
        let mainSize = mainSum + spacingTotal
        let result = match (axis) {
            case MainAxis.Horizontal => Size(mainSize, crossMax)
            case MainAxis.Vertical => Size(crossMax, mainSize)
        }
        constraints.constrain(result)
    }

    public static func arrange(
        items: Array<LayoutItem>,
        rect: Rect,
        axis: MainAxis,
        config: StackConfig
    ): Unit {
        let n = items.size
        if (n == 0) {
            return
        }
        let horizontal = match (axis) {
            case MainAxis.Horizontal => true
            case MainAxis.Vertical => false
        }
        let containerMain = if (horizontal) {
            rect.width
        } else {
            rect.height
        }
        let containerCross = if (horizontal) {
            rect.height
        } else {
            rect.width
        }
        let spacingTotal = if (n > 1) {
            config.spacing * Float32(n - 1)
        } else {
            0.0f32
        }
        var fixedMain = 0.0f32
        var flexTotal = 0.0f32
        for (item in items) {
            if (item.flex > 0.0f32) {
                flexTotal += item.flex
            } else {
                fixedMain += mainExtentOf(item.size, horizontal)
            }
        }
        let remaining = maxF32(0.0f32, containerMain - fixedMain - spacingTotal)

        let mainSizes = Array<Float32>(n, repeat: 0.0f32)
        let crossSizes = Array<Float32>(n, repeat: 0.0f32)
        for (i in 0..n) {
            let item = items[i]
            if (item.flex > 0.0f32 && flexTotal > 0.0f32) {
                mainSizes[i] = remaining * item.flex / flexTotal
            } else {
                mainSizes[i] = mainExtentOf(item.size, horizontal)
            }
            crossSizes[i] = match (config.crossAlign) {
                case CrossAlign.Stretch => containerCross
                case _ => crossExtentOf(item.size, horizontal)
            }
        }

        var contentMain = 0.0f32
        for (i in 0..n) {
            contentMain += mainSizes[i]
        }

        var cursor = 0.0f32
        var gap = config.spacing
        match (config.mainAlign) {
            case MainAlign.Start => cursor = 0.0f32
            case MainAlign.Center => cursor = (containerMain - contentMain - spacingTotal) * 0.5f32
            case MainAlign.End => cursor = containerMain - contentMain - spacingTotal
            case MainAlign.SpaceBetween =>
                if (n > 1) {
                    gap = (containerMain - contentMain) / Float32(n - 1)
                } else {
                    gap = 0.0f32
                }
                cursor = 0.0f32
        }

        for (i in 0..n) {
            let item = items[i]
            let mainSize = mainSizes[i]
            let crossSize = crossSizes[i]
            var crossPos = 0.0f32
            match (config.crossAlign) {
                case CrossAlign.Start => crossPos = 0.0f32
                case CrossAlign.Center => crossPos = (containerCross - crossSize) * 0.5f32
                case CrossAlign.End => crossPos = containerCross - crossSize
                case CrossAlign.Stretch => crossPos = 0.0f32
            }
            let childRect = if (horizontal) {
                Rect(rect.x + cursor, rect.y + crossPos, mainSize, crossSize)
            } else {
                Rect(rect.x + crossPos, rect.y + cursor, crossSize, mainSize)
            }
            item.arrange(childRect)
            cursor += mainSize
            if (i < n - 1) {
                cursor += gap
            }
        }
    }
}
