import Foundation
import CellarCore

public struct SimulatedRuntimeBridge: RuntimeBridging, Sendable {
    public var startupDelay: Duration
    public var lineDelay: Duration
    public var logLines: [String]
    public var interactiveMessage: String?
    public var exitCode: Int32
    public var failureMessage: String?

    public init(
        startupDelay: Duration = .milliseconds(40),
        lineDelay: Duration = .milliseconds(10),
        logLines: [String] = [],
        interactiveMessage: String? = "Renderer initialized.",
        exitCode: Int32 = 0,
        failureMessage: String? = nil
    ) {
        self.startupDelay = startupDelay
        self.lineDelay = lineDelay
        self.logLines = logLines
        self.interactiveMessage = interactiveMessage
        self.exitCode = exitCode
        self.failureMessage = failureMessage
    }

    public func launch(
        container: ContainerDescriptor,
        decision: PlanningDecision,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) -> AsyncStream<RuntimeBridgeEvent> {
        AsyncStream { continuation in
            Task {
                continuation.yield(
                    .preparing(
                        message: "Preparing \(container.title) for \(decision.backend.rawValue) in \(productLane.rawValue) lane."
                    )
                )
                try? await Task.sleep(for: startupDelay)
                continuation.yield(.started)

                for line in resolvedLogLines(container: container, decision: decision, capabilities: capabilities) {
                    continuation.yield(.log(line))
                    try? await Task.sleep(for: lineDelay)
                }

                if let interactiveMessage {
                    continuation.yield(.interactive(message: interactiveMessage))
                }

                try? await Task.sleep(for: lineDelay)
                if let failureMessage {
                    continuation.yield(.failed(message: failureMessage))
                } else {
                    continuation.yield(.exited(exitCode: exitCode))
                }
                continuation.finish()
            }
        }
    }

    private func resolvedLogLines(
        container: ContainerDescriptor,
        decision: PlanningDecision,
        capabilities: RuntimeCapabilities
    ) -> [String] {
        if !logLines.isEmpty {
            return logLines
        }

        return [
            "container=\(container.id.uuidString)",
            "backend=\(decision.backend.rawValue)",
            "distribution=\(capabilities.distributionChannel.rawValue)",
            "jit=\(capabilities.jitMode.rawValue)"
        ]
    }
}
