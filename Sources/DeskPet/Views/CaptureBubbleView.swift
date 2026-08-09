import SwiftUI

struct CaptureBubbleView: View {
    @ObservedObject var model: PetViewModel
    let shortcutLabel: () -> String
    @FocusState private var inputFocused: Bool

    var body: some View {
        Group {
            switch model.state {
            case .input:
                inputBubble
            case .success:
                successBubble
            case .idle, .sleeping:
                EmptyView()
            }
        }
        .onChange(of: model.state) { newState in
            if newState == .input {
                DispatchQueue.main.async {
                    inputFocused = true
                }
            } else {
                inputFocused = false
            }
        }
    }

    private var inputBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("想到什麼？")
                    .font(.headline)

                Spacer()

                Text(shortcutLabel())
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            TextField("例如：明天問廠商冷氣保養進度", text: $model.captureText)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit {
                    model.submitCapture()
                }
                .onExitCommand {
                    model.cancelInput()
                }

            Text("Enter 儲存 · Esc 取消")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 304)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10, y: 4)
    }

    private var successBubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("✓ 已收進 Inbox")
                .font(.headline)

            Text(model.lastCapturedText)
                .font(.callout)
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 304, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10, y: 4)
    }
}
