package kaurui.widget

import kaurui.layout.*
import kaurui.render.*

class ListViewBindCounter {
    public var value: Int64 = 0

    public func bump(): Unit {
        value += 1
    }
}

class ListViewBindProbe <: WidgetBase {
    private let counter: ListViewBindCounter

    public init(counter: ListViewBindCounter) {
        super(0.0f32)
        this.counter = counter
    }

    public func measure(c: Constraints): Size {
        sizeValue = c.constrain(Size(120.0f32, 30.0f32))
        sizeValue
    }

    public func paint(r: Renderer): Unit {}

    public override func bind(ctx: WidgetContext): Unit {
        super.bind(ctx)
        counter.bump()
    }
}

func listViewRow(index: Int64): Widget {
    SizedBox(width: 300.0f32, height: 30.0f32)
}

@Test
func listViewBuildsVisibleRangeOnlyTest(): Unit {
    let view = ListView(itemCount: 1000, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    view.bind(WidgetContext(Theme.light()))
    view.measure(Constraints.loose(300.0f32, 300.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))

    @Expect(view.offset, 0.0f32)
    @Expect(view.firstVisibleIndex, 0)
    @Expect(view.builtCount <= 13, true)
    @Expect(view.builtCount >= 10, true)
}

@Test
func listViewScrollClampsToContentTest(): Unit {
    let view = ListView(itemCount: 1000, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    view.measure(Constraints.loose(300.0f32, 300.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))

    view.scrollBy(1000000.0f32)
    @Expect(widgetApprox(view.offset, 29700.0f32, 0.1f32), true)
    view.scrollBy(-1000000.0f32)
    @Expect(widgetApprox(view.offset, 0.0f32, 0.1f32), true)
}

@Test
func listViewOffsetRebuildsRangeTest(): Unit {
    let view = ListView(itemCount: 1000, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    view.measure(Constraints.loose(300.0f32, 300.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))

    view.setOffset(1500.0f32)
    @Expect(view.firstVisibleIndex, 50)
    @Expect(view.builtCount <= 13, true)

    let hit = view.hitTest(Point(10.0f32, 5.0f32))
    @Expect(hit.isSome(), true)
    if (let Some(w) <- hit) {
        @Expect(widgetApprox(w.bounds.y, 0.0f32, 0.5f32), true)
    }
}

@Test
func listViewHitTestHitVisibleChildTest(): Unit {
    let view = ListView(itemCount: 1000, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    view.measure(Constraints.loose(300.0f32, 300.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))

    let hit = view.hitTest(Point(10.0f32, 45.0f32))
    @Expect(hit.isSome(), true)
    if (let Some(w) <- hit) {
        @Expect(widgetApprox(w.bounds.y, 30.0f32, 0.5f32), true)
    }
    @Expect(view.hitTest(Point(10.0f32, 400.0f32)).isNone(), true)
}

@Test
func listViewWheelScrollsTest(): Unit {
    let view = ListView(itemCount: 1000, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    view.measure(Constraints.loose(300.0f32, 300.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))
    view.setOffset(100.0f32)

    view.onEvent(UiEvent.Wheel(1.0f32, 10.0f32, 10.0f32))
    @Expect(widgetApprox(view.offset, 60.0f32, 0.1f32), true)
    view.onEvent(UiEvent.Wheel(-1.0f32, 10.0f32, 10.0f32))
    @Expect(widgetApprox(view.offset, 100.0f32, 0.1f32), true)
}

@Test
func listViewShortContentHasNoScrollTest(): Unit {
    let view = ListView(itemCount: 3, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    view.measure(Constraints.loose(300.0f32, 300.0f32))
    @Expect(widgetApprox(view.size.height, 90.0f32, 0.5f32), true)
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))

    @Expect(view.offset, 0.0f32)
    @Expect(view.builtCount, 3)
    view.scrollBy(100.0f32)
    @Expect(view.offset, 0.0f32)
    view.scrollBy(-100.0f32)
    @Expect(view.offset, 0.0f32)
}

@Test
func listViewBindsMaterializedChildrenTest(): Unit {
    let counter = ListViewBindCounter()
    let view = ListView(
        itemCount: 1000,
        itemHeight: 30.0f32,
        builder: {_ => ListViewBindProbe(counter)}
    )
    view.bind(WidgetContext(Theme.light()))
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))

    @Expect(counter.value, view.builtCount)

    view.setOffset(600.0f32)
    @Expect(counter.value, 8 + view.builtCount)
}

@Test
func listViewUnboundedWidthUsesFirstItemTest(): Unit {
    let view = ListView(itemCount: 50, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    let size = view.measure(Constraints.unbounded())

    @Expect(widgetApprox(size.width, 300.0f32, 0.5f32), true)
    @Expect(widgetApprox(size.height, 1500.0f32, 1.0f32), true)
    @Expect(view.builtCount, 50)
}

// ---------------------------------------------------------------------------
// Variable-height mode
// ---------------------------------------------------------------------------

class ListViewHeightCounter {
    public var value: Int64 = 0

    public func bump(): Unit {
        value += 1
    }
}

func listViewAlternatingHeight(index: Int64): Float32 {
    if (index % 2 == 0) {
        20.0f32
    } else {
        30.0f32
    }
}

func listViewZeroOrNegativeHeight(index: Int64): Float32 {
    if (index % 2 == 0) {
        0.0f32
    } else {
        -5.0f32
    }
}

func listViewCountingHeight(counter: ListViewHeightCounter, index: Int64): Float32 {
    counter.bump()
    return 20.0f32
}

func listViewVariable(): ListView {
    ListView(
        itemCount: 100,
        itemHeight: 20.0f32,
        builder: {index => listViewRow(index)},
        heightProvider: Some({index => listViewAlternatingHeight(index)})
    )
}

@Test
func listViewVariableContentHeightTest(): Unit {
    let view = listViewVariable()
    @Expect(widgetApprox(view.contentHeight, 2500.0f32, 0.5f32), true)
}

@Test
func listViewVariableMaxOffsetClampTest(): Unit {
    let view = listViewVariable()
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))

    @Expect(widgetApprox(view.contentHeight, 2500.0f32, 0.5f32), true)
    view.scrollBy(1000000.0f32)
    @Expect(widgetApprox(view.offset, 2300.0f32, 0.1f32), true)
}

@Test
func listViewVariableFirstVisibleAtZeroTest(): Unit {
    let view = listViewVariable()
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))

    @Expect(view.offset, 0.0f32)
    @Expect(view.firstVisibleIndex, 0)
}

