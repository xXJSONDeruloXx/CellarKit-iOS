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
            bookmarkIdentifier: container.contentReference?.bookmarkIdentifier,
            memoryBudgetMB: container.runtimeProfile.memoryBudgetMB,
            shaderCacheBudgetMB: container.runtimeProfile.shaderCacheBudgetMB
        )
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
