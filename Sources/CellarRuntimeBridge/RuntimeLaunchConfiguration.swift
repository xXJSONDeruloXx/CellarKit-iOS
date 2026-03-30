import Foundation
import CellarCore

public struct RuntimeLaunchConfiguration: Equatable, Sendable {
    public var title: String
    public var backend: ExecutionBackend
    public var productLane: ProductLane
    public var graphicsBackend: GraphicsBackend
    public var distributionChannel: DistributionChannel
    public var jitMode: JITMode
    public var contentMode: ImportedContentMode?
    public var contentPath: String?
    public var entryExecutableRelativePath: String?
    public var resolvedExecutablePath: String?
    /// Absolute path to the Wine binary (or wine-stub) to posix_spawn.
    /// Nil means fall back to legacy simulated events.
    public var runtimeBinaryPath: String?
    /// When true the bridge uses Wine argv: `[wine64, exe_path]`.
    /// When false it uses wine-stub argv: `[stub, --exe, exe_path, ...]`.
    public var runtimeIsWine: Bool
    /// WINEPREFIX passed as an env var to the Wine child process.
    public var winePrefixPath: String?
    /// WINEDEBUG spec, e.g. "-all". Nil = Wine default.
    public var wineDebug: String?
    public var bookmarkIdentifier: String?
    public var memoryBudgetMB: Int
    public var shaderCacheBudgetMB: Int

    public init(
        title: String,
        backend: ExecutionBackend,
        productLane: ProductLane,
        graphicsBackend: GraphicsBackend,
        distributionChannel: DistributionChannel,
        jitMode: JITMode,
        contentMode: ImportedContentMode?,
        contentPath: String?,
        entryExecutableRelativePath: String? = nil,
        resolvedExecutablePath: String? = nil,
        runtimeBinaryPath: String? = nil,
        runtimeIsWine: Bool = false,
        winePrefixPath: String? = nil,
        wineDebug: String? = nil,
        bookmarkIdentifier: String?,
        memoryBudgetMB: Int,
        shaderCacheBudgetMB: Int
    ) {
        self.title = title
        self.backend = backend
        self.productLane = productLane
        self.graphicsBackend = graphicsBackend
        self.distributionChannel = distributionChannel
        self.jitMode = jitMode
        self.contentMode = contentMode
        self.contentPath = contentPath
        self.entryExecutableRelativePath = entryExecutableRelativePath
        self.resolvedExecutablePath = resolvedExecutablePath
        self.runtimeBinaryPath = runtimeBinaryPath
        self.runtimeIsWine = runtimeIsWine
        self.winePrefixPath = winePrefixPath
        self.wineDebug = wineDebug
        self.bookmarkIdentifier = bookmarkIdentifier
        self.memoryBudgetMB = memoryBudgetMB
        self.shaderCacheBudgetMB = shaderCacheBudgetMB
    }
}

// MARK: - Factory

public struct RuntimeLaunchConfigurationFactory: Sendable {
    /// When false, skips system wine64 lookup and uses wine-stub / legacy mode.
    /// Set to false in unit tests so test results don’t depend on the host’s
    /// Wine installation.
    public var allowSystemWine: Bool

    public init(allowSystemWine: Bool = true) {
        self.allowSystemWine = allowSystemWine
    }

    public func makeConfiguration(
        container: ContainerDescriptor,
        decision: PlanningDecision,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) -> RuntimeLaunchConfiguration {
        let contentPath = container.contentReference?.pathHint ?? container.importPath
        let entryExecutableRelativePath = container.entryExecutableRelativePath

        let runtime = resolveRuntime()

        return RuntimeLaunchConfiguration(
            title: container.title,
            backend: decision.backend,
            productLane: productLane,
            graphicsBackend: container.runtimeProfile.graphicsBackend,
            distributionChannel: capabilities.distributionChannel,
            jitMode: capabilities.jitMode,
            contentMode: container.contentReference?.mode,
            contentPath: contentPath,
            entryExecutableRelativePath: entryExecutableRelativePath,
            resolvedExecutablePath: resolveExecutablePath(
                contentPath: contentPath,
                entryExecutableRelativePath: entryExecutableRelativePath
            ),
            runtimeBinaryPath: runtime.binaryPath,
            runtimeIsWine: runtime.isWine,
            winePrefixPath: runtime.isWine ? resolveWinePrefix() : nil,
            wineDebug: runtime.isWine ? "-all" : nil,
            bookmarkIdentifier: container.contentReference?.bookmarkIdentifier,
            memoryBudgetMB: container.runtimeProfile.memoryBudgetMB,
            shaderCacheBudgetMB: container.runtimeProfile.shaderCacheBudgetMB
        )
    }