@Test
func listViewVariableFirstVisibleAt1000Test(): Unit {
    let view = listViewVariable()
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))

    view.setOffset(1000.0f32)
    @Expect(widgetApprox(view.offset, 1000.0f32, 0.1f32), true)
    // prefix[40] == 20*20 + 20*30 == 1000, prefix[41] == 1020.
    @Expect(view.firstVisibleIndex, 40)
}

@Test
func listViewVariableBuiltCountBoundedTest(): Unit {
    let view = listViewVariable()
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))

    view.setOffset(2300.0f32)
    @Expect(view.firstVisibleIndex, 92)
    @Expect(view.builtCount >= 8, true)
    @Expect(view.builtCount <= 10, true)
}

@Test
func listViewVariableNonPositiveHeightClampedTest(): Unit {
    let view = ListView(
        itemCount: 10,
        itemHeight: 20.0f32,
        builder: {index => listViewRow(index)},
        heightProvider: Some({index => listViewZeroOrNegativeHeight(index)})
    )
    @Expect(widgetApprox(view.contentHeight, 10.0f32, 0.5f32), true)
}

@Test
func listViewVariableProviderCallsBoundedTest(): Unit {
    let counter = ListViewHeightCounter()
    let view = ListView(
        itemCount: 100,
        itemHeight: 20.0f32,
        builder: {index => listViewRow(index)},
        heightProvider: Some({index => listViewCountingHeight(counter, index)})
    )
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))
    view.setOffset(500.0f32)
    view.scrollBy(100.0f32)
    @Expect(widgetApprox(view.contentHeight, 2000.0f32, 0.5f32), true)

    @Expect(counter.value <= 100, true)
    @Expect(counter.value, 100)
}

