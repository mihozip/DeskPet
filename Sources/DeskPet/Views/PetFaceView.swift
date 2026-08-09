import AppKit
import SwiftUI

struct PetFaceView: View {
    let state: PetState
    @ObservedObject var preferences: DailyUsePreferencesStore

    var body: some View {
        AnimatedPetSpriteView(state: state, intensity: preferences.animationIntensity)
            .frame(width: preferences.petSize.points, height: preferences.petSize.points)
            .contentShape(Rectangle())
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return "白貓桌寵待命"
        case .input:
            return "白貓桌寵正在聆聽"
        case .success:
            return "白貓桌寵完成回應"
        case .sleeping:
            return "白貓桌寵睡著了"
        }
    }
}

private struct AnimatedPetSpriteView: View {
    let state: PetState
    let intensity: DailyUsePreferencesStore.AnimationIntensity

    var body: some View {
        TimelineView(.animation(minimumInterval: intensity.timelineInterval)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let metrics = AnimationMetrics(state: state, time: time, intensityFactor: intensity.factor)

            ZStack {
                petLayer(name: "pet_idle", targetState: .idle, metrics: metrics)
                    .overlay {
                        if state == .idle {
                            blinkOverlay(progress: metrics.blinkProgress)
                        }
                    }

                petLayer(name: "pet_listening", targetState: .input, metrics: metrics)
                    .overlay {
                        if state == .input {
                            listeningEarMarks(progress: metrics.earTwitchProgress, intensity: intensity.factor)
                        }
                    }

                petLayer(name: "pet_success", targetState: .success, metrics: metrics)
                    .overlay {
                        if state == .success {
                            successStars(progress: metrics.successFlashProgress, intensity: intensity.factor)
                        }
                    }

                petLayer(name: "pet_sleep", targetState: .sleeping, metrics: metrics)
                    .overlay(alignment: .topTrailing) {
                        if state == .sleeping {
                            sleepingZzz(progress: metrics.zzzProgress, intensity: intensity.factor)
                        }
                    }
            }
            .animation(.easeInOut(duration: 0.24), value: state)
        }
    }

    @ViewBuilder
    private func petLayer(
        name: String,
        targetState: PetState,
        metrics: AnimationMetrics
    ) -> some View {
        if let image = PetAssetLoader.image(named: name) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .padding(2)
                .scaleEffect(state == targetState ? metrics.scale : 0.975)
                .rotationEffect(.degrees(state == targetState ? metrics.rotation : 0))
                .offset(
                    x: state == targetState ? metrics.xOffset : 0,
                    y: state == targetState ? metrics.yOffset : 0
                )
                .opacity(state == targetState ? metrics.opacity : 0)
                .shadow(
                    color: state == targetState ? metrics.shadowColor : Color.clear,
                    radius: state == targetState ? metrics.shadowRadius : 0,
                    x: 0,
                    y: state == targetState ? metrics.shadowYOffset : 0
                )
                .drawingGroup()
                .allowsHitTesting(false)
        } else if state == targetState {
            MissingPetAssetView(fileName: "\(name).png")
        }
    }

    // MARK: - Idle blink

    private func blinkOverlay(progress: Double) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let eyeCoverHeight = max(1.2, 6.0 * progress)
            let lineOpacity = min(1.0, progress * 1.3)

            ZStack {
                blinkEye(
                    coverHeight: eyeCoverHeight,
                    lineOpacity: lineOpacity
                )
                .position(x: w * 0.225, y: h * 0.397)

                blinkEye(
                    coverHeight: eyeCoverHeight,
                    lineOpacity: lineOpacity
                )
                .position(x: w * 0.410, y: h * 0.397)
            }
            .opacity(progress)
        }
    }

    private func blinkEye(coverHeight: CGFloat, lineOpacity: Double) -> some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.98, green: 0.97, blue: 0.94))
                .frame(width: 10.5, height: coverHeight)

            Capsule()
                .fill(Color(red: 0.28, green: 0.16, blue: 0.15).opacity(lineOpacity))
                .frame(width: 8.5, height: 1.2)
        }
    }

    // MARK: - Listening ear twitch

    private func listeningEarMarks(progress: Double, intensity: Double) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let alpha = sin(progress * .pi)

            ZStack {
                earMarkGroup(mirrored: false)
                    .position(x: w * 0.245, y: h * 0.218)
                    .offset(x: CGFloat(alpha * -2.0), y: CGFloat(alpha * -1.5))

                earMarkGroup(mirrored: true)
                    .position(x: w * 0.485, y: h * 0.205)
                    .offset(x: CGFloat(alpha * 2.0), y: CGFloat(alpha * -1.5))
            }
            .opacity(alpha * intensity)
        }
    }

    private func earMarkGroup(mirrored: Bool) -> some View {
        HStack(spacing: 2.5) {
            Capsule()
                .fill(Color(red: 0.62, green: 0.48, blue: 0.86))
                .frame(width: 2.3, height: 8)
                .rotationEffect(.degrees(mirrored ? 28 : -28))

            Capsule()
                .fill(Color(red: 0.62, green: 0.48, blue: 0.86))
                .frame(width: 2.1, height: 5.5)
                .rotationEffect(.degrees(mirrored ? 8 : -8))
        }
    }

    // MARK: - Success stars

    private func successStars(progress: Double, intensity: Double) -> some View {
        GeometryReader { proxy in
            let pulse = sin(progress * .pi)
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                star(size: 14)
                    .position(x: w * 0.78, y: h * 0.18)
                    .scaleEffect(0.6 + pulse * 0.7)
                    .rotationEffect(.degrees(pulse * 18))

                star(size: 9)
                    .position(x: w * 0.20, y: h * 0.26)
                    .scaleEffect(0.5 + pulse * 0.65)
                    .rotationEffect(.degrees(-pulse * 15))

                star(size: 7)
                    .position(x: w * 0.86, y: h * 0.42)
                    .scaleEffect(0.5 + pulse * 0.55)
            }
            .opacity(pulse * intensity)
        }
    }

    private func star(size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Color(red: 0.98, green: 0.76, blue: 0.25))
            .shadow(color: Color.white.opacity(0.8), radius: 2)
    }

    // MARK: - Sleeping Zzz

    private func sleepingZzz(progress: Double, intensity: Double) -> some View {
        SleepingZzzView(progress: progress, intensity: intensity)
    }
}

