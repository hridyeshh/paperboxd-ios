import SwiftUI
import UIKit

/// Shopify Editions–style page change (shader in `PageDissolve.metal`).
/// Call `PageDissolve.cover()` right before the state change that swaps the
/// page: it freezes the screen and burns that copy away while the new page
/// renders underneath. `reverse` (back navigation) plays it backwards: the
/// page you return to un-burns over the one you leave. Snapshots rather than
/// a live `layerEffect` because Metal effects can't draw UIKit-backed views
/// like `TextField`.
@MainActor
enum PageDissolve {
    static let duration = 0.8 // the shader's flicker assumes this
    private static var host: UIViewController?
    private static var still: UIView?

    static func cover(reverse: Bool = false) {
        guard host == nil, still == nil, !UIAccessibility.isReduceMotionEnabled,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
              let root = window.rootViewController?.view
        else { return }

        let leaving = snapshot(window)
        guard reverse else {
            play(leaving, reverse: false, in: window)
            return
        }
        // The page we return to has to render before it can be captured, so
        // hold a still of this one over it for a beat.
        let frozen = UIImageView(image: leaving)
        frozen.frame = window.bounds
        window.addSubview(frozen)
        still = frozen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            play(snapshot(root), reverse: true, in: window) // root view: leaves out the still
        }
    }

    private static func snapshot(_ view: UIView) -> UIImage {
        UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
    }

    private static func play(_ image: UIImage, reverse: Bool, in window: UIWindow) {
        let controller = UIHostingController(rootView: DissolveOverlay(image: image, reverse: reverse) {
            host?.view.removeFromSuperview()
            still?.removeFromSuperview()
            host = nil
            still = nil
        })
        controller.view.backgroundColor = .clear
        controller.view.frame = window.bounds
        window.addSubview(controller.view)
        host = controller
    }
}

private struct DissolveOverlay: View {
    let image: UIImage
    let reverse: Bool
    let onDone: () -> Void
    @State private var progress: Double

    init(image: UIImage, reverse: Bool, onDone: @escaping () -> Void) {
        self.image = image
        self.reverse = reverse
        self.onDone = onDone
        _progress = State(initialValue: reverse ? 1 : 0)
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .modifier(DissolveEffect(progress: progress))
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: PageDissolve.duration)) {
                    progress = reverse ? 0 : 1
                } completion: {
                    onDone()
                }
            }
    }
}

private struct DissolveEffect: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { [progress] effect, proxy in
            effect.layerEffect(
                ShaderLibrary.pageDissolve(.float2(proxy.size), .float(progress)),
                maxSampleOffset: CGSize(width: 2, height: 2)
            )
        }
    }
}
