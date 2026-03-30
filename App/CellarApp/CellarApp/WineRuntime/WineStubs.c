/*
 * WineStubs.c — stub implementations for Wine iOS missing symbols.
 *
 * wine_build    : Wine version string (printed in debug logs).
 * __clear_cache : Instruction cache flush (compiler-rt builtin; provided
 *                 by the iOS system on arm64 but not auto-linked from .a files).
 * IOPowerSources: macOS-only battery APIs; stubbed to safe defaults on iOS.
 */

#include <stddef.h>
#include <stdlib.h>
#include <libkern/OSCacheControl.h>   /* sys_icache_invalidate */

/* Wine version string exposed as a global symbol. */
const char wine_build[] = "CellarKit-Wine-iOS-1.0 (arm64)";

/* Instruction cache flush — compiler-rt builtin, provided here for .a linkage. */
void __clear_cache(void *start, void *end) {
    sys_icache_invalidate(start, (char *)end - (char *)start);
}

/* ── IOKit Power Source stubs (macOS-only, not on iOS) ─────────────
 * ntdll/unix/system.c calls these to query battery status.
 * On iOS there is no IOPowerSources API; return safe NULL/empty values.  */
#include <CoreFoundation/CoreFoundation.h>

CFTypeRef IOPSCopyPowerSourcesInfo(void) {
    return CFDictionaryCreate(NULL, NULL, NULL, 0,
                              &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}

CFArrayRef IOPSCopyPowerSourcesList(CFTypeRef blob) {
    (void)blob;
    return CFArrayCreate(NULL, NULL, 0, &kCFTypeArrayCallBacks);
}

CFDictionaryRef IOPSGetPowerSourceDescription(CFTypeRef blob, CFTypeRef ps) {
    (void)blob; (void)ps;
    return NULL;
}