private struct SleepingZzzView: View {
    let progress: Double
    let intensity: Double

    var body: some View {
        let phase = progress * 2.0 * Double.pi
        let wave = 0.5 - 0.5 * cos(phase)
        let opacityValue = (0.18 + wave * 0.72) * max(0.55, intensity)
        let scaleValue = CGFloat(0.88 + wave * 0.12)
        let verticalOffset = CGFloat(5.0 - wave * 5.0)
        let zzzColor = Color(red: 0.55, green: 0.48, blue: 0.76)
        let glowColor = Color.white.opacity(0.70)

        return Text("Zzz")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(zzzColor)
            .opacity(opacityValue)
            .scaleEffect(scaleValue)
            .offset(x: -8, y: verticalOffset)
            .shadow(color: glowColor, radius: 1, x: 0, y: 0)
    }
}

private enum PetAssetLoader {
    private static let images: [String: NSImage] = {
        let names = ["pet_idle", "pet_listening", "pet_success", "pet_sleep"]
        guard let resourcesURL = Bundle.main.resourceURL else {
            NSLog("DeskPet: Bundle.main.resourceURL is nil")
            return [:]
        }

        var loaded: [String: NSImage] = [:]
        for name in names {
            let fileURL = resourcesURL.appendingPathComponent("\(name).png")
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                NSLog("DeskPet: pet asset missing at %@", fileURL.path)
                continue
            }
            guard let image = NSImage(contentsOf: fileURL) else {
                NSLog("DeskPet: failed to decode pet asset at %@", fileURL.path)
                continue
            }
            loaded[name] = image
        }
        return loaded
    }()

    static func image(named name: String) -> NSImage? {
        images[name]
    }
}

private struct MissingPetAssetView: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.secondary)
            Text("DeskPet")
                .font(.caption.bold())
            Text("Add licensed pet assets")
                .font(.system(size: 8))
                .foregroundStyle(Color.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        }
        .frame(width: 122, height: 122)
        .help("Missing optional asset: \(fileName). See Sources/DeskPet/Resources/README.md")
    }
}

private struct AnimationMetrics {
    let state: PetState
    let time: Double
    let intensityFactor: Double

    var scale: CGFloat {
        switch state {
        case .idle:
            return CGFloat(1.0 + (breathingWave - 0.5) * 0.026 * intensityFactor)
        case .input:
            return CGFloat(1.0 + (listeningPulse - 0.5) * 0.016 * intensityFactor)
        case .success:
            return CGFloat(1.0 + successBounce * 0.055 * intensityFactor)
        case .sleeping:
            return CGFloat(1.0 + (sleepingWave - 0.5) * 0.022 * intensityFactor)
        }
    }

