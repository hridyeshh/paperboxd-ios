import SwiftUI

struct ProfileDockView: View {
    @Binding var selected: ProfileTab
    var count: (ProfileTab) -> Int?
    var onSelect: (ProfileTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button { onSelect(tab) } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 5) {
                                Text(tab.rawValue)
                                    .font(.system(size: 13.5, weight: selected == tab ? .semibold : .medium))
                                    .foregroundStyle(selected == tab ? Color("TextPrimary") : Color("TextSecondary"))
                                if let n = count(tab) {
                                    Text("\(n)")
                                        .font(PB.mono(10))
                                        .foregroundStyle(Color("TextSecondary").opacity(0.8))
                                }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 11)

                            Rectangle()
                                .fill(selected == tab ? Color("TextPrimary") : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: selected)
                }
            }
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }
}
