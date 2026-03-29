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
        RuntimeLaunchConfiguration(
            title: container.title,
            backend: decision.backend,
            productLane: productLane,
            graphicsBackend: container.runtimeProfile.graphicsBackend,
            distributionChannel: capabilities.distributionChannel,
            jitMode: capabilities.jitMode,
            contentMode: container.contentReference?.mode,
            contentPath: container.contentReference?.pathHint ?? container.importPath,
            bookmarkIdentifier: container.contentReference?.bookmarkIdentifier,
            memoryBudgetMB: container.runtimeProfile.memoryBudgetMB,
            shaderCacheBudgetMB: container.runtimeProfile.shaderCacheBudgetMB
        )
    }
}
