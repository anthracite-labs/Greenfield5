import Testing

@testable import Greenfield5

/// Tests for the shell's only navigation rule (PRODUCT.md §2 primary
/// actions). Mirrors the Android `AppNavigationTest` — both shells must
/// keep the same home-action mapping until the core seam replaces it.
@Suite("App navigation")
struct AppNavigationTests {
    @Test("Share My Screen routes to the sender entry point")
    func shareMyScreenRoutesToSender() {
        #expect(destination(for: .shareMyScreen) == .sender)
    }

    @Test("View a Screen routes to the viewer entry point")
    func viewAScreenRoutesToViewer() {
        #expect(destination(for: .viewAScreen) == .viewer)
    }

    @Test("Every home action leaves the home screen")
    func everyActionLeavesHome() {
        for action in HomeAction.allCases {
            #expect(destination(for: action) != .home)
        }
    }

    @Test("Screen model covers home and both role entry points")
    func screenModelCoversAllEntryPoints() {
        #expect(Set(AppScreen.allCases) == [.home, .sender, .viewer])
    }
}
