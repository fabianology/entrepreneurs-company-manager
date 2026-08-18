import SwiftUI
import StoreKit
import Observation
struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM
    
    @State private var isYearly = true
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.zifrGreen.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Image/Graphic
                ZStack {
                    Circle()
                        .fill(Color(hex: "#3b82f6").opacity(0.2))
                        .frame(width: 160, height: 160)
                        .blur(radius: 40)
                    
                    Image(systemName: "crown.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "#60a5fa"), Color(hex: "#2563eb")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                .padding(.top, 40)
                .padding(.bottom, 24)
                
                Text("MILOOM PRO")
                    .font(.system(size: 32, weight: .black))
                    .tracking(2)
                    .foregroundStyle(.white)
                
                Text("Unlock the ultimate business manager.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.top, 8)
                
                // Features
                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(icon: "chart.pie.fill", title: "Unlimited Financial Sync", description: "Connect unlimited Plaid accounts and sync in real-time.")
                    FeatureRow(icon: "doc.text.viewfinder", title: "Advanced Document OCR", description: "Automatically extract data from your uploaded receipts and contracts.")
                    FeatureRow(icon: "person.3.sequence.fill", title: "Team Collaboration", description: "Invite unlimited team members and manage role-based access.")
                    FeatureRow(icon: "headphones", title: "Priority Support", description: "Get dedicated 24/7 priority support from our experts.")
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
                
                Spacer()
                
                // Pricing Toggle
                HStack(spacing: 0) {
                    PricingTab(title: "Monthly", subtitle: "$19.99/mo", isSelected: !isYearly) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isYearly = false
                        }
                    }
                    PricingTab(title: "Yearly", subtitle: "$199.99/yr", isSelected: isYearly) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isYearly = true
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Text("SAVE 20%")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                            .offset(x: -8, y: 8)
                    }
                }
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                
                // CTA Button
                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    Task {
                        let productId = isYearly ? "com.miloom.premium.yearly" : "com.miloom.premium.monthly"
                        if let product = StoreService.shared.products.first(where: { $0.id == productId }) {
                            do {
                                try await StoreService.shared.purchase(product)
                                dismiss()
                            } catch {
                                print("Purchase failed: \(error)")
                            }
                        } else {
                            // Fallback if products not loaded in simulator
                            dismiss()
                        }
                    }
                } label: {
                    Text(isYearly ? "Start Yearly Trial" : "Start Monthly Trial")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(colors: [Color(hex: "#2563eb"), Color(hex: "#1d4ed8")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(hex: "#2563eb").opacity(0.5), radius: 15, y: 5)
                }
                .padding(.horizontal, 32)
                
                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color(hex: "#60a5fa"))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PricingTab: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundStyle(isSelected ? .white : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

@Observable
final class StoreService {
    static let shared = StoreService()
    
    var isPremium: Bool = false
    var products: [Product] = []
    
    private let productIDs = ["com.miloom.premium.monthly", "com.miloom.premium.yearly"]
    
    private init() {
        Task {
            await fetchProducts()
            await updateCustomerProductStatus()
        }
    }
    
    @MainActor
    func fetchProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed product request from the App Store server: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    isPremium = true
                    return
                }
            } catch {
                print("Transaction verification failed.")
            }
        }
        isPremium = false
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    enum StoreError: Error {
        case failedVerification
    }
}
