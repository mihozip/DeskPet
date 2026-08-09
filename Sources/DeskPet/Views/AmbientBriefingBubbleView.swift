import SwiftUI

struct AmbientBriefingBubbleView: View {
    @ObservedObject var monitor: GASTaskAmbientMonitor
    @ObservedObject var gasConfiguration: GASTaskConfigurationStore

    var body: some View {
        if let announcement = monitor.announcement {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("🐱")
                    Text(gasConfiguration.reminderTitle)
                        .font(.headline)
                    Spacer()
                    Button {
                        monitor.dismissAnnouncement()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Text(announcement)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 304, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 10, y: 4)
        }
    }
}
