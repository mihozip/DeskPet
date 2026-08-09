import Foundation

final class InboxViewState: ObservableObject {
    @Published var searchText = ""
    @Published var filter: InboxFilter = .inbox
}
