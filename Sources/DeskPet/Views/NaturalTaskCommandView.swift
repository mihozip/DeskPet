import SwiftUI

struct NaturalTaskCommandView: View {
    @ObservedObject var model: NaturalTaskCommandViewModel
    @ObservedObject var voiceService: VoiceCommandService

    private let examples = [
        "那個冷氣的延到星期五下午三點",
        "廠商那件回覆了",
        "監視器採購規格複核完成了"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            commandEditor
            exampleRow
            Divider()
            resultArea
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 560)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("DeskPet 自然語句操作")
                    .font(.title2.bold())
                Text("Gemini 會從目前總務任務中找出你指的那一件，再提出變更草案。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.analysisModeLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.08), in: Capsule())
        }
    }

    private var commandEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("直接跟 DeskPet 說")
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                TextField("例如：那個冷氣的延到星期五下午三點", text: $model.commandText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .onSubmit {
                        Task { await model.analyze() }
                    }

                Button {
                    Task {
                        if voiceService.state.isListening {
                            voiceService.stopListening()
                        } else {
                            await voiceService.startListening()
                        }
                    }
                } label: {
                    Image(systemName: voiceService.state.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(voiceService.state.isListening ? Color.red : Color.purple)
                }
                .buttonStyle(.plain)
                .help(voiceService.state.isListening ? "停止錄音" : "開始語音輸入")
            }

            if voiceService.state.isListening || !voiceService.transcript.isEmpty || voiceService.hasError {
                voicePanel
            }

            HStack(alignment: .center) {
                Image(systemName: model.isAnalyzing ? "sparkles" : "bubble.left")
                    .foregroundStyle(model.isAnalyzing ? Color.purple : Color.secondary)
                Text(model.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(model.isAnalyzing ? "理解中…" : "讓 DeskPet 理解") {
                    Task { await model.analyze() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isAnalyzing || model.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if model.usedFallback {
                Label("這次 Gemini 呼叫失敗，結果改由本機規則產生。", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: voiceService.transcript) { newValue in
            if !newValue.isEmpty {
                model.commandText = newValue
            }
        }
    }

    private var voicePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    voiceService.state.isListening ? "DeskPet 正在聽" : "語音輸入",
                    systemImage: voiceService.state.isListening ? "waveform" : "text.quote"
                )
                .font(.subheadline.bold())
                .foregroundStyle(voiceService.state.isListening ? Color.red : Color.secondary)

                Spacer()

                if voiceService.state.isListening {
                    Button("停止並理解") {
                        voiceService.stopListening()
                        let spoken = voiceService.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !spoken.isEmpty {
                            model.commandText = spoken
                            Task { await model.analyze() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else if !voiceService.transcript.isEmpty {
                    Button("重新錄音") {
                        voiceService.reset()
                        Task { await voiceService.startListening() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(voiceService.statusMessage)
                .font(.caption)
                .foregroundStyle(voiceService.hasError ? Color.red : Color.secondary)

            if !voiceService.transcript.isEmpty {
                Text(voiceService.transcript)
                    .font(.callout.weight(.medium))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var exampleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("試試更口語的說法")
                .font(.subheadline.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examples, id: \.self) { example in
                        Button(example) { model.useExample(example) }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultArea: some View {
        if let proposal = model.proposal {
            proposalCard(proposal)
        } else if let ambiguity = model.ambiguity {
            ambiguityCard(ambiguity)
        } else {
            emptyState
        }
    }

    private func proposalCard(_ proposal: NaturalTaskActionProposal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DeskPet 的理解")
                    .font(.headline)
                Spacer()
                Label(proposal.source.label, systemImage: proposal.source == .gemini ? "sparkles" : "cpu")
                    .font(.caption)
                    .foregroundStyle(proposal.source == .gemini ? Color.purple : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                row("任務", proposal.task.name)
                row("目前狀態", proposal.task.status ?? "—")
                row("操作", proposal.action.title)
                if let deadline = proposal.dueDate {
                    row("新期限", Self.dateFormatter.string(from: deadline))
                }
                row("進度備註", proposal.note)
                row("信心度", "\(Int(proposal.confidence * 100))%")

                Text(proposal.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Label("這裡還沒有寫入任何資料。", systemImage: "shield.checkered")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("前往變更預覽") { model.proceed() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func ambiguityCard(_ ambiguity: NaturalTaskActionAmbiguity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("DeskPet 不想硬猜", systemImage: "questionmark.bubble")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(ambiguity.message)
                .foregroundStyle(.secondary)

            if ambiguity.candidates.isEmpty {
                Text("Gemini 沒有提供可靠候選。請加入任務名稱、對象或工作內容後再分析。")
                    .font(.callout)
            } else {
                Text("請選你真正指的任務：")
                    .font(.subheadline.bold())

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(ambiguity.candidates) { task in
                            Button {
                                model.chooseCandidate(task)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.name)
                                            .font(.body.weight(.medium))
                                        HStack(spacing: 8) {
                                            if let category = task.category, !category.isEmpty { Text(category) }
                                            if let status = task.status, !status.isEmpty { Text(status) }
                                            if let deadline = task.deadlineText { Text(deadline) }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 210)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🐾")
                .font(.system(size: 36))
            Text("DeskPet 還在等你說一句話")
                .font(.headline)
            Text("0.8 可以直接用麥克風說一句話，再把轉寫文字交給 Gemini 做任務語意比對；有歧義時仍不會自行選擇。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .frame(width: 78, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .fontWeight(.medium)
        }
        .font(.callout)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.timeZone = TimeZone(identifier: "Asia/Taipei")
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()
}