    // MARK: - Runtime resolution

    private struct ResolvedRuntime {
        let binaryPath: String?
        let isWine: Bool
    }

    /// Priority order:
    /// 1. System wine64 (macOS-native; works when running in the iOS simulator
    ///    because the simulator process is a macOS process).
    /// 2. wine-stub in the app bundle (placeholder for device / CI builds).
    /// 3. nil → legacy simulated events.
    private func resolveRuntime() -> ResolvedRuntime {
        if allowSystemWine, let wine = resolveSystemWine64() {
            return ResolvedRuntime(binaryPath: wine, isWine: true)
        }
        return ResolvedRuntime(binaryPath: resolveWineStub(), isWine: false)
    }

    /// Looks for a system-installed wine64 binary.
    /// Checks the Homebrew prefix and the Wine Crossover app bundle.
    private func resolveSystemWine64() -> String? {
        let candidates = [
            "/opt/homebrew/bin/wine64",                                            // Homebrew symlink (ARM or Rosetta)
            "/usr/local/bin/wine64",                                               // Intel Homebrew
            "/Applications/Wine Crossover.app/Contents/Resources/wine/bin/wine64",// direct bundle path
            "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine64",
        ]
        let fm = FileManager.default
        for path in candidates where fm.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    /// Looks for `wine-stub` inside the app bundle.
    ///
    /// `xcrun simctl install` strips the executable bit from non-main binaries,
    /// so we copy the binary to the writable tmp directory and chmod it before
    /// handing the path to the C bridge for posix_spawn.
    private func resolveWineStub() -> String? {
        let fm = FileManager.default

        // Primary: <Bundle>/Binaries/wine-stub (placed by Xcode build phase)
        let inBundle = (Bundle.main.bundlePath as NSString)
            .appendingPathComponent("Binaries/wine-stub")
        let source: String
        if fm.fileExists(atPath: inBundle) {
            source = inBundle
        } else if let fallback = Bundle.main.path(forResource: "wine-stub", ofType: nil),
                  fm.fileExists(atPath: fallback) {
            source = fallback
        } else {
            return nil
        }

        // Copy to a writable location and chmod +x.
        let dest = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("wine-stub")
        do {
            if fm.fileExists(atPath: dest) { try fm.removeItem(atPath: dest) }
            try fm.copyItem(atPath: source, toPath: dest)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
            return dest
        } catch {
            return source   // best-effort fallback
        }
    }

    /// Returns a writable WINEPREFIX path inside the app's Library directory.
    /// Wine will create it on first launch.
    private func resolveWinePrefix() -> String? {
        guard let library = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask).first
        else { return nil }

        let prefix = library
            .appendingPathComponent("CellarKit")
            .appendingPathComponent("WinePrefix")
        // Ensure the parent directory exists (Wine creates WinePrefix itself)
        try? FileManager.default.createDirectory(
            at: library.appendingPathComponent("CellarKit"),
            withIntermediateDirectories: true
        )
        return prefix.path(percentEncoded: false)
    }

    // MARK: - Executable resolution

    private func resolveExecutablePath(
        contentPath: String?,
        entryExecutableRelativePath: String?
    ) -> String? {
        guard let contentPath else { return nil }

        let contentURL = URL(fileURLWithPath: contentPath)
        if let isDirectory = try? contentURL.resourceValues(
            forKeys: [.isDirectoryKey]).isDirectory,
           isDirectory == true
        {
            guard let entryExecutableRelativePath,
                  !entryExecutableRelativePath.isEmpty else { return nil }
            return contentURL.appending(path: entryExecutableRelativePath)
                .path(percentEncoded: false)
        }
        return contentPath
    }
}
