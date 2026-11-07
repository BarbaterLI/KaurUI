package kaurui.platform

import kaurui.ffi.*

// ---------------------------------------------------------------------------
// Win32 system clipboard, CF_UNICODETEXT only.
//
// Opening the clipboard can fail while another process holds it, so the open
// step is retried a few times. HGLOBAL handles returned by GlobalAlloc become
// owned by the system once SetClipboardData succeeds and must not be freed.
// ---------------------------------------------------------------------------

let CF_UNICODETEXT: UInt32 = 13
let GMEM_MOVEABLE: UInt32 = 0x0042
let CLIPBOARD_MAX_RETRIES: Int64 = 5
let CLIPBOARD_RETRY_DELAY_MS: UInt32 = 20

// Most clipboard exports live in user32, the global-memory and Sleep helpers in
// kernel32. Resolve each symbol in whichever DLL actually exports it.
func clipboardSymbol(name: String): CPointer<UInt8> {
    if (let Some(p) <- Libs.user32().tryProc(name)) {
        return p
    }
    match (Libs.kernel32().tryProc(name)) {
        case Some(p) => p
        case None => throw Win32Error("failed to resolve clipboard symbol '${name}'")
    }
}

func isClipboardFormatAvailable(): Bool {
    let f = CFunc<(UInt32) -> Int32>(clipboardSymbol("IsClipboardFormatAvailable"))
    unsafe { f(CF_UNICODETEXT) } != 0
}

func openClipboardHandle(): Bool {
    let f = CFunc<(CPointer<Unit>) -> Int32>(clipboardSymbol("OpenClipboard"))
    unsafe { f(CPointer<Unit>()) } != 0
}

func openClipboardWithRetry(): Bool {
    if (openClipboardHandle()) {
        return true
    }
    var retry: Int64 = 0
    while (retry < CLIPBOARD_MAX_RETRIES) {
        sleepMs(CLIPBOARD_RETRY_DELAY_MS)
        if (openClipboardHandle()) {
            return true
        }
        retry += 1
    }
    false
}

func sleepMs(ms: UInt32): Unit {
    let f = CFunc<(UInt32) -> Unit>(clipboardSymbol("Sleep"))
    unsafe { f(ms) }
}

func closeClipboardHandle(): Unit {
    let f = CFunc<() -> Int32>(clipboardSymbol("CloseClipboard"))
    unsafe { f() }
}

func emptyClipboardHandle(): Bool {
    let f = CFunc<() -> Int32>(clipboardSymbol("EmptyClipboard"))
    unsafe { f() } != 0
}

func getClipboardHandle(): CPointer<Unit> {
    let f = CFunc<(UInt32) -> CPointer<Unit>>(clipboardSymbol("GetClipboardData"))
    unsafe { f(CF_UNICODETEXT) }
}

func setClipboardHandle(handle: CPointer<Unit>): CPointer<Unit> {
    let f = CFunc<(UInt32, CPointer<Unit>) -> CPointer<Unit>>(clipboardSymbol("SetClipboardData"))
    unsafe { f(CF_UNICODETEXT, handle) }
}

func globalAllocHandle(bytes: Int64): CPointer<Unit> {
    let f = CFunc<(UInt32, UIntNative) -> CPointer<Unit>>(clipboardSymbol("GlobalAlloc"))
    unsafe { f(GMEM_MOVEABLE, UIntNative(bytes)) }
}

func globalLockHandle(handle: CPointer<Unit>): CPointer<UInt8> {
    let f = CFunc<(CPointer<Unit>) -> CPointer<UInt8>>(clipboardSymbol("GlobalLock"))
    unsafe { f(handle) }
}

func globalUnlockHandle(handle: CPointer<Unit>): Unit {
    let f = CFunc<(CPointer<Unit>) -> Int32>(clipboardSymbol("GlobalUnlock"))
    unsafe { f(handle) }
}

func globalFreeHandle(handle: CPointer<Unit>): Unit {
    let f = CFunc<(CPointer<Unit>) -> CPointer<Unit>>(clipboardSymbol("GlobalFree"))
    unsafe { f(handle) }
}

// UTF-16 buffer byte count, including the terminating zero code unit.
func utf16ByteCount(text: String): Int64 {
    var units: Int64 = 0
    for (r in text.runes()) {
        if (UInt32(r) > 0xFFFF) {
            units += 2
        } else {
            units += 1
        }
    }
    (units + 1) * 2
}

func copyBytes(src: CPointer<UInt8>, dst: CPointer<UInt8>, count: Int64): Unit {
    var i: Int64 = 0
    while (i < count) {
        let b = unsafe { src.read(i) }
        unsafe { dst.write(i, b) }
        i += 1
    }
}

public class Win32Clipboard {
    public init() {}

    // Returns the clipboard text, or "" when the clipboard cannot be opened or
    // holds no CF_UNICODETEXT payload. Never throws.
    public func getText(): String {
        var text = ""
        try {
            if (!isClipboardFormatAvailable()) {
                return ""
            }
            if (!openClipboardWithRetry()) {
                return ""
            }
            try {
                let handle = getClipboardHandle()
                if (!handle.isNull()) {
                    let locked = globalLockHandle(handle)
                    if (!locked.isNull()) {
                        try {
                            text = fromUtf16(CPointer<UInt16>(locked))
                        } finally {
                            globalUnlockHandle(handle)
                        }
                    }
                }
            } finally {
                closeClipboardHandle()
            }
        } catch (e: Exception) {
            text = ""
        }
        text
    }

    // Writes text to the clipboard. Returns false instead of throwing when the
    // clipboard is unavailable; failures are never surfaced to callers.
    public func setText(text: String): Bool {
        let buffer = toUtf16(text)
        let byteCount = utf16ByteCount(text)
        var success = false
        var handle = CPointer<Unit>()
        try {
            if (!openClipboardWithRetry()) {
                return false
            }
            try {
                if (!emptyClipboardHandle()) {
                    return false
                }
                handle = globalAllocHandle(byteCount)
                if (handle.isNull()) {
                    return false
                }
                let target = globalLockHandle(handle)
                if (target.isNull()) {
                    return false
                }
                copyBytes(buffer.getChars(), target, byteCount)
                globalUnlockHandle(handle)
                if (!setClipboardHandle(handle).isNull()) {
                    // Ownership moved to the clipboard: do not free it.
                    success = true
                    handle = CPointer<Unit>()
                }
            } finally {
                closeClipboardHandle()
            }
        } catch (e: Exception) {
            success = false
        } finally {
            if (!handle.isNull()) {
                globalFreeHandle(handle)
            }
            freeCString(buffer)
        }
        success
    }
}
