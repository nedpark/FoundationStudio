import SwiftUI
import FoundationModels

/// Toolbar badge showing the current Apple Intelligence model availability.
struct ModelStatusBadge: View {
    @Environment(FoundationModelService.self) private var modelService

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text("Apple Intelligence")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .help(statusHelp)
    }

    private var statusColor: Color {
        switch modelService.modelAvailability {
        case .available:
            .green
        case .unavailable:
            .red
        }
    }

    private var statusHelp: String {
        switch modelService.modelAvailability {
        case .available:
            "On-device model is ready"
        case .unavailable(.deviceNotEligible):
            "This device does not support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            "Please enable Apple Intelligence in System Settings"
        case .unavailable(.modelNotReady):
            "Model is downloading or not yet ready"
        case .unavailable:
            "Model is unavailable"
        }
    }
}