@Test
func listViewFixedContentHeightUnchangedTest(): Unit {
    let view = ListView(itemCount: 100, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    @Expect(widgetApprox(view.contentHeight, 3000.0f32, 0.5f32), true)

    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))
    view.setOffset(1500.0f32)
    @Expect(view.firstVisibleIndex, 50)
}

@Test
func listViewVariableArrangeUsesPrefixTest(): Unit {
    let view = listViewVariable()
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))
    view.setOffset(1000.0f32)

    let hit = view.hitTest(Point(10.0f32, 25.0f32))
    @Expect(hit.isSome(), true)
    if (let Some(w) <- hit) {
        @Expect(widgetApprox(w.bounds.y, 20.0f32, 0.5f32), true)
        @Expect(widgetApprox(w.bounds.height, 30.0f32, 0.5f32), true)
    }
}

@Test
func listViewVariableWheelScrollTest(): Unit {
    let view = listViewVariable()
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))
    view.setOffset(1000.0f32)

    view.onEvent(UiEvent.Wheel(1.0f32, 10.0f32, 10.0f32))
    @Expect(widgetApprox(view.offset, 960.0f32, 0.1f32), true)
    @Expect(view.firstVisibleIndex, 38)
}

@Test
func listViewVariableShortContentTest(): Unit {
    let view = ListView(
        itemCount: 3,
        itemHeight: 20.0f32,
        builder: {index => listViewRow(index)},
        heightProvider: Some({index => listViewAlternatingHeight(index)})
    )
    let size = view.measure(Constraints.loose(300.0f32, 300.0f32))
    @Expect(widgetApprox(size.height, 70.0f32, 0.5f32), true)
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))

    @Expect(view.builtCount, 3)
    view.scrollBy(100.0f32)
    @Expect(view.offset, 0.0f32)
}

@Test
func listViewVariableScrollBackToTopTest(): Unit {
    let view = listViewVariable()
    view.measure(Constraints.loose(300.0f32, 200.0f32))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 200.0f32))

    view.scrollBy(1000000.0f32)
    @Expect(widgetApprox(view.offset, 2300.0f32, 0.1f32), true)
    view.scrollBy(-1000000.0f32)
    @Expect(view.offset, 0.0f32)
    @Expect(view.firstVisibleIndex, 0)
    @Expect(view.builtCount <= 10, true)
}

// ---------------------------------------------------------------------------
// Child reuse via binder
// ---------------------------------------------------------------------------

class ListViewRowProbe <: WidgetBase {
    public var label: String

    public init(text: String) {
        super(0.0f32)
        label = text
    }

    public func measure(c: Constraints): Size {
        sizeValue = c.constrain(Size(120.0f32, 30.0f32))
        sizeValue
    }

    public func paint(r: Renderer): Unit {}
}

func listViewProbeRow(index: Int64): Widget {
    ListViewRowProbe("#${index}")
}

func listViewRowBinder(child: Widget, index: Int64): Unit {
    if (let Some(row) <- (child as ListViewRowProbe)) {
        row.label = "#${index}"
    }
}

func listViewReusable(): ListView {
    ListView(
        itemCount: 1000,
        itemHeight: 30.0f32,
        builder: {index => listViewProbeRow(index)},
        binder: Some({child, index => listViewRowBinder(child, index)})
    )
}

func listViewLayOut(view: ListView, height: Float32): Unit {
    view.measure(Constraints.loose(300.0f32, height))
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, height))
}

