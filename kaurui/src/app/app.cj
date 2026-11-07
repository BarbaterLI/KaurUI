package kaurui.app

import kaurui.layout.*
import kaurui.platform.*
import kaurui.render.*
import kaurui.widget.*

public let MODULE_NAME: String = "kaurui.app"
let TAB_VK: UInt32 = 0x09

// ---------------------------------------------------------------------------
// SystemClipboardAdapter: bridges the widget Clipboard contract to the Win32
// clipboard. When the system clipboard is unavailable the in-process
// MemoryClipboard keeps copy/paste working inside the app.
// ---------------------------------------------------------------------------

public class SystemClipboardAdapter <: Clipboard {
    private let system: Win32Clipboard = Win32Clipboard()
    private let fallback: MemoryClipboard = MemoryClipboard()

    public init() {}

    public func getText(): String {
        let text = system.getText()
        if (!text.isEmpty()) {
            return text
        }
        fallback.getText()
    }

    public func setText(text: String): Unit {
        if (system.setText(text)) {
            return
        }
        fallback.setText(text)
    }
}

// ---------------------------------------------------------------------------
// Widget identity helpers
// ---------------------------------------------------------------------------

func sameWidget(a: Widget, b: Widget): Bool {
    let left = a as Object
    let right = b as Object
    if (let Some(x) <- left) {
        if (let Some(y) <- right) {
            return refEq(x, y)
        }
    }
    false
}

func sameOptionWidget(a: Option<Widget>, b: Option<Widget>): Bool {
    if (let Some(x) <- a) {
        if (let Some(y) <- b) {
            return sameWidget(x, y)
        }
        return false
    }
    if (let Some(_) <- b) {
        return false
    }
    true
}

// ---------------------------------------------------------------------------
// AppBuilder
// ---------------------------------------------------------------------------

public class AppBuilder {
    var titleValue: String = "KaurUI"
    var widthValue: Int64 = 800
    var heightValue: Int64 = 600
    var resizableValue: Bool = true
    var minWidthValue: Int64 = 0
    var minHeightValue: Int64 = 0
    var themeValue: Theme = Theme.light()
    var rootWidgetValue: Option<Widget> = None

    public init() {}

    public static func create(): AppBuilder {
        AppBuilder()
    }

    public func title(t: String): AppBuilder {
        titleValue = t
        this
    }

    public func size(w: Int64, h: Int64): AppBuilder {
        widthValue = w
        heightValue = h
        this
    }

    public func resizable(v: Bool): AppBuilder {
        resizableValue = v
        this
    }

    public func minSize(w: Int64, h: Int64): AppBuilder {
        minWidthValue = w
        minHeightValue = h
        this
    }

    public func theme(t: Theme): AppBuilder {
        themeValue = t
        this
    }

    public func root(w: Widget): AppBuilder {
        rootWidgetValue = Some(w)
        this
    }

    public func run(): Int64 {
        let app = App(this)
        app.run()
    }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

public class App <: WindowHandler {
    private let titleValue: String
    private let widthValue: Int64
    private let heightValue: Int64
    private let resizableValue: Bool
    private let minWidthValue: Int64
    private let minHeightValue: Int64
    private var themeValue: Theme
    private var rootWidget: Widget

    private var rendererValue: Renderer
    private var windowValue: Option<Window> = None
    private var contextValue: Option<WidgetContext> = None

    private var layoutDirtyValue: Bool = true
    private var pendingDirtyValue: Option<Rect> = None
    private var layoutCountValue: Int64 = 0
    private var lastFrameDrawCallsValue: Int64 = 0
    private var lastFrameDirtyValue: Option<Rect> = None

    private var hoverWidget: Option<Widget> = None
    private var capturedWidget: Option<Widget> = None
    private var focusedWidget: Option<Widget> = None

    public init(builder: AppBuilder) {
        titleValue = builder.titleValue
        widthValue = builder.widthValue
        heightValue = builder.heightValue
        resizableValue = builder.resizableValue
        minWidthValue = builder.minWidthValue
        minHeightValue = builder.minHeightValue
        themeValue = builder.themeValue
        rootWidget = builder.rootWidgetValue ?? Panel(Array<Widget>())
        rendererValue = GdiRenderer()
    }

