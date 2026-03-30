#pragma once
/*
 * cellarkit_wine_ios.h — in-process Wine execution on iOS (real device).
 *
 * Wraps the Mythic WineServerBridge + WineProcessBridge pattern:
 *   1. wineserver runs as a background pthread (no posix_spawn)
 *   2. ntdll Unix loader called in-process via __wine_main()
 *   3. ARM64 PE binaries execute natively (no JIT needed)
 *   4. x86-64 PE binaries require FEX-Emu JIT (future)
 *
 * On iOS Simulator this path is not used — posix_spawn works there.
 * On physical iOS hardware: posix_spawn → EPERM, this path is used instead.
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* Log callback: called for each line of Wine output. */
typedef void (*cellarkit_wine_log_cb)(void *ctx, const char *line);

/*
 * Run a Windows PE binary in-process via Wine.
 *
 * exe_path     – absolute path to the .exe inside the Wine prefix
 * prefix_path  – absolute path to the WINEPREFIX directory
 * log_cb       – called for each log line (may be called from any thread)
 * ctx          – opaque pointer forwarded to log_cb
 *
 * Blocks until the guest process exits.
 * Returns the Windows exit code (0 = success), or -1 on launch failure.
 */
int cellarkit_wine_run(
    const char           *exe_path,
    const char           *prefix_path,
    cellarkit_wine_log_cb log_cb,
    void                 *ctx
);

/* Returns 1 if an in-process wineserver is currently running. */
int cellarkit_wine_server_running(void);

/* Tear down the wineserver thread (call after guest process exits). */
void cellarkit_wine_teardown(void);

#ifdef __cplusplus
}
#endif
