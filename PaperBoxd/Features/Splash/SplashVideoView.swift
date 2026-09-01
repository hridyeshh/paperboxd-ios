import AVFoundation
import SwiftUI

/// Playback rate for the splash clip. The 4.87s source runs 3.9s at 1.25x —
/// `AppState.holdSplash` is floored above that plus the outro fade.
private let splashPlaybackRate: Float = 1.25

/// The bundled splash clip on a bare `AVPlayerLayer` — no transport controls,
/// no audio session.
///
/// Everything here exists to keep the animation from hitching on a cold start:
/// the asset is a local file, the player is prerolled before it is allowed to
/// start, and stall avoidance is off (it buys nothing for a file URL and only
/// delays the first frame). The clip has no audio track, so the app never
/// touches `AVAudioSession` and never interrupts whatever the user is playing.
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
    }

    final class Coordinator {
        private let resource: String
        private let ext: String
        private var player: AVPlayer?
        private var statusObservation: NSKeyValueObservation?
        private var displayObservation: NSKeyValueObservation?
        private var endObserver: NSObjectProtocol?
        private var started = false

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
                // first frames. Setting `rate` starts playback; `play()` would
                // reset it to 1x.
                player.preroll(atRate: splashPlaybackRate) { finished in
                    DispatchQueue.main.async {
                        guard finished else { return }
                        player.rate = splashPlaybackRate
                        // `readyToPlay` only means playback can begin; the layer
                        // still draws black until it actually holds a frame.
                        // Reveal on isReadyForDisplay so nothing shows before
                        // there is a real frame to show.
                        if view.playerLayer.isReadyForDisplay {
                            onReady()
                        } else {
                            self.displayObservation = view.playerLayer.observe(
                                \.isReadyForDisplay, options: [.new]
                            ) { layer, _ in
                                guard layer.isReadyForDisplay else { return }
                                DispatchQueue.main.async { onReady() }
                            }
                        }
                    }
                }
            }
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
