import SwiftUI
import CellarCore
import CellarHost

public struct HostShellRootView: View {
    @StateObject private var model: HostShellViewModel

    public init(model: HostShellViewModel = HostShellViewModel()) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        NavigationSplitView {
            List {
                capabilitySection
                containersSection
            }
            .navigationTitle("CellarKit")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    actionSection
                    planningSection
                    sessionsSection
                    logSection
                }
                .padding()
            }
            .navigationTitle("Host Shell")
        }
        .task {
            await model.refresh()
        }
    }

    private var capabilitySection: some View {
        Section("Capabilities") {
            LabeledContent("Lane", value: label(for: model.capabilitySnapshot.productLane))
            LabeledContent("Distribution", value: label(for: model.capabilitySnapshot.capabilities.distributionChannel))
            LabeledContent("JIT", value: label(for: model.capabilitySnapshot.capabilities.jitMode))
            LabeledContent(
                "Dynarec",
                value: model.capabilitySnapshot.capabilities.canRunDynarec ? "Available" : "Unavailable"
            )
            if !model.capabilitySnapshot.notes.isEmpty {
                ForEach(Array(model.capabilitySnapshot.notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var containersSection: some View {
        Section("Containers") {
            if model.containers.isEmpty {
                Text("No containers saved yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.containers) { container in
                    Button {
                        Task {
                            await model.selectContainer(id: container.id)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(container.title)
                                    .font(.headline)
                                Text("\(label(for: container.guestArchitecture)) • \(label(for: container.acquisitionMode))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.selectedContainerID == container.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
            Text(model.statusMessage)
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh") {
                    Task {
                        await model.refresh()
                    }
                }
                .disabled(model.isBusy)

                Button("Create Sample") {
                    Task {
                        await model.createSampleContainer()
                    }
                }
                .disabled(model.isBusy)

                Button("Launch Selected") {
                    Task {
                        await model.launchSelectedContainer()
                    }
                }
                .disabled(model.isBusy || model.selectedContainerID == nil)
            }
        }
    }

    private var planningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planning")
                .font(.headline)

            if let planningDecision = model.planningDecision {
                LabeledContent("Backend", value: label(for: planningDecision.backend))
                LabeledContent("Policy risk", value: label(for: planningDecision.policyRisk))

                if !planningDecision.blockers.isEmpty {
                    Text("Blockers")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(planningDecision.blockers.enumerated()), id: \.offset) { _, blocker in
                        Text("• \(blocker)")
                    }
                }

                if !planningDecision.warnings.isEmpty {
                    Text("Warnings")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(planningDecision.warnings.enumerated()), id: \.offset) { _, warning in
                        Text("• \(warning)")
                    }
                }
            } else {
                Text("Select a container to inspect the current planning decision.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Launch Sessions")
                .font(.headline)

            if model.sessions.isEmpty {
                Text("No launches recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.sessions.prefix(5)) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(label(for: session.state)) • \(label(for: session.backend))")
                            .font(.subheadline.weight(.semibold))
                        Text(session.startedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Log")
                .font(.headline)
            Group {
                if model.latestLog.isEmpty {
                    Text("No log output yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.latestLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func label<T>(for value: T) -> String {
        String(describing: value)
            .replacingOccurrences(of: "_", with: " ")
    }
}
