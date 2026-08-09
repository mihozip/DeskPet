import Combine
import Foundation

@MainActor
final class DailyUsePreferencesStore: ObservableObject {
    enum PetSizePreset: String, CaseIterable, Identifiable {
        case compact
        case standard
        case large

        var id: String { rawValue }

        var title: String {
            switch self {
            case .compact: return "小"
            case .standard: return "標準"
            case .large: return "大"
            }
        }

        var points: CGFloat {
            switch self {
            case .compact: return 102
            case .standard: return 126
            case .large: return 154
            }
        }
    }

    enum AnimationIntensity: String, CaseIterable, Identifiable {
        case quiet
        case normal
        case lively

        var id: String { rawValue }

        var title: String {
            switch self {
            case .quiet: return "安靜"
            case .normal: return "正常"
            case .lively: return "活潑"
            }
        }

        var factor: Double {
            switch self {
            case .quiet: return 0.42
            case .normal: return 0.72
            case .lively: return 1.0
            }
        }

        var timelineInterval: TimeInterval {
            switch self {
            case .quiet: return 1.0 / 15.0
            case .normal: return 1.0 / 24.0
            case .lively: return 1.0 / 30.0
            }
        }
    }

    private enum Key {
        static let petSize = "dailyUse.petSize"
        static let animationIntensity = "dailyUse.animationIntensity"
    }

    @Published var petSize: PetSizePreset {
        didSet { UserDefaults.standard.set(petSize.rawValue, forKey: Key.petSize) }
    }

    @Published var animationIntensity: AnimationIntensity {
        didSet { UserDefaults.standard.set(animationIntensity.rawValue, forKey: Key.animationIntensity) }
    }

    init() {
        let defaults = UserDefaults.standard
        petSize = PetSizePreset(rawValue: defaults.string(forKey: Key.petSize) ?? "") ?? .standard
        animationIntensity = AnimationIntensity(rawValue: defaults.string(forKey: Key.animationIntensity) ?? "") ?? .normal
    }
}
