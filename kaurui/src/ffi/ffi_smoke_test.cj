package kaurui.ffi

@Test
func layoutSelfCheckTest(): Unit {
    layoutSelfCheck()
}

@Test
func smokeCheckTest(): Unit {
    let report = smokeCheck()
    @Expect(report.size > 0, true)
    @Expect(report.startsWith("user32!CreateWindowExW=0x"), true)
}

@Test
func utf16RoundTripTest(): Unit {
    let wide = toUtf16("KaurUI 界面😀")
    let text = fromUtf16(CPointer<UInt16>(wide.getChars()))
    freeCString(wide)
    @Expect(text, "KaurUI 界面😀")
}
