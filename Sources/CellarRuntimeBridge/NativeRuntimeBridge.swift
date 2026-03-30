import Foundation
import CellarCore
import CellarHost
import CCellarBridgeStub

public struct NativeRuntimeBridge: RuntimeBridging, Sendable {
    public var exitCode: Int32
    public var emitFailure: Bool
    public var configurationFactory: RuntimeLaunchConfigurationFactory

    public init(
        exitCode: Int32 = 0,
        emitFailure: Bool = false,
        configurationFactory: RuntimeLaunchConfigurationFactory = RuntimeLaunchConfigurationFactory()
    ) {
        self.exitCode = exitCode
        self.emitFailure = emitFailure
        self.configurationFactory = configurationFactory
    }

    public func launch(
        container: ContainerDescriptor,
        decision: PlanningDecision,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) -> AsyncStream<RuntimeBridgeEvent> {
        let configuration = configurationFactory.makeConfiguration(
            container: container,
            decision: decision,
            capabilities: capabilities,
            productLane: productLane
        )

        return AsyncStream { continuation in
            let context = NativeBridgeContext(continuation: continuation)
            let opaque = Unmanaged.passRetained(context).toOpaque()

            Task.detached {
                withOptionalCString(configuration.contentMode?.rawValue) { contentModePtr in
                withOptionalCString(configuration.contentPath) { contentPathPtr in
                withOptionalCString(configuration.entryExecutableRelativePath) { entryExePtr in
                withOptionalCString(configuration.resolvedExecutablePath) { resolvedExePtr in
                withOptionalCString(configuration.bookmarkIdentifier) { bookmarkPtr in
                withOptionalCString(configuration.runtimeBinaryPath) { runtimeBinPtr in
                withOptionalCString(configuration.winePrefixPath) { winePrefixPtr in
                withOptionalCString(configuration.wineDebug) { wineDebugPtr in
                    configuration.title.withCString { titlePtr in
                    configuration.backend.rawValue.withCString { backendPtr in
                    configuration.productLane.rawValue.withCString { lanePtr in
                    configuration.graphicsBackend.rawValue.withCString { graphicsPtr in
                    configuration.distributionChannel.rawValue.withCString { distPtr in
                    configuration.jitMode.rawValue.withCString { jitPtr in
                        let config = cellarkit_bridge_config(
                            title: titlePtr,
                            backend: backendPtr,
                            product_lane: lanePtr,
                            graphics_backend: graphicsPtr,
                            distribution_channel: distPtr,
                            jit_mode: jitPtr,
                            content_mode: contentModePtr,
                            content_path: contentPathPtr,
                            entry_executable_relative_path: entryExePtr,
                            resolved_executable_path: resolvedExePtr,
                            runtime_binary_path: runtimeBinPtr,
                            runtime_is_wine: configuration.runtimeIsWine ? 1 : 0,
                            wineprefix_path: winePrefixPtr,
                            winedebug: wineDebugPtr,
                            memory_budget_mb: Int32(configuration.memoryBudgetMB),
                            shader_cache_budget_mb: Int32(configuration.shaderCacheBudgetMB),
                            has_bookmark: bookmarkPtr == nil ? 0 : 1,
                            exit_code: exitCode,
                            emit_failure: emitFailure ? 1 : 0
                        )
                        cellarkit_bridge_run(config, opaque, nativeBridgeCallback)
                    }
                    }
                    }
                    }
                    }
                    }
                }
                }
                }
                }
                }
                }
                }
                }

                let retained = Unmanaged<NativeBridgeContext>.fromOpaque(opaque)
                retained.release()
                continuation.finish()
            }
        }
    }
}

private final class NativeBridgeContext {
    let continuation: AsyncStream<RuntimeBridgeEvent>.Continuation

    init(continuation: AsyncStream<RuntimeBridgeEvent>.Continuation) {
        self.continuation = continuation
    }

    func emit(kind: Int32, message: String?, value: Int32) {
        switch kind {
        case Int32(CELLARKIT_BRIDGE_EVENT_PREPARING):
            continuation.yield(.preparing(message: message ?? "Preparing native runtime bridge."))
        case Int32(CELLARKIT_BRIDGE_EVENT_STARTED):
            continuation.yield(.started)
        case Int32(CELLARKIT_BRIDGE_EVENT_LOG):
            continuation.yield(.log(message ?? ""))
        case Int32(CELLARKIT_BRIDGE_EVENT_INTERACTIVE):
            continuation.yield(.interactive(message: message))
        case Int32(CELLARKIT_BRIDGE_EVENT_EXITED):
            continuation.yield(.exited(exitCode: value))
        case Int32(CELLARKIT_BRIDGE_EVENT_FAILED):
            continuation.yield(.failed(message: message ?? "Native runtime bridge reported a failure."))
        default:
            continuation.yield(.log(message ?? "Unknown native bridge event."))
        }
    }
}

private func withOptionalCString<Result>(
    _ string: String?,
    _ body: (UnsafePointer<CChar>?) -> Result
) -> Result {
    guard let string else {
        return body(nil)
    }
    return string.withCString(body)
}

private let nativeBridgeCallback: @convention(c) (
    UnsafeMutableRawPointer?,
    Int32,
    UnsafePointer<CChar>?,
    Int32
) -> Void = { context, kind, message, value in
    guard let context else {
        return
    }

    let bridgeContext = Unmanaged<NativeBridgeContext>.fromOpaque(context).takeUnretainedValue()
    let resolvedMessage = message.map { String(cString: $0) }
    bridgeContext.emit(kind: kind, message: resolvedMessage, value: value)
}
