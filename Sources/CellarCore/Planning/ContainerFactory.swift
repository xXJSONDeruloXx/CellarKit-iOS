import Foundation

public struct ContainerFactory: Sendable {
    public init() {}

    public func makeDescriptor(
        from request: GameLaunchRequest,
        decision: PlanningDecision,
        contentReference: ImportedContentReference? = nil,
        entryExecutableRelativePath: String? = nil,
        titleOverride: String? = nil
    ) -> ContainerDescriptor {
        let title = titleOverride ?? request.title
        return ContainerDescriptor(
            title: title,
            storefront: request.storefront,
            acquisitionMode: request.acquisitionMode,
            guestArchitecture: request.guestArchitecture,
            importPath: contentReference?.pathHint,
            contentReference: contentReference,
            entryExecutableRelativePath: entryExecutableRelativePath,
            runtimeProfile: makeRuntimeProfile(request: request, decision: decision),
            lastLaunchedAt: nil
        )
    }

    public func makeRuntimeProfile(
        request: GameLaunchRequest,
        decision: PlanningDecision
    ) -> RuntimeProfile {
        let graphicsBackend: GraphicsBackend = switch decision.backend {
        case .wineARM64, .wineARM64EC, .wineX64Translator:
            request.requiresGraphicsTranslation ? .dxvkMoltenVK : .diagnosticOnly
        case .wineThreadedInterpreter:
            request.requiresGraphicsTranslation ? .wined3dFallback : .diagnosticOnly
        case .diagnosticVM, .unsupported:
            .diagnosticOnly
        }

        let memoryBudgetMB: Int = switch decision.backend {
        case .wineARM64:
            1536
        case .wineARM64EC:
            1792
        case .wineX64Translator:
            2048
        case .wineThreadedInterpreter:
            1280
        case .diagnosticVM, .unsupported:
            1024
        }

        let shaderCacheBudgetMB: Int = switch graphicsBackend {
        case .dxvkMoltenVK, .vkd3dMoltenVK:
            256
        case .wined3dFallback:
            128
        case .diagnosticOnly:
            64
        }

        return RuntimeProfile(
            backendPreference: decision.backend,
            graphicsBackend: graphicsBackend,
            touchOverlayEnabled: true,
            prefersPhysicalController: true,
            memoryBudgetMB: memoryBudgetMB,
            shaderCacheBudgetMB: shaderCacheBudgetMB
        )
    }
}
