import SwiftUI

struct CalendarQueryView: View {
    @ObservedObject var model: CalendarQueryViewModel

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = .current
        formatter.dateFormat = "M/d（E）"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar Intelligence")
                    .font(.title2.bold())
                Text("用自然語句查詢 macOS 行事曆中的工作行程")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField("例如：九月在台中的研習講師行程", text: $model.queryText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.search() } }
                Button(model.isLoading ? "查詢中…" : "查詢") {
                    Task { await model.search() }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(model.isLoading)
            }

            Text(model.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            if model.events.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("尚無行程結果")
                        .font(.headline)
                    Text("可試試「今年所有研習講師的行程」、「下個月有哪些研習」或「九月在台中的行程」。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(model.events) { event in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateFormatter.string(from: event.startDate))
                                .font(.headline)
                            Text(event.isAllDay ? "全天" : "\(timeFormatter.string(from: event.startDate))–\(timeFormatter.string(from: event.endDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 105, alignment: .leading)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.title)
                                .font(.headline)
                            if let location = event.location, !location.isEmpty {
                                Label(location, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(event.calendarName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 560)
    }
}
