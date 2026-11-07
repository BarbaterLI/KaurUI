package demo

import std.collection.*
import std.convert.*
import std.env.getVariable
import kaurui.app.*
import kaurui.ffi.*
import kaurui.layout.*
import kaurui.render.*
import kaurui.widget.*

let WINDOW_TITLE: String = "KaurUI Demo"
let WM_CLOSE_MESSAGE: UInt32 = 0x0010
let AUTOCLOSE_ENV: String = "KAURUI_AUTOCLOSE_MS"
let START_DARK_ENV: String = "KAURUI_START_DARK"
let AUTO_CHANGE_ENV: String = "KAURUI_AUTO_CHANGE"
let IMAGE_ENV: String = "KAURUI_IMAGE"
let AUTO_CHANGE_DELAY_MS: Int64 = 500
let AUTO_CHANGE_TEXT: String = "自动变更：输入回显已更新，用于验证测量缓存命中。"

// ---------------------------------------------------------------------------
// Frame counter shared by every FrameRoot so theme rebuilds keep counting.
// ---------------------------------------------------------------------------

class FrameStats {
    public var frames: Int64 = 0

    public init() {}
}

let FRAME_STATS = FrameStats()

// ---------------------------------------------------------------------------
// FrameRoot: transparent decorator around the real root widget, used only to
// count painted frames for the observation line printed on shutdown.
// ---------------------------------------------------------------------------

class FrameRoot <: WidgetBase {
    private let child: Widget
    private let stats: FrameStats
    private let focusTarget: ?Widget
    private var focusRequested: Bool = false

    init(child: Widget, stats: FrameStats, focusTarget!: ?Widget = None) {
        super(0.0f32)
        this.child = child
        this.stats = stats
        this.focusTarget = focusTarget
    }

    public func measure(c: Constraints): Size {
        sizeValue = c.constrain(child.measure(c))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        stats.frames += 1
        child.paint(r)
        // Focus the text field after the first frame so the caret at the end of
        // a long text scrolls the content horizontally on startup.
        if (!focusRequested) {
            focusRequested = true
            if (let Some(target) <- focusTarget) {
                if (let Some(ctx) <- ctxValue) {
                    ctx.requestFocus(target)
                }
            }
        }
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        child.arrange(rect)
    }

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        child.bind(ctx)
    }

    public override func hitTest(p: Point): Option<Widget> {
        child.hitTest(p)
    }

    public override func focusOrder(): Array<Widget> {
        child.focusOrder()
    }

    public override func subtreeWidgets(): Array<Widget> {
        child.subtreeWidgets()
    }
}

// ---------------------------------------------------------------------------
// ListRow: paints a background so the non-uniform virtual row heights are
// visible, then forwards everything to the row content.
// ---------------------------------------------------------------------------

class ListRow <: WidgetBase {
    private let child: Widget
    private let background: Color

    init(child: Widget, background: Color) {
        super(0.0f32)
        this.child = child
        this.background = background
    }

    public func measure(c: Constraints): Size {
        sizeValue = c.constrain(child.measure(c))
        sizeValue
    }

    public func paint(r: Renderer): Unit {
        r.fillRect(boundsValue, background)
        child.paint(r)
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        child.arrange(rect)
    }

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        child.bind(ctx)
    }

    public override func hitTest(p: Point): Option<Widget> {
        child.hitTest(p)
    }
}

// ---------------------------------------------------------------------------
// EchoRow: places a prefix label and a wrapping text label on one row. The
// wrapping label is measured against the width that remains after the prefix,
// so its lines are wrapped to the row it is actually arranged in.
// ---------------------------------------------------------------------------

class EchoRow <: WidgetBase {
    private let prefix: Widget
    private let text: Widget
    private let gap: Float32

    init(prefix: Widget, text: Widget, gap: Float32) {
        super(0.0f32)
        this.prefix = prefix
        this.text = text
        this.gap = gap
    }