    // -- renderer ---------------------------------------------------------------

    public prop renderer: Renderer {
        get() {
            rendererValue
        }
    }

    public func setRenderer(r: Renderer): Unit {
        rendererValue = r
        layoutDirtyValue = true
        pendingDirtyValue = None
        if (let Some(win) <- windowValue) {
            win.invalidateAll()
        }
    }

    // -- runtime configuration ---------------------------------------------------

    // Theme is a value struct, so the context holds a copy: both the app and the
    // context must be updated or widgets keep painting with the old palette.
    public func setTheme(t: Theme): Unit {
        guard(
            {
                =>
                    themeValue = t
                    if (let Some(ctx) <- contextValue) {
                        ctx.theme = t
                    }
                    layoutDirtyValue = true
                    pendingDirtyValue = None
                    if (let Some(win) <- windowValue) {
                        win.invalidateAll()
                    }
            }
        )
    }

    public func setRoot(w: Widget): Unit {
        guard(
            {
                =>
                    if (let Some(ctx) <- contextValue) {
                        w.bind(ctx)
                    }
                    rootWidget = w
                    hoverWidget = None
                    capturedWidget = None
                    if (let Some(f) <- focusedWidget) {
                        focusedWidget = None
                        f.setFocus(false)
                    }
                    layoutDirtyValue = true
                    pendingDirtyValue = None
                    if (let Some(win) <- windowValue) {
                        win.invalidateAll()
                    }
            }
        )
    }

    public prop lastFrameDrawCalls: Int64 {
        get() {
            lastFrameDrawCallsValue
        }
    }

    public prop lastFrameDirty: Option<Rect> {
        get() {
            lastFrameDirtyValue
        }
    }

    public prop layoutCount: Int64 {
        get() {
            layoutCountValue
        }
    }

    // -- lifecycle -------------------------------------------------------------

    public func run(): Int64 {
        var code: Int64 = -1
        try {
            enableDpiAwareness()
            var config = WindowConfig()
            config.title = titleValue
            config.width = widthValue
            config.height = heightValue
            config.resizable = resizableValue
            config.minWidth = minWidthValue
            config.minHeight = minHeightValue
            let win = Window.create(config, this)
            windowValue = Some(win)
            let ctx = WidgetContext(themeValue)
            contextValue = Some(ctx)
            ctx.invalidateHandler = {w => this.handleInvalidate(w)}
            ctx.paintInvalidateHandler = {w => this.handlePaintInvalidate(w)}
            ctx.focusHandler = {w => this.requestFocus(w)}
            ctx.measureTextHandler = {text, style => this.measureText(text, style)}
            ctx.clipboard = SystemClipboardAdapter()
            rootWidget.bind(ctx)
            layoutDirtyValue = true
            win.show()
            code = EventLoop.run(win)
        } catch (e: Exception) {
            println("kaurui.app: run failed: ${e.message}")
            code = -1
        }
        releaseRenderer()
        code
    }

    private func releaseRenderer(): Unit {
        let gdi = rendererValue as GdiRenderer
        if (let Some(r) <- gdi) {
            r.release()
        }
    }

    private func measureText(text: String, style: TextStyle): Size {
        rendererValue.measureText(text, style)
    }

    private func bindRenderer(hdc: CPointer<Unit>, scale: Float32): Unit {
        let gdi = rendererValue as GdiRenderer
        if (let Some(r) <- gdi) {
            r.bind(hdc, scale)
        }
    }

    // -- window handler --------------------------------------------------------

    public func onPaint(hdc: CPointer<Unit>, clientSize: Size, scale: Float32): Unit {
        guard({=> this.paintFrame(hdc, clientSize, scale)})
    }

    public func onResize(clientSize: Size, scale: Float32): Unit {
        let _ = (clientSize, scale)
        guard(
            {
                =>
                    layoutDirtyValue = true
                    pendingDirtyValue = None
                    if (let Some(win) <- windowValue) {
                        win.invalidateAll()
                    }
            }
        )
    }

    public func onMouseMove(e: MouseEvent): Unit {
        guard({=> this.handleMouseMove(e.x, e.y)})
    }

