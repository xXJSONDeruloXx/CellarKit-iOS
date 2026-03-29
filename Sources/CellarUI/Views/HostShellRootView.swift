import SwiftUI
import UniformTypeIdentifiers
import CellarCore
import CellarHost

public struct HostShellRootView: View {
    @StateObject private var model: HostShellViewModel
    @State private var isImportingPayload = false
    @State private var selectedImportMode: ImportedContentMode = .managedCopy
    @State private var titleDraft = ""
    @State private var backendDraft: ExecutionBackend = .wineARM64
    @State private var graphicsBackendDraft: GraphicsBackend = .dxvkMoltenVK
    @State private var memoryBudgetDraft = 1536
    @State private var shaderCacheBudgetDraft = 256
    @State private var touchOverlayDraft = true
    @State private var prefersControllerDraft = true

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
                    selectedContainerSection
                    planningSection
                    sessionsSection
                    sessionDetailSection
                    benchmarkSection
                    benchmarkDetailSection
                    logSection
                }
                .padding()
            }
            .navigationTitle("Host Shell")
        }
        .task {
            await model.refresh()
        }
        .task(id: model.selectedContainer?.id) {
            syncDrafts()
        }
        .sheet(
            isPresented: Binding(
                get: { model.isPresentingLaunchSurface },
                set: { isPresented in
                    if !isPresented {
                        model.dismissLaunchSurface()
                    }
                }
            )
        ) {
            LaunchSurfaceView(model: model)
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

    private var selectedContainerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Container")
                .font(.headline)

            if let container = model.selectedContainer {
                TextField("Container title", text: $titleDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("containerTitleField")

                LabeledContent("Storefront", value: label(for: container.storefront))
                LabeledContent("Architecture", value: label(for: container.guestArchitecture))
                LabeledContent("Acquisition", value: label(for: container.acquisitionMode))
                if let contentMode = container.contentReference?.mode {
                    LabeledContent("Content mode", value: label(for: contentMode))
                }
                if let entryExecutableRelativePath = container.entryExecutableRelativePath {
                    LabeledContent("Entry executable", value: entryExecutableRelativePath)
                }
                if let resolvedContentPath = model.resolvedContentPath {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resolved content")
                            .font(.subheadline.weight(.semibold))
                        Text(resolvedContentPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                if let lastLaunchedAt = container.lastLaunchedAt {
                    LabeledContent(
                        "Last launched",
                        value: lastLaunchedAt.formatted(date: .abbreviated, time: .standard)
                    )
                }

                Divider()

                Text("Runtime Settings")
                    .font(.subheadline.weight(.semibold))

                Picker("Backend preference", selection: $backendDraft) {
                    ForEach(ExecutionBackend.allCases.filter { $0 != .unsupported }, id: \.self) { backend in
                        Text(label(for: backend)).tag(backend)
                    }
                }
                .pickerStyle(.menu)

                Picker("Graphics backend", selection: $graphicsBackendDraft) {
                    ForEach(GraphicsBackend.allCases, id: \.self) { backend in
                        Text(label(for: backend)).tag(backend)
                    }
                }
                .pickerStyle(.menu)

                Stepper("Memory budget: \(memoryBudgetDraft) MB", value: $memoryBudgetDraft, in: 256...4096, step: 128)
                Stepper(
                    "Shader cache budget: \(shaderCacheBudgetDraft) MB",
                    value: $shaderCacheBudgetDraft,
                    in: 32...1024,
                    step: 32
                )
                Toggle("Touch overlay enabled", isOn: $touchOverlayDraft)
                Toggle("Prefer physical controller", isOn: $prefersControllerDraft)

                HStack {
                    Button("Save Title") {
                        Task {
                            await model.renameSelectedContainer(to: titleDraft)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy || titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Save Runtime Settings") {
                        Task {
                            await model.saveRuntimeProfile(
                                backendPreference: backendDraft,
                                graphicsBackend: graphicsBackendDraft,
                                touchOverlayEnabled: touchOverlayDraft,
                                prefersPhysicalController: prefersControllerDraft,
                                memoryBudgetMB: memoryBudgetDraft,
                                shaderCacheBudgetMB: shaderCacheBudgetDraft
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("saveRuntimeSettingsButton")
                    .disabled(model.isBusy)

                    Button("Delete Container", role: .destructive) {
                        Task {
                            await model.deleteSelectedContainer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)
                }
            } else {
                Text("Select a container to inspect or edit its metadata.")
                    .foregroundStyle(.secondary)
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
                    Button {
                        model.selectSession(id: session.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(label(for: session.state)) • \(label(for: session.backend))")
                                .font(.subheadline.weight(.semibold))
                            Text(session.startedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            (model.selectedSession?.id == session.id ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sessionDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Detail")
                .font(.headline)

            if let session = model.selectedSession {
                LabeledContent("State", value: label(for: session.state))
                LabeledContent("Backend", value: label(for: session.backend))
                if let exitCode = session.lastExitCode {
                    LabeledContent("Exit code", value: String(exitCode))
                }
                if let endedAt = session.endedAt {
                    LabeledContent("Ended", value: endedAt.formatted(date: .abbreviated, time: .standard))
                }

                if !session.events.isEmpty {
                    Text("Event Timeline")
                        .font(.subheadline.weight(.semibold))
                    ForEach(session.events.prefix(8)) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label(for: event.kind))
                                .font(.caption.weight(.semibold))
                            if let message = event.message, !message.isEmpty {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                Text("No session selected.")
                    .foregroundStyle(.secondary)
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
                    Button {
                        model.selectBenchmark(id: benchmark.id)
                    } label: {
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
                        .background(
                            (model.selectedBenchmark?.id == benchmark.id ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var benchmarkDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Benchmark Detail")
                .font(.headline)

            if let benchmark = model.selectedBenchmark {
                LabeledContent("Backend", value: label(for: benchmark.backend))
                LabeledContent("JIT", value: label(for: benchmark.jitMode))
                LabeledContent("Lane", value: label(for: benchmark.productLane))
                LabeledContent("Content mode", value: benchmark.contentMode.map { label(for: $0) } ?? "Unknown")
                LabeledContent("Recorded", value: benchmark.recordedAt.formatted(date: .abbreviated, time: .standard))
                Text(metricsSummary(for: benchmark.metrics))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !benchmark.plannerWarnings.isEmpty {
                    Text("Planner warnings")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(benchmark.plannerWarnings.enumerated()), id: \.offset) { _, warning in
                        Text("• \(warning)")
                            .font(.caption)
                    }
                }
            } else {
                Text("No benchmark selected.")
                    .foregroundStyle(.secondary)
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

    private func syncDrafts() {
        guard let container = model.selectedContainer else {
            titleDraft = ""
            backendDraft = .wineARM64
            graphicsBackendDraft = .dxvkMoltenVK
            memoryBudgetDraft = 1536
            shaderCacheBudgetDraft = 256
            touchOverlayDraft = true
            prefersControllerDraft = true
            return
        }

        titleDraft = container.title
        backendDraft = container.runtimeProfile.backendPreference == .unsupported
            ? .wineARM64
            : container.runtimeProfile.backendPreference
        graphicsBackendDraft = container.runtimeProfile.graphicsBackend
        memoryBudgetDraft = container.runtimeProfile.memoryBudgetMB
        shaderCacheBudgetDraft = container.runtimeProfile.shaderCacheBudgetMB
        touchOverlayDraft = container.runtimeProfile.touchOverlayEnabled
        prefersControllerDraft = container.runtimeProfile.prefersPhysicalController
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