    var rotation: Double {
        switch state {
        case .input:
            return (listeningSway + earTwitchAngle) * intensityFactor
        default:
            return 0
        }
    }

    var xOffset: CGFloat {
        switch state {
        case .input:
            return CGFloat((sin(time * 4.1) * 1.2 + earTwitchAngle * 0.45) * intensityFactor)
        default:
            return 0
        }
    }

    var yOffset: CGFloat {
        switch state {
        case .idle:
            return CGFloat((1.2 - breathingWave * 2.4) * intensityFactor)
        case .input:
            return CGFloat((0.7 - listeningPulse * 1.4) * intensityFactor)
        case .success:
            return CGFloat(-successBounce * 13.0 * intensityFactor)
        case .sleeping:
            return CGFloat((1.3 - sleepingWave * 4.0) * intensityFactor)
        }
    }

    var opacity: Double {
        switch state {
        case .input:
            return 1.0 - (0.06 - listeningPulse * 0.06) * intensityFactor
        default:
            return 1.0
        }
    }

    var shadowColor: Color {
        switch state {
        case .input:
            return Color.accentColor.opacity((0.08 + listeningPulse * 0.14) * intensityFactor)
        case .success:
            return Color.yellow.opacity((0.10 + successFlashProgress * 0.20) * intensityFactor)
        default:
            return Color.black.opacity(0.14)
        }
    }

    var shadowRadius: CGFloat {
        switch state {
        case .input:
            return CGFloat(6.0 + listeningPulse * 4.0 * intensityFactor)
        case .success:
            return CGFloat(7.0 + successFlashProgress * 5.0 * intensityFactor)
        default:
            return 7
        }
    }

    var shadowYOffset: CGFloat {
        state == .success ? 8 : 6
    }

    var blinkProgress: Double {
        let blockLength = 7.4
        let block = floor(time / blockLength)
        let local = time - block * blockLength
        let random = pseudoRandom(block * 12.73 + 4.91)
        let start = 1.15 + random * 4.45
        let first = triangularPulse(local: local, start: start, duration: 0.19)

        let secondRandom = pseudoRandom(block * 21.17 + 9.31)
        let second: Double
        if secondRandom > 0.76 {
            second = triangularPulse(local: local, start: start + 0.38, duration: 0.16)
        } else {
            second = 0
        }

        return max(first, second)
    }

    var earTwitchProgress: Double {
        let blockLength = 5.2
        let block = floor(time / blockLength)
        let local = time - block * blockLength
        let random = pseudoRandom(block * 18.11 + 2.47)
        let start = 0.75 + random * 3.2
        return normalizedWindow(local: local, start: start, duration: 0.48)
    }

    var successFlashProgress: Double {
        let phase = positiveRemainder(time, divisor: 1.35)
        if phase > 0.78 { return 0 }
        return phase / 0.78
    }

    var zzzProgress: Double {
        positiveRemainder(time, divisor: 3.0) / 3.0
    }

    private var breathingWave: Double {
        0.5 - 0.5 * cos(time * 2 * .pi / 2.8)
    }

    private var listeningPulse: Double {
        0.5 - 0.5 * cos(time * 2 * .pi / 0.82)
    }

    private var listeningSway: Double {
        sin(time * 2 * .pi / 1.05) * 0.65
    }

    private var earTwitchAngle: Double {
        guard earTwitchProgress > 0, earTwitchProgress < 1 else { return 0 }
        return sin(earTwitchProgress * .pi * 4) * 2.2 * sin(earTwitchProgress * .pi)
    }

    private var successBounce: Double {
        let phase = positiveRemainder(time, divisor: 1.10)
        guard phase < 0.72 else { return 0 }
        let normalized = phase / 0.72
        return abs(sin(normalized * .pi)) * exp(-normalized * 0.8)
    }

    private var sleepingWave: Double {
        0.5 - 0.5 * cos(time * 2 * .pi / 3.8)
    }

    private func pseudoRandom(_ seed: Double) -> Double {
        let value = sin(seed) * 43758.5453123
        return value - floor(value)
    }

    private func positiveRemainder(_ value: Double, divisor: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: divisor)
        return result >= 0 ? result : result + divisor
    }

    private func normalizedWindow(local: Double, start: Double, duration: Double) -> Double {
        guard local >= start, local <= start + duration else { return 0 }
        return (local - start) / duration
    }

    private func triangularPulse(local: Double, start: Double, duration: Double) -> Double {
        let progress = normalizedWindow(local: local, start: start, duration: duration)
        guard progress > 0, progress < 1 else { return 0 }
        return 1.0 - abs(progress * 2.0 - 1.0)
    }
}
