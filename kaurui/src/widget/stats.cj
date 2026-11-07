package kaurui.widget

// ---------------------------------------------------------------------------
// LayoutStats: process-wide counters for measurement work done by containers.
// measureCalls counts cache misses that actually walked children; cacheHits
// counts measure() calls that returned a cached size.
// ---------------------------------------------------------------------------

public class LayoutStats {
    public static var measureCalls: Int64 = 0
    public static var cacheHits: Int64 = 0
    // Children whose paint was skipped because their subtree lies entirely
    // outside the renderer's current clip rectangle.
    public static var paintSkips: Int64 = 0

    public static func reset(): Unit {
        measureCalls = 0
        cacheHits = 0
        paintSkips = 0
    }
}
