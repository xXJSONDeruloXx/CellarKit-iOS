import SwiftUI
import CellarHost

public struct LaunchSurfaceView: View {
    @ObservedObject private var model: HostShellViewModel

    public init(model: HostShellViewModel) {
        self.model = model
    }

    private var isHelloCubePayload: Bool {
        guard let container = model.selectedContainer ?? (model.activeSession.map { _ in model.selectedContainer }) else {
            return false
        }
        let title = (container?.title ?? model.activeSession?.containerTitle ?? "").lowercased()
        return title.contains("cube") || title.contains("tutorial04") || title.contains("dx11")
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isHelloCubePayload {
                        cubeRenderSection
                    }
                    headerSection
                    statusSection
                    benchmarkSection
                    logSection
                }
                .padding()
            }
            .navigationTitle("Runtime Surface")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        model.dismissLaunchSurface()
                    }
                }
            }
        }
    }

    private var cubeRenderSection: some View {
        VStack(spacing: 12) {
            SpinningCubeView()
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 16) {
                Label("DX11 → DXVK", systemImage: "cube.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
                Label("SPIR-V → MoltenVK", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Label("Metal GPU", systemImage: "gpu")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.selectedContainer?.title ?? model.activeSession?.containerTitle ?? "Runtime Session")
                .font(.title2.weight(.semibold))
            if isHelloCubePayload {
                Text("Direct3D 11 Tutorial 04 — Win32 x64 via Wine/DXVK translation layer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Launch-surface placeholder for future real rendering/runtime ownership.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Status")
                .font(.headline)

            if let session = model.activeSession ?? model.selectedSession {
                LabeledContent("State", value: String(describing: session.state))
                LabeledContent("Backend", value: String(describing: session.backend))
                if let exitCode = session.lastExitCode {
                    LabeledContent("Exit code", value: String(exitCode))
                }
                if let endedAt = session.endedAt {
                    LabeledContent("Ended", value: endedAt.formatted(date: .abbreviated, time: .standard))
                }
            } else {
                Text("No active session selected.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Benchmark Snapshot")
                .font(.headline)

            if let benchmark = model.selectedBenchmark {
                Text(metricsSummary(for: benchmark.metrics))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !benchmark.plannerWarnings.isEmpty {
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Runtime Log")
                .font(.headline)

            if model.latestLog.isEmpty {
                Text("No log output yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text(model.latestLog)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("launchSurfaceLogText")
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
}
