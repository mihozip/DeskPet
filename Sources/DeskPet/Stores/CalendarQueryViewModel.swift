import Foundation

@MainActor
final class CalendarQueryViewModel: ObservableObject {
    @Published var queryText = "告訴我今年所有研習講師的行程"
    @Published private(set) var events: [CalendarEventSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var statusText = "輸入想找的行程，例如：今年所有研習講師的行程"
    @Published private(set) var lastQuery: CalendarQuery?

    private let service: CalendarQueryService

    init(service: CalendarQueryService) {
        self.service = service
    }

    func search() async {
        let text = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusText = "請先輸入想查詢的行程"
            events = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.query(text)
            lastQuery = result.query
            events = result.events
            statusText = result.events.isEmpty
                ? "找不到符合條件的行程"
                : "找到 \(result.events.count) 筆符合條件的行程"
        } catch {
            events = []
            statusText = error.localizedDescription
        }
    }
}
