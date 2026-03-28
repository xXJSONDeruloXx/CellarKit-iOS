import Foundation

public enum GraphicsBackend: String, Codable, CaseIterable, Sendable {
    case dxvkMoltenVK
    case vkd3dMoltenVK
    case wined3dFallback
    case diagnosticOnly
}

public struct RuntimeProfile: Codable, Equatable, Sendable {
    public var backendPreference: ExecutionBackend
    public var graphicsBackend: GraphicsBackend
    public var touchOverlayEnabled: Bool
    public var prefersPhysicalController: Bool
    public var memoryBudgetMB: Int
    public var shaderCacheBudgetMB: Int

    public init(
        backendPreference: ExecutionBackend,
        graphicsBackend: GraphicsBackend,
        touchOverlayEnabled: Bool = true,
        prefersPhysicalController: Bool = true,
        memoryBudgetMB: Int = 1536,
        shaderCacheBudgetMB: Int = 256
    ) {
        self.backendPreference = backendPreference
        self.graphicsBackend = graphicsBackend
        self.touchOverlayEnabled = touchOverlayEnabled
        self.prefersPhysicalController = prefersPhysicalController
        self.memoryBudgetMB = memoryBudgetMB
        self.shaderCacheBudgetMB = shaderCacheBudgetMB
    }
}

public struct ContainerDescriptor: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var storefront: Storefront
    public var acquisitionMode: AcquisitionMode
    public var guestArchitecture: GuestBinaryArchitecture
    public var importPath: String?
    public var runtimeProfile: RuntimeProfile
    public var lastLaunchedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        storefront: Storefront,
        acquisitionMode: AcquisitionMode,
        guestArchitecture: GuestBinaryArchitecture,
        importPath: String? = nil,
        runtimeProfile: RuntimeProfile,
        lastLaunchedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.storefront = storefront
        self.acquisitionMode = acquisitionMode
        self.guestArchitecture = guestArchitecture
        self.importPath = importPath
        self.runtimeProfile = runtimeProfile
        self.lastLaunchedAt = lastLaunchedAt
    }
}
