import SwiftUI

/// The 4-value match state — the single source that drives EVERY match-colored
/// visual (viewfinder border, corner brackets, badge, arrows, hint, shutter ring).
/// Config values are ported verbatim from the mockup's MATCH_CONFIG.
enum MatchState: String, CaseIterable, Identifiable {
    case none, far, close, perfect

    var id: String { rawValue }

    enum Arrows {
        case edges, side, none
    }

    struct Config {
        let color: Color
        let light: Color
        let percent: Int
        let label: String
        let hint: String
        let arrows: Arrows
        let dashedBorder: Bool
    }

    var config: Config {
        switch self {
        case .none:
            Config(color: Tokens.matchNone, light: Tokens.matchNoneLight, percent: 0,
                   label: "Không nhận diện", hint: "Di chuyển vào khung hình",
                   arrows: .edges, dashedBorder: true)
        case .far:
            Config(color: Tokens.matchFar, light: Tokens.matchFarLight, percent: 35,
                   label: "35% khớp", hint: "Tiến gần hơn để lấp đầy khung",
                   arrows: .edges, dashedBorder: false)
        case .close:
            Config(color: Tokens.matchClose, light: Tokens.matchCloseLight, percent: 78,
                   label: "78% khớp", hint: "Dịch chuyển sang phải một chút",
                   arrows: .side, dashedBorder: false)
        case .perfect:
            Config(color: Tokens.matchPerfect, light: Tokens.matchPerfectLight, percent: 97,
                   label: "97% khớp", hint: "Đã khớp! Sắp chụp...",
                   arrows: .none, dashedBorder: false)
        }
    }

    /// Vietnamese label for the DEBUG dev switch.
    var devLabel: String {
        switch self {
        case .none: "Không nhận diện"
        case .far: "Lệch xa"
        case .close: "Gần khớp"
        case .perfect: "Khớp hoàn hảo"
        }
    }
}
