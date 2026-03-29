import Foundation

public extension ContainerDescriptor {
    var launchRequest: GameLaunchRequest {
        GameLaunchRequest(
            title: title,
            storefront: storefront,
            acquisitionMode: acquisitionMode,
            guestArchitecture: guestArchitecture,
            requiresGraphicsTranslation: runtimeProfile.graphicsBackend != .diagnosticOnly,
            allowsInterpreterFallback: true,
            allowsDiagnosticVMFallback: true
        )
    }
}
