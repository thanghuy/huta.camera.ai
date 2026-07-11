import SwiftUI

/// "Thư viện dáng" bottom sheet: category chips + 2-column pose card grid.
struct PoseLibrarySheet: View {
    @Environment(CameraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Tokens.hairline)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            HStack {
                Text("Thư viện dáng")
                    .font(AppFont.medium(18))
                    .foregroundStyle(Tokens.ink)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Tokens.ink)
                        .frame(width: 30, height: 30)
                        .background(Tokens.chipIdle, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 4)

            CategoryChips(selected: $store.libraryCategory)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(store.filteredPoses) { pose in
                        PoseCard(pose: pose, isSelected: store.selectedPoseID == pose.id) {
                            store.selectPose(pose)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, 22)
        .background(Color.white)
        .presentationDetents([.fraction(0.78)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }
}

/// Horizontal category filter chips (Tất cả + the 4 categories).
struct CategoryChips: View {
    @Binding var selected: PoseCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "Tất cả", isSelected: selected == nil) { selected = nil }
                ForEach(PoseCategory.allCases) { category in
                    chip(label: category.rawValue, isSelected: selected == category) {
                        selected = category
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.medium(13))
                .foregroundStyle(isSelected ? Tokens.yellow : Tokens.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 16)
                .background(
                    isSelected ? Tokens.ink : Tokens.chipIdle,
                    in: RoundedRectangle(cornerRadius: 18)
                )
        }
        .buttonStyle(.plain)
    }
}
