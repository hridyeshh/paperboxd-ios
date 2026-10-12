import Foundation
import Combine
import StoreKit

/// PaperBoxd Plus — the subscription that unlocks Ask Jazy.
///
/// StoreKit 2 on the device, one row on the backend. The backend is the
/// source of truth for the entitlement (`GET /subscriptions/me`); StoreKit
/// only supplies receipts. Every transaction StoreKit hands us — purchase,
/// restore, renewal from `Transaction.updates` — goes to
/// `POST /subscriptions/apple` as its JWS and lands on the same row.
@MainActor
final class PlusStore: ObservableObject {
    static let shared = PlusStore()

    enum ProductID: String, CaseIterable {
        case monthly = "in.paperboxd.plus.monthly"
        case yearly  = "in.paperboxd.plus.yearly"
    }

    struct Status: Decodable {
        let active: Bool
        var scansRemaining: Int? = nil
        var scansUnlimited: Bool? = nil

        enum CodingKeys: String, CodingKey {
            case active
            case scansRemaining = "scans_remaining"
            case scansUnlimited = "scans_unlimited"
        }
    }

    /// Nil until the first backend check answers; callers treat nil as
    /// "unknown" and fail closed (show the paywall) — the backend rejects the
    /// ask anyway, so nothing is lost by asking twice.
    @Published private(set) var isActive: Bool?
    @Published private(set) var products: [Product] = []
    /// True once a product query came back empty — no products in App Store
    /// Connect / no `.storekit` config on the scheme. Lets the paywall show
    /// "unavailable" instead of spinning forever.
    @Published private(set) var productsUnavailable = false
    @Published private(set) var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    private init() {}

    /// Call once the user is signed in. Starts the renewal listener and
    /// answers `isActive`.
    func start() {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await result in StoreKit.Transaction.updates {
                    guard let self, case .verified(let tx) = result else { continue }
                    await self.link(result)
                    await tx.finish()
                }
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        let status: Status? = try? await APIClient.shared.request(
            path: "/api/v1/subscriptions/me", method: .get, requiresAuth: true)
        guard let status else { return }
        isActive = status.active
        // The scan allowance resets monthly on the backend; this is where the
        // local counter learns about it without a scan.
        if let remaining = status.scansRemaining {
            UserDefaults.standard.set(remaining, forKey: "pb_scans_remaining")
        }
        UserDefaults.standard.set(status.scansUnlimited ?? status.active, forKey: "pb_scans_unlimited")
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        let ids = ProductID.allCases.map(\.rawValue)
        products = ((try? await Product.products(for: ids)) ?? [])
            .sorted { $0.price < $1.price }
        productsUnavailable = products.isEmpty
    }

    /// Runs the App Store sheet, then links the receipt. Returns true when
    /// the backend confirms the entitlement.
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let tx) = verification else { throw PlusError.unverified }
            let ok = await link(verification)
            await tx.finish()
            return ok
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// "Restore purchases": sync with the App Store, then re-link whatever
    /// subscription this Apple ID holds.
    func restore() async -> Bool {
        try? await AppStore.sync()
        var linked = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let tx) = result, ProductID(rawValue: tx.productID) != nil else { continue }
            if await link(result) { linked = true }
        }
        if !linked { await refresh() }
        return linked
    }

    /// POST the signed transaction (the JWS lives on the VerificationResult,
    /// not the Transaction). 409 means the receipt backs another account —
    /// surfaced as false, never as a crash, since the renewal listener hits
    /// it routinely on a shared device.
    @discardableResult
    private func link(_ result: VerificationResult<StoreKit.Transaction>) async -> Bool {
        struct Body: Encodable { let jws: String }
        do {
            let status: Status = try await APIClient.shared.request(
                path: "/api/v1/subscriptions/apple",
                method: .post,
                body: Body(jws: result.jwsRepresentation),
                requiresAuth: true)
            isActive = status.active
            UserDefaults.standard.set(status.active, forKey: "pb_scans_unlimited")
            return status.active
        } catch {
            return false
        }
    }

    enum PlusError: LocalizedError {
        case unverified
        var errorDescription: String? { "The App Store could not verify this purchase." }
    }
}