    public func measure(c: Constraints): Size {
        let prefixSize = prefix.measure(Constraints.loose(c.maxWidth, c.maxHeight))
        let remaining = maxOf(0.0f32, c.maxWidth - prefixSize.width - gap)
        let textSize = text.measure(Constraints(0.0f32, remaining, 0.0f32, c.maxHeight))
        sizeValue = c.constrain(Size(prefixSize.width + gap + textSize.width, maxOf(prefixSize.height, textSize.height)))
        sizeValue
    }

    // Ancestor containers cache on contentVersion, so a composite row must fold
    // in the versions of its children: otherwise setText on the echo label would
    // be masked by a stale cache hit and never re-measured.
    public override func contentVersion(): Int64 {
        var total = version
        if (let Some(base) <- (prefix as WidgetBase)) {
            total += base.contentVersion()
        }
        if (let Some(base) <- (text as WidgetBase)) {
            total += base.contentVersion()
        }
        total
    }

    public func paint(r: Renderer): Unit {
        prefix.paint(r)
        text.paint(r)
    }

    public override func arrange(rect: Rect): Unit {
        super.arrange(rect)
        let height = maxOf(prefix.size.height, text.size.height)
        prefix.arrange(Rect(rect.x, rect.y, prefix.size.width, height))
        text.arrange(
            Rect(rect.x + prefix.size.width + gap, rect.y, maxOf(0.0f32, rect.width - prefix.size.width - gap), height))
    }

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        prefix.bind(ctx)
        text.bind(ctx)
    }

    public override func focusOrder(): Array<Widget> {
        prefix.focusOrder().concat(text.focusOrder())
    }

    public override func subtreeWidgets(): Array<Widget> {
        var out: Array<Widget> = [this]
        out = out.concat(prefix.subtreeWidgets())
        out = out.concat(text.subtreeWidgets())
        out
    }
}

func maxOf(a: Float32, b: Float32): Float32 {
    if (a >= b) {
        a
    } else {
        b
    }
}

// ---------------------------------------------------------------------------
// Delayed auto close (for automated smoke runs)
// ---------------------------------------------------------------------------

func autoCloseDelay(): Option<Int64> {
    if (let Some(raw) <- getVariable(AUTOCLOSE_ENV)) {
        try {
            let value = Int64.parse(raw)
            if (value > 0) {
                return Some(value)
            }
        } catch (e: Exception) {
            return None
        }
    }
    None
}

func autoChangeEnabled(): Bool {
    if (let Some(raw) <- getVariable(AUTO_CHANGE_ENV)) {
        return raw == "1"
    }
    false
}

func startDark(): Bool {
    if (let Some(raw) <- getVariable(START_DARK_ENV)) {
        return raw == "1"
    }
    false
}

func imagePath(): Option<String> {
    if (let Some(raw) <- getVariable(IMAGE_ENV)) {
        if (!raw.isEmpty()) {
            return Some(raw)
        }
    }
    None
}

func findWindow(title: String): CPointer<Unit> {
    let findFn = CFunc<(CPointer<Unit>, CString) -> CPointer<Unit>>(Libs.user32().proc("FindWindowW"))
    let cTitle = toUtf16(title)
    let hwnd = unsafe { findFn(CPointer<Unit>(), cTitle) }
    freeCString(cTitle)
    hwnd
}

func postClose(hwnd: CPointer<Unit>): Unit {
    let postFn = CFunc<(CPointer<Unit>, UInt32, UInt64, Int64) -> Int32>(Libs.user32().proc("PostMessageW"))
    unsafe { postFn(hwnd, WM_CLOSE_MESSAGE, UInt64(0), Int64(0)) }
    ()
}

func scheduleAutoClose(delayMs: Int64): Unit {
    // Resolve the symbols on the UI thread first: kaurui.ffi caches them in a
    // HashMap that is only safe to read from the worker thread.
    let _ = Libs.user32().proc("FindWindowW")
    let _ = Libs.user32().proc("PostMessageW")
    let _ = spawn {
        =>
            sleep(delayMs * Duration.millisecond)
            var hwnd = findWindow(WINDOW_TITLE)
            var waited: Int64 = 0
            while (hwnd.isNull() && waited < 5000) {
                sleep(50 * Duration.millisecond)
                waited += 50
                hwnd = findWindow(WINDOW_TITLE)
            }
            if (!hwnd.isNull()) {
                postClose(hwnd)
            }
    }
}