    public func onMouseDown(e: MouseEvent): Unit {
        guard({=> this.handleMouseDown(e.x, e.y)})
    }

    public func onMouseUp(e: MouseEvent): Unit {
        guard({=> this.handleMouseUp(e.x, e.y)})
    }

    public func onMouseLeave(): Unit {
        guard({=> this.handleMouseLeave()})
    }

    public func onWheel(delta: Float32, x: Float32, y: Float32): Unit {
        guard({=> this.handleWheel(delta, x, y)})
    }

    public func onKeyDown(e: KeyEvent): Unit {
        guard({=> this.handleKeyDown(e.vk, e.ctrl, e.shift)})
    }

    public func onChar(e: CharEvent): Unit {
        guard({=> this.handleChar(e.ch)})
    }

    public func onDeactivate(): Unit {
        guard({=> this.handleDeactivate()})
    }

    public func onTimer(id: UInt64): Unit {
        let _ = id
    }

    public func onClose(): Bool {
        true
    }

    public func wantsHandCursor(x: Float32, y: Float32): Bool {
        if (let Some(w) <- rootWidget.hitTest(Point(x, y))) {
            return w.isClickable()
        }
        false
    }

    // -- paint -----------------------------------------------------------------

    private func paintFrame(hdc: CPointer<Unit>, clientSize: Size, scale: Float32): Unit {
        bindRenderer(hdc, scale)
        // beginFrame prepares the back buffer and the logical->device mapping that
        // measureText relies on, so layout must run after it.
        rendererValue.beginFrame(clientSize.width, clientSize.height)
        if (layoutDirtyValue) {
            rootWidget.measure(Constraints.loose(clientSize.width, clientSize.height))
            rootWidget.arrange(Rect(0.0f32, 0.0f32, clientSize.width, clientSize.height))
            layoutCountValue += 1
            layoutDirtyValue = false
        }
        let canvas = Rect(0.0f32, 0.0f32, clientSize.width, clientSize.height)
        rendererValue.fillRect(canvas, themeValue.background)
        match (pendingDirtyValue) {
            case Some(dirty) =>
                rendererValue.pushClip(dirty)
                rootWidget.paint(rendererValue)
                rendererValue.popClip()
            case None => rootWidget.paint(rendererValue)
        }
        rendererValue.endFrame()
        lastFrameDrawCallsValue = rendererValue.drawCalls
        lastFrameDirtyValue = pendingDirtyValue
        pendingDirtyValue = None
    }

    // -- invalidation ----------------------------------------------------------

    private func handleInvalidate(w: Widget): Unit {
        let bounds = w.bounds
        pendingDirtyValue = match (pendingDirtyValue) {
            case Some(dirty) => Some(dirty.union(bounds))
            case None => Some(bounds)
        }
        layoutDirtyValue = true
        if (let Some(win) <- windowValue) {
            win.invalidate(bounds)
        }
    }

    // Visual-only invalidation: merge the dirty rect but keep the existing
    // layout, so hover/press/scroll repaints never trigger measure/arrange.
    private func handlePaintInvalidate(w: Widget): Unit {
        let bounds = w.bounds
        pendingDirtyValue = match (pendingDirtyValue) {
            case Some(dirty) => Some(dirty.union(bounds))
            case None => Some(bounds)
        }
        if (let Some(win) <- windowValue) {
            win.invalidate(bounds)
        }
    }

    // -- mouse -----------------------------------------------------------------

    private func handleMouseMove(x: Float32, y: Float32): Unit {
        let hit = rootWidget.hitTest(Point(x, y))
        if (!sameOptionWidget(hoverWidget, hit)) {
            if (let Some(old) <- hoverWidget) {
                old.onEvent(UiEvent.MouseLeave)
            }
            if (let Some(fresh) <- hit) {
                fresh.onEvent(UiEvent.MouseEnter)
            }
            hoverWidget = hit
        }
        if (let Some(target) <- capturedWidget) {
            target.onEvent(UiEvent.MouseMove(x, y))
        } else if (let Some(target) <- hoverWidget) {
            target.onEvent(UiEvent.MouseMove(x, y))
        }
    }

