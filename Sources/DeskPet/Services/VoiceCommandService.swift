import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoiceCommandService: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case stopped
        case error(String)

        var isListening: Bool {
            if case .listening = self { return true }
            return false
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var statusMessage = "按下麥克風後開始說話。"
    @Published private(set) var isOnDeviceRecognition = false

    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
    private let contextualStrings: [String]
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledTap = false

    init(contextualStrings: [String] = []) {
        self.contextualStrings = Array(contextualStrings.filter { !$0.isEmpty }.prefix(80))
    }

    func startListening() async {
        guard !state.isListening else { return }

        stopAudioPipeline(cancelRecognition: true)
        transcript = ""
        state = .requestingPermission
        statusMessage = "正在確認麥克風與語音辨識權限…"

        let speechAllowed = await requestSpeechPermission()
        guard speechAllowed else {
            state = .error("尚未允許語音辨識")
            statusMessage = "請到「系統設定 → 隱私權與安全性 → 語音辨識」允許 DeskPet。"
            return
        }

        let microphoneAllowed = await requestMicrophonePermission()
        guard microphoneAllowed else {
            state = .error("尚未允許麥克風")
            statusMessage = "請到「系統設定 → 隱私權與安全性 → 麥克風」允許 DeskPet。"
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            state = .error("語音辨識服務目前不可用")
            statusMessage = "macOS 語音辨識目前不可用，稍後再試，或先使用文字輸入。"
            return
        }

        do {
            try beginRecognition(using: recognizer)
        } catch {
            state = .error(error.localizedDescription)
            statusMessage = "無法開始錄音：\(error.localizedDescription)"
            stopAudioPipeline(cancelRecognition: true)
        }
    }

    func stopListening() {
        guard state.isListening else { return }
        audioEngine.stop()
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        state = .stopped
        statusMessage = transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "沒有辨識到文字，可以再錄一次。"
            : "已停止收音。確認文字後交給 DeskPet 理解。"
    }

    func reset() {
        stopAudioPipeline(cancelRecognition: true)
        transcript = ""
        state = .idle
        statusMessage = "按下麥克風後開始說話。"
    }

    func stopAndReturnTranscript() -> String {
        if state.isListening {
            stopListening()
        }
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginRecognition(using recognizer: SFSpeechRecognizer) throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualStrings
        request.taskHint = .dictation

        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            isOnDeviceRecognition = true
        } else {
            request.requiresOnDeviceRecognition = false
            isOnDeviceRecognition = false
        }

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        if hasInstalledTap {
            inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        hasInstalledTap = true

        audioEngine.prepare()
        try audioEngine.start()

        state = .listening
        statusMessage = isOnDeviceRecognition
            ? "正在聽…（使用 Mac 本機語音辨識）"
            : "正在聽…（使用 macOS 語音辨識服務）"

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finishRecognitionNaturally()
                    }
                }

                if let error, self.state.isListening {
                    self.state = .error(error.localizedDescription)
                    self.statusMessage = "語音辨識中斷：\(error.localizedDescription)"
                    self.stopAudioPipeline(cancelRecognition: false)
                }
            }
        }
    }

    private func finishRecognitionNaturally() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        state = .stopped
        statusMessage = transcript.isEmpty ? "沒有辨識到文字。" : "語音已轉成文字，可以交給 DeskPet 理解。"
    }

    private func stopAudioPipeline(cancelRecognition: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if cancelRecognition {
            recognitionTask?.cancel()
        }
        recognitionTask = nil
    }

    private func requestSpeechPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

}
