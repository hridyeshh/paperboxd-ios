import SwiftUI
import StoreKit

/// The Plus paywall, in Jazy's own kit: hard ink frame, mono readouts, one
/// serif line. Shown over the Jazy entry screen whenever the reader is not
/// subscribed. `onUnlocked` fires once the backend confirms the purchase.
struct PlusPaywallView: View {
    /// Which feature opened it — analytics metadata, and the headline.
    var feature: Feature = .jazy
    let onUnlocked: () -> Void
    let onDismiss: () -> Void

    enum Feature: String {
        case jazy, scan, taste
        var headline: String {
            switch self {
            case .jazy:  return "Ask Jazy anything about your next read."
            case .scan:  return "Scan every cover you wonder about."
            case .taste: return "See the whole shape of your taste."
            }
        }
        var body: String {
            switch self {
            case .jazy:  return "Jazy reads your shelf, your ratings and your thoughts, then talks you to the right book. Plus keeps the conversation open."
            case .scan:  return "Free readers get 3 scans a month. Plus makes Scan & Know unlimited, and opens Ask Jazy too."
            case .taste: return "Your taste axes, how they shift, and the patterns behind your ratings — the full mirror, on Plus."
            }
        }
    }

    @ObservedObject private var store = PlusStore.shared
    @State private var selected: PlusStore.ProductID = .yearly
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    MonoLabel(text: "PaperBoxd Plus", size: 9.5, tracking: 2.2, color: SK.faint)
                    Spacer()
                    PipFace()
                        .frame(width: 30, height: 32)
                        .offset(x: 2, y: -4)
                }

                Text(feature.headline)
                    .font(PB.serif(23, .semibold))
                    .foregroundStyle(SK.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                Text(feature.body)
                    .font(.system(size: 13.5))
                    .foregroundStyle(SK.sub)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                Rectangle().fill(SK.ink.opacity(0.14)).frame(height: 1).padding(.vertical, 16)

                if store.products.isEmpty {
                    if store.productsUnavailable {
                        Button {
                            Task { await store.loadProducts(); await loadTrial() }
                        } label: {
                            MonoLabel(text: "Plans unavailable · Tap to retry", size: 10, tracking: 1.6, color: SK.accent)
                                .frame(maxWidth: .infinity, minHeight: 96)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack {
                            ProgressView().tint(SK.ink)
                            MonoLabel(text: "Loading plans", size: 10, tracking: 1.6, color: SK.faint)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.products, id: \.id) { product in
                            planRow(product)
                        }
                    }
                }

                Button {
                    Task { await buy() }
                } label: {
                    MonoLabel(text: busy ? "Opening App Store" : (trialDays > 0 ? "Start \(trialDays)-day free trial" : "Start Plus"),
                              size: 12, tracking: 1.4, color: SK.panel, weight: .semibold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(BrutalButtonStyle(fill: SK.ink, shadowColor: SK.ink.opacity(0.78),
                                               border: SK.ink, borderWidth: 2, offset: 4))
                .disabled(busy || store.products.isEmpty)
                .padding(.top, 20)
                .padding(.trailing, 4)
                .padding(.bottom, 4)

                if let message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(SK.accent)
                        .padding(.top, 8)
                }

                HStack(spacing: 14) {
                    Button("Restore purchases") { Task { await restore() } }
                    Link("Terms", destination: URL(string: "https://paperboxd.in/terms")!)
                    Link("Privacy", destination: URL(string: "https://paperboxd.in/privacy")!)
                }
                .font(PB.mono(9.5))
                .foregroundStyle(SK.faint)
                .padding(.top, 14)

                // App Store guideline 3.1.2: price, period and auto-renew terms
                // must be stated where the subscription is sold.
                Text((trialDays > 0 ? "Free for \(trialDays) days, then " : "") + "auto-renews until cancelled. Charged to your Apple ID at confirmation; manage or cancel in Settings › Apple ID › Subscriptions.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(SK.faint)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .padding(20)
            .background(SK.panel)
            .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: 2))
            .background(Rectangle().fill(SK.ink).offset(x: 5, y: 5))
            .padding(.horizontal, 28)
            .padding(.trailing, 5)
            .padding(.bottom, 5)
        }
        .task {
            Analytics.track("paywall_viewed", metadata: ["feature": feature.rawValue, "surface": "app"])
            await store.loadProducts()
            await loadTrial()
        }
    }

    /// Days of introductory free trial on the selected plan, 0 when none or
    /// the Apple ID has already used it. StoreKit applies it automatically at
    /// purchase; this only decides the copy.
    @State private var trialDays = 0

    private func loadTrial() async {
        guard let product = store.products.first(where: { $0.id == selected.rawValue }),
              let sub = product.subscription,
              let offer = sub.introductoryOffer, offer.paymentMode == .freeTrial,
              await sub.isEligibleForIntroOffer else { trialDays = 0; return }
        let p = offer.period
        trialDays = p.unit == .week ? p.value * 7 : (p.unit == .day ? p.value : 0)
    }

    private func planRow(_ product: Product) -> some View {
        let id = PlusStore.ProductID(rawValue: product.id)
        let isOn = id == selected
        return Button {
            if let id { selected = id; Task { await loadTrial() } }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    MonoLabel(text: id == .yearly ? "Yearly" : "Monthly", size: 10, tracking: 1.6,
                              color: isOn ? SK.panel : SK.ink, weight: .semibold)
                    if id == .yearly {
                        MonoLabel(text: "Two months free", size: 8.5, tracking: 1.2,
                                  color: isOn ? SK.panel.opacity(0.7) : SK.faint)
                    }
                }
                Spacer()
                Text("\(product.displayPrice) / \(id == .yearly ? "yr" : "mo")")
                    .font(PB.serif(17, .semibold))
                    .foregroundStyle(isOn ? SK.panel : SK.ink)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isOn ? SK.ink : SK.bgSoft)
            .overlay(Rectangle().strokeBorder(SK.ink, lineWidth: isOn ? 2 : 1.5))
        }
        .buttonStyle(.plain)
    }

    private func buy() async {
        guard let product = store.products.first(where: { $0.id == selected.rawValue }) else { return }
        Analytics.track("premium_cta_clicked", metadata: ["feature": feature.rawValue, "plan": selected.rawValue])
        busy = true
        message = nil
        defer { busy = false }
        do {
            if try await store.purchase(product) {
                onUnlocked()
            } else if store.isActive == false {
                message = "Purchase not completed."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func restore() async {
        busy = true
        message = nil
        defer { busy = false }
        if await store.restore() {
            onUnlocked()
        } else {
            message = "No Plus subscription found for this Apple ID."
        }
    }
}
