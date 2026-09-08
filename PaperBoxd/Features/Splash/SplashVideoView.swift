import AVFoundation
import SwiftUI

/// Playback rate for the splash clip. The 4.87s source runs 3.9s at 1.25x —
/// `AppState.holdSplash` is floored above that plus the outro fade.
private let splashPlaybackRate: Float = 1.25

/// The bundled splash clip on a bare `AVPlayerLayer` — no transport controls,
/// no sound.
///
/// Everything here exists to keep the animation from hitching on a cold start:
/// the asset is a local file, the player is prerolled before it is allowed to
/// start, and stall avoidance is off (it buys nothing for a file URL and only
/// delays the first frame). The clip has no audio track, but `AVPlayer` still
/// activates the audio session, so the category is moved off the default
/// `soloAmbient` first — see `attach`.
struct SplashVideoView: UIViewRepresentable {
    let resource: String
    let ext: String
    /// Fired on the main queue once the first frame is decoded and playing, so
    /// the caller can fade the view in instead of popping a half-drawn frame.
    var onReady: () -> Void = {}
    /// Fired on the main queue when the clip reaches its end, so the caller can
    /// fade it out rather than cutting straight to the next screen.
    var onFinished: () -> Void = {}

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        context.coordinator.attach(to: view, onReady: onReady, onFinished: onFinished)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(resource: resource, ext: ext)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    /// Backing the view with `AVPlayerLayer` directly avoids the extra
    /// sublayer-resize dance you get from adding the layer by hand.
    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        /// Fired when the view gains a window or gets laid out. SwiftUI sizes
        /// this view from an `aspectRatio` modifier, so on a cold start it is
        /// mounted at zero bounds and cannot draw yet; the coordinator uses
        /// this to re-check whether it is safe to start playback.
        var onVisibilityChange: () -> Void = {}

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onVisibilityChange()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            onVisibilityChange()
        }
    }

    final class Coordinator {
        private let resource: String
        private let ext: String
        private var player: AVPlayer?
        private weak var view: PlayerContainerView?
        private var prerolled = false
        private var statusObservation: NSKeyValueObservation?
        private var displayObservation: NSKeyValueObservation?
        private var endObserver: NSObjectProtocol?
        private var started = false
        private var beganPlayback = false

        init(resource: String, ext: String) {
            self.resource = resource
            self.ext = ext
        }

        func attach(
            to view: PlayerContainerView,
            onReady: @escaping () -> Void,
            onFinished: @escaping () -> Void
        ) {
            guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
                // Missing asset must not strand the user on a blank screen.
                DispatchQueue.main.async(execute: onReady)
                return
            }

            // `AVPlayer` activates the app's audio session on playback even for
            // a silent, video-only clip, and the default `soloAmbient` category
            // interrupts whatever the user has playing. `ambient` mixes instead.
            // The app produces no audio of its own, so this is the right
            // category for it outright; the session is never activated by hand.
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

            let item = AVPlayerItem(asset: AVURLAsset(url: url))
            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .pause  // hold the last frame instead of blanking
            player.automaticallyWaitsToMinimizeStalling = false

            view.playerLayer.player = player
            view.playerLayer.videoGravity = .resizeAspect
            // Default is an opaque black backing; the paper ground shows through
            // instead, so there is nothing to flash before the first frame.
            view.playerLayer.backgroundColor = UIColor.clear.cgColor
            view.playerLayer.isOpaque = false
            self.player = player
            self.view = view
            view.onVisibilityChange = { [weak self] in self?.startIfDrawable(onReady: onReady) }

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in onFinished() }

            statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard item.status == .readyToPlay else { return }
                guard let self, !self.started else { return }
                self.started = true

                // Decode ahead at the rate we will actually play at, so playback
                // opens on a warm pipeline rather than stuttering through the
                // first frames.
                player.preroll(atRate: splashPlaybackRate) { finished in
                    DispatchQueue.main.async {
                        guard finished else { return }
                        self.prerolled = true

                        // `readyToPlay` only means playback can begin; the layer
                        // still draws black until it holds a frame, and the
                        // caller reveals the view from `onReady`. Frames played
                        // before that are frames nobody sees, so the clip looks
                        // like it began partway in. Wait for the layer.
                        self.displayObservation = view.playerLayer.observe(
                            \.isReadyForDisplay, options: [.initial, .new]
                        ) { [weak self] _, _ in
                            DispatchQueue.main.async { self?.startIfDrawable(onReady: onReady) }
                        }

                        // Neither `isReadyForDisplay` nor a layout pass is
                        // promised on any particular schedule. `holdSplash`
                        // routes away at 4.6s, so a blank splash would be a
                        // visible dead launch: start regardless well before
                        // that. Worst case is the skip, not a hang.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                            self?.begin(onReady: onReady)
                        }
                    }
                }
            }
        }

        /// Starts playback and reveals the layer in the same turn, so the first
        /// frame the user sees is the first frame of the clip. Guarded because
        /// the display observation and the fallback timer race to call it.
        /// Starts only once the layer is genuinely on screen, sized, and
        /// holding a frame — the three things that must be true for the first
        /// frame drawn to be the first frame of the clip.
        private func startIfDrawable(onReady: () -> Void) {
            guard prerolled,
                  let view,
                  view.window != nil,
                  view.bounds.width > 0,
                  view.playerLayer.isReadyForDisplay
            else { return }
            begin(onReady: onReady)
        }

        private func begin(onReady: () -> Void) {
            guard !beganPlayback, let player else { return }
            beganPlayback = true
            // Setting `rate` starts playback; `play()` would reset it to 1x.
            player.rate = splashPlaybackRate
            onReady()
        }

        func stop() {
            statusObservation?.invalidate()
            statusObservation = nil
            displayObservation?.invalidate()
            displayObservation = nil
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            player?.pause()
            player = nil
        }
    }
}
