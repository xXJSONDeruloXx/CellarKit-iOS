import Foundation
import CellarCore

public enum RuntimeBridgeEvent: Equatable, Sendable {
    case preparing(message: String)
    case started
    case log(String)
    case interactive(message: String?)
    case exited(exitCode: Int32)
    case failed(message: String)
}

public protocol RuntimeBridging: Sendable {
    func launch(
        container: ContainerDescriptor,
        decision: PlanningDecision,
        capabilities: RuntimeCapabilities,
        productLane: ProductLane
    ) -> AsyncStream<RuntimeBridgeEvent>
}
