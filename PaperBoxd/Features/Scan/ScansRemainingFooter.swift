import SwiftUI

/// Live free-scan count, shown at the foot of the Reveal + Breakdown screens.
/// Reads the value persisted by `ScanService.analyze` after each scan.
struct ScansRemainingFooter: View {
    @AppStorage("pb_scans_remaining") private var scansRemaining: Int = 7

    var body: some View {
        Text(footerText)
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
    }

    private var footerText: String {
        switch scansRemaining {
        case 0:
            return "No free scans remaining"
        case 1:
            return "1 free scan remaining"
        default:
            return "\(scansRemaining) free scans remaining"
        }
    }
}
