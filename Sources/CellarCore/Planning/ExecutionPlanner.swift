import Foundation

public struct ExecutionPlanner: Sendable {
    public init() {}

    public func plan(
        request: GameLaunchRequest,
        capabilities: RuntimeCapabilities
    ) -> PlanningDecision {
        var blockers: [String] = []
        var warnings: [String] = []
        var rationale: [String] = []
        var nextSteps: [String] = []

        let policyRisk = classifyPolicyRisk(request: request, capabilities: capabilities)

        if policyRisk == .blocked {
            blockers.append(
                "Integrated storefront download is not considered safe to assume for App Store or TestFlight distribution."
            )
            rationale.append(
                "Apple App Store Review Guideline 2.5.2 is a direct policy concern for downloading and executing Windows game binaries."
            )
            nextSteps.append("Use local import or a side-load-first distribution lane for the first MVP.")
            return PlanningDecision(
                backend: .unsupported,
                policyRisk: .blocked,
                blockers: blockers,
                warnings: warnings,
                rationale: rationale,
                recommendedNextSteps: nextSteps
            )
        }

        if request.requiresGraphicsTranslation && !capabilities.supportsMoltenVK {
            blockers.append("No Apple-compatible Vulkan-to-Metal bridge is currently available in capabilities.")
        }

        switch request.guestArchitecture {
        case .windowsARM64:
            rationale.append("Windows ARM64 avoids the heaviest x64 CPU translation problem.")
            if capabilities.isPolicyConstrainedChannel {
                warnings.append("Even import-based execution on App Store-constrained channels should be treated as review-sensitive.")
            }
            return finalize(
                backend: blockers.isEmpty ? .wineARM64 : .unsupported,
                policyRisk: policyRisk,
                blockers: blockers,
                warnings: warnings,
                rationale: rationale,
                nextSteps: nextSteps + ["Prioritize a narrow ARM64 title or sample to prove rendering, input, and lifecycle."]
            )

        case .windowsARM64EC:
            rationale.append("ARM64EC is a promising compromise path, but still needs careful runtime validation on iOS.")
            warnings.append("ARM64EC support should be treated as experimental until proven with real binaries.")
            return finalize(
                backend: blockers.isEmpty ? .wineARM64EC : .unsupported,
                policyRisk: policyRisk,
                blockers: blockers,
                warnings: warnings,
                rationale: rationale,
                nextSteps: nextSteps + ["Validate one ARM64EC sample before treating this as a mainstream backend."]
            )

        case .windowsX64, .windowsX86:
            rationale.append("x86/x64 Windows support needs an additional CPU translation layer on iOS-class devices.")

            if capabilities.canRunDynarec {
                rationale.append("Current capabilities allow a dynarec-oriented backend.")
                if !capabilities.hasIncreasedMemoryLimit {
                    warnings.append("x64 translation without increased memory limits may be fragile under iOS memory pressure.")
                }
                if capabilities.isPolicyConstrainedChannel {
                    warnings.append("A dynarec backend is likely unsuitable for a policy-constrained App Store lane.")
                }
                nextSteps.append("Benchmark thermals, startup cost, and frame pacing on a real device early.")
                return finalize(
                    backend: blockers.isEmpty ? .wineX64Translator : .unsupported,
                    policyRisk: policyRisk,
                    blockers: blockers,
                    warnings: warnings,
                    rationale: rationale,
                    nextSteps: nextSteps
                )
            }

            if request.allowsInterpreterFallback {
                warnings.append("Falling back to a threaded interpreter will likely be much slower than a JIT-backed x64 path.")
                rationale.append("Interpreter fallback mirrors the UTM SE / iSH style of surviving when JIT is unavailable.")
                nextSteps.append("Use interpreter mode as a proof-of-life or constrained-distribution path, not the primary gaming target.")
                return finalize(
                    backend: blockers.isEmpty ? .wineThreadedInterpreter : .unsupported,
                    policyRisk: policyRisk,
                    blockers: blockers,
                    warnings: warnings,
                    rationale: rationale,
                    nextSteps: nextSteps
                )
            }

            if request.allowsDiagnosticVMFallback {
                warnings.append("VM fallback is useful for diagnostics, but does not satisfy the intended end-user UX.")
                rationale.append("A diagnostic VM path can preserve research momentum when usermode translation is not ready.")
                nextSteps.append("Keep VM fallback clearly separated from the primary containerized game-launch UX.")
                return finalize(
                    backend: .diagnosticVM,
                    policyRisk: policyRisk,
                    blockers: blockers,
                    warnings: warnings,
                    rationale: rationale,
                    nextSteps: nextSteps
                )
            }

            blockers.append("x86/x64 execution needs either dynarec capabilities or an allowed interpreter/VM fallback.")
            nextSteps.append("Either enable a side-load + JIT lane or narrow the first MVP to ARM64 content.")
            return finalize(
                backend: .unsupported,
                policyRisk: policyRisk,
                blockers: blockers,
                warnings: warnings,
                rationale: rationale,
                nextSteps: nextSteps
            )
        }
    }

    private func classifyPolicyRisk(
        request: GameLaunchRequest,
        capabilities: RuntimeCapabilities
    ) -> PolicyRisk {
        if capabilities.isPolicyConstrainedChannel && request.acquisitionMode == .storefrontDownload {
            return .blocked
        }

        if request.acquisitionMode == .storefrontDownload {
            return .high
        }

        if capabilities.isPolicyConstrainedChannel {
            return .medium
        }

        return .low
    }

    private func finalize(
        backend: ExecutionBackend,
        policyRisk: PolicyRisk,
        blockers: [String],
        warnings: [String],
        rationale: [String],
        nextSteps: [String]
    ) -> PlanningDecision {
        PlanningDecision(
            backend: blockers.isEmpty ? backend : .unsupported,
            policyRisk: policyRisk,
            blockers: blockers,
            warnings: warnings,
            rationale: rationale,
            recommendedNextSteps: nextSteps
        )
    }
}
