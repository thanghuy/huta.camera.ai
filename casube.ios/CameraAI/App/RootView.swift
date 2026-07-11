import SwiftUI

struct RootView: View {
    @State private var store = CameraStore()
    @State private var path: [Route] = []

    enum Route: Hashable {
        case camera
    }

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingScreen(onStart: { path.append(.camera) })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .camera:
                        CameraScreen()
                            .toolbarVisibility(.hidden, for: .navigationBar)
                    }
                }
                .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .environment(store)
        #if DEBUG
        .onAppear {
            // Dev shortcut: `--camera` launch argument jumps straight to the camera.
            if CommandLine.arguments.contains("--camera") {
                path = [.camera]
            }
        }
        #endif
    }
}

#Preview {
    RootView()
}
