#if DEBUG
import SwiftUI

/// DEBUG-only strip to force a match state and eyeball all four visual states.
/// "AI" returns control to the real pipeline (M4). Not compiled into Release.
struct MatchStateDevSwitch: View {
    @Binding var manualState: MatchState?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(label: "AI", isSelected: manualState == nil) { manualState = nil }
                ForEach(MatchState.allCases) { state in
                    chip(label: state.devLabel, isSelected: manualState == state) {
                        manualState = state
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.medium(11))
                .foregroundStyle(isSelected ? Tokens.yellow : Tokens.ink)
                .padding(.vertical, 7)
                .padding(.horizontal, 11)
                .background(
                    isSelected ? Tokens.ink : Tokens.chipIdle,
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .buttonStyle(.plain)
    }
}
#endif
