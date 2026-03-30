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
        self.bookmarkIdentifier = bookmarkIdentifier
        self.memoryBudgetMB = memoryBudgetMB
        self.shaderCacheBudgetMB = shaderCacheBudgetMB
    }
}

public struct RuntimeLaunchConfigurationFactory: Sendable {
    public init() {}

    public func makeConfiguration(
        container: ContainerDescriptor,
        decision: PlanningDecision,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) -> RuntimeLaunchConfiguration {
        let contentPath = container.contentReference?.pathHint ?? container.importPath
        let entryExecutableRelativePath = container.entryExecutableRelativePath

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
            runtimeBinaryPath: resolveRuntimeBinaryPath(),
            bookmarkIdentifier: container.contentReference?.bookmarkIdentifier,
            memoryBudgetMB: container.runtimeProfile.memoryBudgetMB,
            shaderCacheBudgetMB: container.runtimeProfile.shaderCacheBudgetMB
        )
    }

    /// Looks for `wine-stub` (or eventually `wine`) inside the app bundle.
    ///
    /// `xcrun simctl install` strips the executable bit from non-main binaries,
    /// so we copy the binary to the writable tmp directory and chmod it before
    /// handing the path to the C bridge for posix_spawn.
    /// Returns nil if not found — bridge falls back to legacy simulated events.
    private func resolveRuntimeBinaryPath() -> String? {
        let fm = FileManager.default

        // Find the binary in the bundle.
        let bundlePath = Bundle.main.bundlePath
        let inBundle = (bundlePath as NSString).appendingPathComponent("Binaries/wine-stub")
        let source: String
        if fm.fileExists(atPath: inBundle) {
            source = inBundle
        } else if let fallback = Bundle.main.path(forResource: "wine-stub", ofType: nil),
                  fm.fileExists(atPath: fallback) {
            source = fallback
        } else {
            return nil
        }

        // Copy to a writable location and set the executable bit.
        // (simctl install strips the +x bit from non-main bundle executables.)
        let dest = (NSTemporaryDirectory() as NSString).appendingPathComponent("wine-stub")
        do {
            if fm.fileExists(atPath: dest) { try fm.removeItem(atPath: dest) }
            try fm.copyItem(atPath: source, toPath: dest)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
            return dest
        } catch {
            // If we can't copy, try the bundle path directly (might still work)
            return source
        }
    }

    private func resolveExecutablePath(
        contentPath: String?,
        entryExecutableRelativePath: String?
    ) -> String? {
        guard let contentPath else {
            return nil
        }

        let contentURL = URL(fileURLWithPath: contentPath)
        if let isDirectory = try? contentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
           isDirectory == true {
            guard let entryExecutableRelativePath, !entryExecutableRelativePath.isEmpty else {
                return nil
            }
            return contentURL.appending(path: entryExecutableRelativePath).path
        }

        return contentPath
    }
}
