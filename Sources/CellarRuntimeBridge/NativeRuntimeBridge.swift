import Foundation
import CellarCore
import CellarHost
import CCellarBridgeStub

public struct NativeRuntimeBridge: RuntimeBridging, Sendable {
    public var exitCode: Int32
    public var emitFailure: Bool

    public init(exitCode: Int32 = 0, emitFailure: Bool = false) {
        self.exitCode = exitCode
        self.emitFailure = emitFailure
    }

    public func launch(
        container: ContainerDescriptor,
        decision: PlanningDecision,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) -> AsyncStream<RuntimeBridgeEvent> {
        AsyncStream { continuation in
            let context = NativeBridgeContext(continuation: continuation)
            let opaque = Unmanaged.passRetained(context).toOpaque()

            Task.detached {
                container.title.withCString { titlePointer in
                    decision.backend.rawValue.withCString { backendPointer in
                        productLane.rawValue.withCString { lanePointer in
                            let config = cellarkit_bridge_config(
                                title: titlePointer,
                                backend: backendPointer,
                                product_lane: lanePointer,
                                exit_code: exitCode,
                                emit_failure: emitFailure ? 1 : 0
                            )
                            cellarkit_bridge_run(config, opaque, nativeBridgeCallback)
                        }
                    }
                }

                let retained = Unmanaged<NativeBridgeContext>.fromOpaque(opaque)
                retained.release()
                continuation.finish()
                _ = capabilities
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
