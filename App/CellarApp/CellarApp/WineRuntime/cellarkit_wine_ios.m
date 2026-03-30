/*
 * cellarkit_wine_ios.m — in-process Wine execution on iOS.
 *
 * Bridges WineServerBridge + WineProcessBridge (from Mythic) into
 * CellarKit's callback-based log stream.
 *
 * Compiled only on physical iOS (TARGET_OS_IOS && !TARGET_OS_SIMULATOR).
 * On Simulator: posix_spawn in cellarkit_bridge.c handles execution.
 */

#if TARGET_OS_IOS && !TARGET_OS_SIMULATOR

#import <Foundation/Foundation.h>
#import <os/log.h>
#import <pthread.h>
#import <unistd.h>
#import <fcntl.h>
#import <sys/socket.h>

#include "cellarkit_wine_ios.h"
#include "WineServerBridge.h"
#include "WineProcessBridge.h"
#include <string.h>

// ── global log routing ─────────────────────────────────────────────

static cellarkit_wine_log_cb  g_log_cb  = NULL;
static void                  *g_log_ctx = NULL;
static pthread_mutex_t        g_log_mutex = PTHREAD_MUTEX_INITIALIZER;

// Called from WineServerBridge's wine_ui_log() — forwards to our callback.
void wine_ui_log(const char *message) {
    pthread_mutex_lock(&g_log_mutex);
    if (g_log_cb && message) {
        char buf[2048];
        snprintf(buf, sizeof(buf), "[wine] %s", message);
        g_log_cb(g_log_ctx, buf);
    }
    pthread_mutex_unlock(&g_log_mutex);
}

// ── stdout/stderr capture pipe ──────────────────────────────────────

static pthread_t  g_stdout_thread;
static int        g_stdout_pipe[2] = {-1, -1};  // [read, write]
static int        g_saved_stdout   = -1;

static void *stdout_drain_thread(void *arg) {
    int rfd = *(int *)arg;
    char buf[4096];
    while (1) {
        ssize_t n = read(rfd, buf, sizeof(buf) - 1);
        if (n <= 0) break;
        buf[n] = '\0';
        // Split on newlines and forward each line.
        char *line = buf;
        char *nl;
        while ((nl = strchr(line, '\n')) != NULL) {
            *nl = '\0';
            if (*line) {
                pthread_mutex_lock(&g_log_mutex);
                if (g_log_cb) g_log_cb(g_log_ctx, line);
                pthread_mutex_unlock(&g_log_mutex);
            }
            line = nl + 1;
        }
        if (*line) {
            pthread_mutex_lock(&g_log_mutex);
            if (g_log_cb) g_log_cb(g_log_ctx, line);
            pthread_mutex_unlock(&g_log_mutex);
        }
    }
    return NULL;
}

static void setup_stdout_capture(void) {
    if (pipe(g_stdout_pipe) != 0) return;
    // Make read end non-blocking so drain thread doesn't wedge.
    fcntl(g_stdout_pipe[0], F_SETFL, O_NONBLOCK);
    g_saved_stdout = dup(STDOUT_FILENO);
    dup2(g_stdout_pipe[1], STDOUT_FILENO);
    close(g_stdout_pipe[1]);
    g_stdout_pipe[1] = -1;
    static int rfd;
    rfd = g_stdout_pipe[0];
    pthread_create(&g_stdout_thread, NULL, stdout_drain_thread, &rfd);
}

static void teardown_stdout_capture(void) {
    if (g_saved_stdout >= 0) {
        dup2(g_saved_stdout, STDOUT_FILENO);
        close(g_saved_stdout);
        g_saved_stdout = -1;
    }
    if (g_stdout_pipe[0] >= 0) {
        close(g_stdout_pipe[0]);
        g_stdout_pipe[0] = -1;
    }
    pthread_join(g_stdout_thread, NULL);
}

// ── public API ─────────────────────────────────────────────────────

int cellarkit_wine_run(
    const char           *exe_path,
    const char           *prefix_path,
    cellarkit_wine_log_cb log_cb,
    void                 *ctx)
{
    pthread_mutex_lock(&g_log_mutex);
    g_log_cb  = log_cb;
    g_log_ctx = ctx;
    pthread_mutex_unlock(&g_log_mutex);

    if (!prefix_path || !exe_path) {
        if (log_cb) log_cb(ctx, "[wine-ios] missing exe_path or prefix_path");
        return -1;
    }

    // Ensure prefix directory exists.
    [[NSFileManager defaultManager]
        createDirectoryAtPath:[NSString stringWithUTF8String:prefix_path]
  withIntermediateDirectories:YES attributes:nil error:nil];

    if (log_cb) {
        char msg[1024];
        snprintf(msg, sizeof(msg),
                 "[wine-ios] starting wineserver | prefix=%s", prefix_path);
        log_cb(ctx, msg);
    }

    // 1. Start wineserver as a background thread.
    if (wineserver_start(prefix_path) != 0) {
        if (log_cb) log_cb(ctx, "[wine-ios] wineserver_start failed");
        return -1;
    }

    // Wait for wineserver to become ready (up to 5 s).
    for (int i = 0; i < 50; i++) {
        if (wineserver_is_running()) break;
        usleep(100000);  // 100 ms
    }
    if (!wineserver_is_running()) {
        if (log_cb) log_cb(ctx, "[wine-ios] wineserver did not start in time");
        return -1;
    }
    if (log_cb) log_cb(ctx, "[wine-ios] wineserver running");

    // 2. Redirect stdout so Wine's printf output comes back through our callback.
    setup_stdout_capture();

    // 3. Set WINEPREFIX + exe environment.
    setenv("WINEPREFIX",       prefix_path, 1);
    setenv("WINELOADERNOEXEC", "1",         1);
    setenv("WINEDEBUG",        "-all",      1);  // suppress noise

    // Point Wine at the bundled ARM64 DLLs.
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *dllPath    = [bundlePath stringByAppendingPathComponent:@"aarch64-windows"];
    setenv("WINEDLLPATH", dllPath.UTF8String, 1);

    if (log_cb) {
        char msg[1024];
        snprintf(msg, sizeof(msg),
                 "[wine-ios] launching %s | dlls=%s", exe_path, dllPath.UTF8String);
        log_cb(ctx, msg);
    }

    // 4. Launch Wine ntdll in-process.
    if (wine_process_start(prefix_path) != 0) {
        teardown_stdout_capture();
        if (log_cb) log_cb(ctx, "[wine-ios] wine_process_start failed");
        return -1;
    }

    // Wait for the Wine process thread to finish.
    // wine_process_start blocks internally, so we poll.
    while (wine_process_is_running()) {
        usleep(200000);  // 200 ms
    }

    teardown_stdout_capture();

    if (log_cb) log_cb(ctx, "[wine-ios] wine process exited");
    return 0;
}

int cellarkit_wine_server_running(void) {
    return wineserver_is_running();
}

void cellarkit_wine_teardown(void) {
    wineserver_stop();
}

#endif /* TARGET_OS_IOS && !TARGET_OS_SIMULATOR */
