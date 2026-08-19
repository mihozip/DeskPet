import SwiftUI

struct ContextBriefingBubbleView: View {
    @ObservedObject var briefing: WorkContextBriefingService
    let onOpenTodayWork: () -> Void

    var body: some View {
        if let announcement = briefing.announcement {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("🐱")
                    Text("白帥帥建議")
                        .font(.headline)
                    Spacer()
                    Button {
                        briefing.dismissAnnouncement()
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

                Text("點一下查看 Now / Next / Later")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(width: 320, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 10, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                briefing.dismissAnnouncement()
                onOpenTodayWork()
            }
        }
    }
}
