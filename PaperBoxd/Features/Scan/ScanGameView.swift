import SwiftUI
import SpriteKit

/// SwiftUI host for the Scan & Know loading game (Phase 5).
///
/// Minimal on purpose — Phase 6/7 will restructure how the scene is instantiated
/// and presented (from the `.scan` tab in `MainTabView`). This gives a testable
/// entry point now: preview it in the Xcode canvas or drop it behind a debug button.
struct ScanGameView: View {
    var scene: SKScene {
        let scene = ScanGameScene()
        scene.size = UIScreen.main.bounds.size
        scene.scaleMode = .aspectFill
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

#Preview {
    ScanGameView()
}
