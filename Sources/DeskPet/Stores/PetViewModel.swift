import AppKit
import Foundation

@MainActor
final class PetViewModel: ObservableObject {
    @Published var state: PetState = .idle
    @Published var captureText = ""
    @Published var lastCapturedText = ""

    let store: CaptureStore

    var requestInputFocus: (() -> Void)?
    var requestFocusRestore: (() -> Void)?

    private var successWorkItem: DispatchWorkItem?

    init(store: CaptureStore) {
        self.store = store
    }

    func petTapped() {
        successWorkItem?.cancel()

        switch state {
        case .idle, .success:
            beginCapture()
        case .input:
            requestInputFocus?()
        case .sleeping:
            state = .idle
        }
    }

    func beginCapture() {
        successWorkItem?.cancel()
        if state == .sleeping {
            state = .idle
        }
        state = .input
        requestInputFocus?()
    }

    func submitCapture() {
        guard let item = store.add(text: captureText) else { return }

        lastCapturedText = item.text
        captureText = ""
        state = .success
        requestFocusRestore?()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.state == .success {
                self.state = .idle
            }
        }

        successWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: workItem)
    }

    func cancelInput() {
        captureText = ""
        state = .idle
        requestFocusRestore?()
    }

    func sleep() {
        successWorkItem?.cancel()
        captureText = ""
        state = .sleeping
        requestFocusRestore?()
    }

    func wake() {
        state = .idle
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
