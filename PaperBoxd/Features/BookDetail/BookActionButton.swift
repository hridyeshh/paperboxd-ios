import SwiftUI

/// Read / Like / TBR toggle button in book detail action row.
/// Shows accent fill when active, secondary when inactive. Spinner while loading.
struct BookActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let isLoading: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(isActive ? Color("Accent") : Color("TextSecondary"))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isActive ? icon + ".fill" : icon)
                            .font(.system(size: 22))
                            .foregroundStyle(isActive ? Color("Accent") : Color("TextSecondary"))
                            .animation(.easeInOut(duration: 0.18), value: isActive)
                    }
                }
                .frame(width: 24, height: 24)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? Color("Accent") : Color("TextSecondary"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? Color("Accent").opacity(0.12) : Color("Surface"))
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
    }
}