    private func handleMouseDown(x: Float32, y: Float32): Unit {
        let hit = rootWidget.hitTest(Point(x, y))
        capturedWidget = hit
        if (let Some(w) <- hit) {
            w.onEvent(UiEvent.MouseDown(x, y))
            if (w.focusable) {
                requestFocus(w)
            }
        }
    }

    private func handleMouseUp(x: Float32, y: Float32): Unit {
        let target = capturedWidget
        capturedWidget = None
        if (let Some(w) <- target) {
            w.onEvent(UiEvent.MouseUp(x, y))
        }
    }

    private func handleMouseLeave(): Unit {
        if (let Some(w) <- hoverWidget) {
            hoverWidget = None
            w.onEvent(UiEvent.MouseLeave)
        }
    }

    // Losing window focus clears transient pointer state without touching the
    // focus chain, so the widget tree cannot keep a stale hover highlight.
    private func handleDeactivate(): Unit {
        if (let Some(w) <- hoverWidget) {
            w.onEvent(UiEvent.MouseLeave)
        }
        hoverWidget = None
        capturedWidget = None
    }

    private func handleWheel(delta: Float32, x: Float32, y: Float32): Unit {
        let p = Point(x, y)
        var target = rootWidget.hitTest(p)
        if (let Some(hover) <- hoverWidget) {
            if (hover.bounds.contains(p)) {
                target = Some(hover)
            }
        }
        let scroll = innermostScrollAt(p)
        if (let Some(w) <- target) {
            w.onEvent(UiEvent.Wheel(delta, x, y))
            if (let Some(sv) <- scroll) {
                if (!sameWidget(w, sv)) {
                    sv.onEvent(UiEvent.Wheel(delta, x, y))
                }
            }
        } else if (let Some(sv) <- scroll) {
            sv.onEvent(UiEvent.Wheel(delta, x, y))
        }
    }

    private func innermostScrollAt(p: Point): Option<Widget> {
        var best: Option<Widget> = None
        var bestArea = Float32.Inf
        for (w in rootWidget.subtreeWidgets()) {
            let maybeScroll = w as ScrollView
            if (let Some(sv) <- maybeScroll) {
                if (sv.bounds.contains(p)) {
                    let area = sv.bounds.width * sv.bounds.height
                    if (area < bestArea) {
                        bestArea = area
                        best = Some(sv)
                    }
                }
            }
        }
        best
    }

    // -- keyboard --------------------------------------------------------------

    private func handleKeyDown(vk: UInt32, ctrl: Bool, shift: Bool): Unit {
        if (vk == TAB_VK) {
            cycleFocus(shift)
            return
        }
        if (let Some(w) <- focusedWidget) {
            w.onEvent(UiEvent.KeyDown(vk, ctrl, shift))
        }
    }

    private func handleChar(ch: UInt32): Unit {
        if (let Some(w) <- focusedWidget) {
            w.onEvent(UiEvent.Char(ch))
        }
    }

    // -- focus -----------------------------------------------------------------

    private func cycleFocus(reverse: Bool): Unit {
        let order = rootWidget.focusOrder()
        if (order.size == 0) {
            return
        }
        var current: Int64 = -1
        if (let Some(f) <- focusedWidget) {
            for (i in 0..order.size) {
                if (sameWidget(f, order[i])) {
                    current = i
                    break
                }
            }
        }
        let next = if (reverse) {
            if (current < 0) {
                order.size - 1
            } else {
                (current - 1 + order.size) % order.size
            }
        } else {
            if (current < 0) {
                0
            } else {
                (current + 1) % order.size
            }
        }
        requestFocus(order[next])
    }

    private func requestFocus(w: Widget): Unit {
        if (let Some(old) <- focusedWidget) {
            if (sameWidget(old, w)) {
                return
            }
            focusedWidget = None
            old.setFocus(false)
            old.onEvent(UiEvent.FocusChanged(false))
        }
        focusedWidget = Some(w)
        w.setFocus(true)
        w.onEvent(UiEvent.FocusChanged(true))
    }

    // -- error containment -----------------------------------------------------

    private func guard(action: () -> Unit): Unit {
        try {
            action()
        } catch (e: Exception) {
            println("kaurui.app: handler failed: ${e.message}")
        }
    }
}
