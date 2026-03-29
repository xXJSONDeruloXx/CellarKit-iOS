import SwiftUI
import UniformTypeIdentifiers
import CellarCore
import CellarHost

public struct HostShellRootView: View {
    @StateObject private var model: HostShellViewModel
    @State private var isImportingPayload = false
    @State private var selectedImportMode: ImportedContentMode = .managedCopy

    public init(model: HostShellViewModel = HostShellViewModel()) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        NavigationSplitView {
            List {
                capabilitySection
                actionSection
                containersSection
            }
            .navigationTitle("CellarKit")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    planningSection
                    sessionsSection
                    benchmarkSection
                    logSection
                }
                .padding()
            }
            .navigationTitle("Host Shell")
        }
        .task {
            await model.refresh()
        }
        .fileImporter(
            isPresented: $isImportingPayload,
            allowedContentTypes: [.item, .data, .folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }
                let accessed = url.startAccessingSecurityScopedResource()
                Task {
                    defer {
                        if accessed {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    await model.importPayload(from: url, mode: selectedImportMode)
                }
            case .failure:
                break
            }
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
                                if let contentMode = container.contentReference?.mode {
                                    Text(label(for: contentMode))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
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
        Section("Actions") {
            Text(model.statusMessage)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("statusMessage")

            Button("Refresh") {
                Task {
                    await model.refresh()
                }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("refreshButton")
            .disabled(model.isBusy)

            Button("Create Sample") {
                Task {
                    await model.createSampleContainer()
                }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("createSampleButton")
            .disabled(model.isBusy)

            Button("Import Copy…") {
                selectedImportMode = .managedCopy
                isImportingPayload = true
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("importPayloadButton")
            .disabled(model.isBusy)

            Button("Link External…") {
                selectedImportMode = .externalSecurityScopedReference
                isImportingPayload = true
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("linkExternalButton")
            .disabled(model.isBusy)

            Button("Launch Selected") {
                Task {
                    await model.launchSelectedContainer()
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("launchSelectedButton")
            .disabled(model.isBusy || model.selectedContainerID == nil)
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

    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Benchmarks")
                .font(.headline)

            if model.benchmarkResults.isEmpty {
                Text("No benchmark captures yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.benchmarkResults.prefix(3)) { benchmark in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(label(for: benchmark.backend)) • \(label(for: benchmark.jitMode))")
                            .font(.subheadline.weight(.semibold))
                        Text("Recorded \(benchmark.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(metricsSummary(for: benchmark.metrics))
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
                        .accessibilityIdentifier("latestLogText")
                }
            }
        }
    }

    private func metricsSummary(for metrics: LaunchSessionMetrics) -> String {
        var parts: [String] = []
        if let startup = metrics.startupDurationSeconds {
            parts.append("startup \(startup.formatted(.number.precision(.fractionLength(2))))s")
        }
        if let interactive = metrics.timeToInteractiveSeconds {
            parts.append("interactive \(interactive.formatted(.number.precision(.fractionLength(2))))s")
        }
        if let total = metrics.totalDurationSeconds {
            parts.append("total \(total.formatted(.number.precision(.fractionLength(2))))s")
        }
        parts.append("logs \(metrics.logLineCount)")
        return parts.joined(separator: " • ")
    }

    private func label<T>(for value: T) -> String {
        String(describing: value)
            .replacingOccurrences(of: "_", with: " ")
    }
}