func listViewProbeLabelAt(view: ListView, y: Float32): String {
    let hit = view.hitTest(Point(10.0f32, y))
    if (let Some(w) <- hit) {
        if (let Some(row) <- (w as ListViewRowProbe)) {
            return row.label
        }
    }
    ""
}

@Test
func listViewInitialBuilderCallsMatchBuiltCountTest(): Unit {
    let view = listViewReusable()
    listViewLayOut(view, 300.0f32)

    @Expect(view.builderCalls, view.builtCount)
    @Expect(view.bindCalls, 0)
}

@Test
func listViewFullScreenScrollReusesChildrenTest(): Unit {
    let view = listViewReusable()
    listViewLayOut(view, 300.0f32)

    let buildersBefore = view.builderCalls
    let bindsBefore = view.bindCalls
    view.scrollBy(300.0f32)

    @Expect(view.builderCalls - buildersBefore <= 1, true)
    @Expect(view.builderCalls - buildersBefore >= 0, true)
    @Expect(view.bindCalls - bindsBefore >= 9, true)
}

@Test
func listViewFarScrollKeepsBuiltCountBoundedTest(): Unit {
    let view = listViewReusable()
    listViewLayOut(view, 300.0f32)
    view.scrollBy(100.0f32 * 30.0f32)

    @Expect(view.firstVisibleIndex, 100)
    @Expect(view.builtCount <= 13, true)
    @Expect(view.builtCount >= 10, true)
}

@Test
func listViewReusedChildContentMatchesNewIndexTest(): Unit {
    let view = listViewReusable()
    listViewLayOut(view, 300.0f32)
    view.scrollBy(300.0f32)

    @Expect(view.bindCalls > 0, true)
    for (i in 10..=19) {
        let top = Float32(i) * 30.0f32 - 300.0f32
        @Expect(listViewProbeLabelAt(view, top + 15.0f32) == "#${i}", true)
    }
}

@Test
func listViewWithoutBinderBuildsNewChildrenTest(): Unit {
    let view = ListView(itemCount: 1000, itemHeight: 30.0f32, builder: {index => listViewRow(index)})
    listViewLayOut(view, 300.0f32)

    let before = view.builderCalls
    @Expect(before, view.builtCount)
    view.setOffset(300.0f32)
    @Expect(view.builderCalls > before, true)
    @Expect(view.bindCalls, 0)
}

@Test
func listViewBindCallsOnlyOnReuseTest(): Unit {
    let view = listViewReusable()
    listViewLayOut(view, 300.0f32)
    @Expect(view.bindCalls, 0)

    view.setOffset(300.0f32)
    let afterFirst = view.bindCalls
    @Expect(afterFirst > 0, true)

    view.setOffset(300.0f32)
    view.setOffset(310.0f32)
    view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))
    @Expect(view.bindCalls, afterFirst)
}

@Test
func listViewHitTestAfterScrolledReuseTest(): Unit {
    let view = listViewReusable()
    listViewLayOut(view, 300.0f32)
    view.scrollBy(300.0f32)

    @Expect(listViewProbeLabelAt(view, 15.0f32), "#10")
    @Expect(listViewProbeLabelAt(view, 285.0f32), "#19")
}

@Test
func listViewReusedChildArrangedAtNewIndexTest(): Unit {
    let view = listViewReusable()
    listViewLayOut(view, 300.0f32)
    view.scrollBy(300.0f32)

    let bindsAfterScroll = view.bindCalls
    var k = 0
    while (k < 3) {
        view.arrange(Rect(0.0f32, 0.0f32, 300.0f32, 300.0f32))
        k += 1
    }
    @Expect(view.bindCalls, bindsAfterScroll)

    for (i in 10..=19) {
        let top = Float32(i) * 30.0f32 - 300.0f32
        let hit = view.hitTest(Point(10.0f32, top + 15.0f32))
        @Expect(hit.isSome(), true)
        if (let Some(w) <- hit) {
            @Expect(widgetApprox(w.bounds.y, top, 0.5f32), true)
        }
    }
}