func scheduleAutoChange(label: Label, delayMs: Int64): Unit {
    // Resolve the symbols used by the invalidation path on the UI thread first:
    // kaurui.ffi resolves procs lazily into a HashMap that a worker thread must
    // only read, never mutate.
    let _ = Libs.user32().proc("InvalidateRect")
    let _ = spawn {
        =>
            sleep(delayMs * Duration.millisecond)
            // setText bumps the widget content version and invalidates itself, so the
            // next frame re-runs layout through the regular dirty path.
            label.setText(AUTO_CHANGE_TEXT)
    }
}

// ---------------------------------------------------------------------------
// Demo state (survives root rebuilds triggered by theme switching)
// ---------------------------------------------------------------------------

let INITIAL_TEXT: String = "This is a long text used to verify horizontal scrolling in the KaurUI TextField."

class DemoState {
    public var progress: Float32 = 0.0f32
    public var text: String = INITIAL_TEXT
    public var checked: Bool = true
    public var dark: Bool = false
    public var app: ?App = None
    public var echoLabel: ?Label = None

    public init() {}
}

// ---------------------------------------------------------------------------
// Demo UI
// ---------------------------------------------------------------------------

func buildRoot(state: DemoState, theme: Theme): Widget {
    let title = Label("KaurUI · 仓颉原生 UI", fontSize: 24.0f32, bold: true)
    let subtitle = Label("朴素 / 原生 / 高性能 / 可扩展", color: Some(theme.textSecondary))

    let progress = ProgressBar(value: state.progress)
    let increase = Button(
        "增加进度",
        enabled: state.checked,
        onClick: {
            =>
                progress.setValue(progress.value + 0.1f32)
                state.progress = progress.value
        }
    )
    let reset = Button(
        "重置",
        enabled: state.checked,
        onClick: {
            =>
                progress.setValue(0.0f32)
                state.progress = progress.value
        }
    )
    let toggle = CheckBox(
        "启用按钮",
        checked: state.checked,
        onChange: {
            enabled =>
                state.checked = enabled
                increase.setEnabled(enabled)
                reset.setEnabled(enabled)
        }
    )
    let switchTheme = Button(
        "切换主题",
        onClick: {
            =>
                state.dark = !state.dark
                let t = if (state.dark) {
                    Theme.dark()
                } else {
                    Theme.light()
                }
                if (let Some(app) <- state.app) {
                    app.setTheme(t)
                    app.setRoot(buildRoot(state, t))
                }
        }
    )

    let echo = Label(state.text, wrap: true, flex: 1.0f32)
    state.echoLabel = Some(echo)
    let field = TextField(
        text: state.text,
        placeholder: "在这里输入内容…",
        onChange: {
            value =>
                state.text = value
                echo.setText(value)
        },
        onSubmit: {value => echo.setText("提交：" + value)}
    )

    let virtualList = ListView(
        itemCount: 1000,
        itemHeight: 28.0f32,
        // Alternating row tints make the non-uniform row heights visible.
        builder: {
            i =>
                let rowBg = if (i % 2 == 0) {
                    theme.surface
                } else {
                    theme.background
                }
                ListRow(
                    Label("条目 ${i + 1} · 虚拟化渲染，只物化可见项", fontSize: 13.0f32),
                    rowBg
                )
        },
        background: Some(theme.surface),
        heightProvider: Some({
            i => if (i % 2 == 0) {
                28.0f32
            } else {
                44.0f32
            }
        })
    )
    let listArea = SizedBox(height: 96.0f32, child: virtualList)

    let tags = WrapPanel(
        [
            Label("朴素 · 界面", fontSize: 13.0f32),
            Label("原生 · 窗口", fontSize: 13.0f32),
            Label("高性能 · 绘制", fontSize: 13.0f32),
            Label("可扩展 · 组件", fontSize: 13.0f32),
            Label("零依赖 · 实现", fontSize: 13.0f32),
            Label("双缓冲 · 渲染", fontSize: 13.0f32),
            Label("脏区重绘 · 增量", fontSize: 13.0f32),
            Label("亚像素 · 布局", fontSize: 13.0f32),
            Label("事件循环 · 驱动", fontSize: 13.0f32),
            Label("仓颉 · 原生", fontSize: 13.0f32)
        ],
        horizontalSpacing: 10.0f32,
        verticalSpacing: 6.0f32,
        crossAlign: CrossAlign.Center
    )

    let paragraph = Label(
        "这是一段用于验证自动换行效果的长文本，它会在窗口宽度受限时自动折行显示，而不是被裁剪或超出可视区域。调整窗口大小后，文本应当随可用宽度的变化重新排版。",
        fontSize: 13.0f32,
        wrap: true,
        color: Some(theme.textSecondary)
    )

    let hint = Panel(
        [
            Label("Tab 切换焦点 · 点击按钮改变进度", fontSize: 12.0f32, color: Some(theme.textSecondary)),
            Label("关闭窗口退出", fontSize: 12.0f32, color: Some(theme.textSecondary))
        ],
        axis: MainAxis.Vertical,
        spacing: 2.0f32,
        crossAlign: CrossAlign.End
    )

    let children = ArrayList<Widget>()
    children.add(title)
    children.add(subtitle)
    children.add(SizedBox(height: 4.0f32))
    children.add(Panel([increase, reset, toggle, switchTheme], axis: MainAxis.Horizontal, spacing: 12.0f32))
    children.add(SizedBox(width: 420.0f32, child: field))
    children.add(EchoRow(Label("输入回显："), echo, 6.0f32))
    children.add(progress)
    children.add(tags)
    if (let Some(path) <- imagePath()) {
        children.add(Image(path: path, width: 160.0f32, height: 90.0f32))
    }
    children.add(
        Panel(
            [
                Label("虚拟化列表（共 1000 项，视口高度 96）", fontSize: 12.0f32, color: Some(theme.textSecondary)),
                listArea
            ],
            axis: MainAxis.Vertical,
            spacing: 6.0f32,
            crossAlign: CrossAlign.Stretch
        )
    )
    children.add(paragraph)
    children.add(Spacer(flex: 1.0f32))
    children.add(Panel([Spacer(flex: 1.0f32), hint], axis: MainAxis.Horizontal))

    let content = Panel(
        children.toArray(),
        axis: MainAxis.Vertical,
        spacing: 5.0f32,
        padding: Insets.all(12.0f32),
        crossAlign: CrossAlign.Stretch
    )

    FrameRoot(content, FRAME_STATS, focusTarget: Some(field))
}

main(): Int64 {
    let state = DemoState()
    state.dark = startDark()
    let theme = if (state.dark) {
        Theme.dark()
    } else {
        Theme.light()
    }

    let root = buildRoot(state, theme)
    let builder = AppBuilder
        .create()
        .title(WINDOW_TITLE)
        .size(760, 600)
        .minSize(560, 460)
        .resizable(true)
        .theme(theme)
        .root(root)
    let app = App(builder)
    state.app = Some(app)

    if (let Some(ms) <- autoCloseDelay()) {
        scheduleAutoClose(ms)
    }
    if (autoChangeEnabled()) {
        if (let Some(echo) <- state.echoLabel) {
            scheduleAutoChange(echo, AUTO_CHANGE_DELAY_MS)
        }
    }

    let code = app.run()
    println(
        "[demo] frames=${FRAME_STATS.frames}, drawCalls=${app.lastFrameDrawCalls}, layout=${app.layoutCount}, measure=${LayoutStats.measureCalls}, cacheHits=${LayoutStats.cacheHits}, skips=${LayoutStats.paintSkips}")
    code
}
