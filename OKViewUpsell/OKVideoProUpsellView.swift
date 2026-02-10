//
//  OKVideoProUpsellView.swift
//  OKViewUpsell
//
//  The "OKVideo Pro" paywall sheet. Present this when a user hits
//  a locked feature gate (e.g. new project limit, watermark, editor).
//
//  Bundle-first design with an expandable "See individual options" section.
//  Uses smart detents on iOS 16+ (compact → large when options expand).
//  Falls back gracefully to a plain full-height sheet on iOS 15.
//

import SwiftUI
import StoreKit

// MARK: - Accent Color
// TODO: Adjust this to match your app's accent color exactly.
private let okAccent = Color(red: 1.0, green: 0.26, blue: 0.40)

// MARK: - Feature Definitions
// TODO: Customise titles, subtitles, and SF Symbol names below.
//       To use your own image assets instead of SF Symbols, swap
//       `Image(systemName:)` for `Image("YourAssetName")` in the view.

private struct ProFeature: Identifiable {
    let id: String          // Must match an OKVideoProductID
    let title: String
    let subtitle: String
    let systemImage: String // SF Symbol name — easy to swap for a custom asset
}

private let proFeatures: [ProFeature] = [
    ProFeature(
        id: OKVideoProductID.projects,
        title: "Unlimited Projects",
        subtitle: "Never delete a project again",
        systemImage: "rectangle.stack.fill"                 // TODO: your icon
    ),
    ProFeature(
        id: OKVideoProductID.watermark,
        title: "Remove Watermark",
        subtitle: "Professional, clean exports",
        systemImage: "eye.slash.fill"                       // TODO: your icon
    ),
    ProFeature(
        id: OKVideoProductID.editor,
        title: "Timeline Editor",
        subtitle: "Full creative control",
        systemImage: "slider.horizontal.below.rectangle"    // TODO: your icon
    ),
]

// MARK: - Upsell View

struct OKVideoProUpsellView: View {

    @ObservedObject var storeManager: StoreManager

    @Environment(\.dismiss) private var dismiss
    @State private var showIndividualOptions = false
    @State private var isPurchasing = false
    @State private var purchaseError: String?

    // MARK: Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 12)
                    headerSection
                    featureListSection
                    pricingCard
                    ctaButton
                    seeOptionsLink
                    if showIndividualOptions {
                        individualSection
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    restoreLink
                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, 24)
            }
            .scrollBounceBehaviorIfAvailable()

            closeButton
        }
        .background(Color(white: 0.11))
        .task { await storeManager.loadProducts() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )
        ) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
        .smartSheetPresentation(isExpanded: showIndividualOptions)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Close")
        .padding(.trailing, 20)
        .padding(.top, 16)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            // TODO: Replace with your own app icon / custom image.
            //       e.g.  Image("ProBadge")
            //             Image("AppIconSmall")
            Image(systemName: "lock.open.fill")
                .font(.system(size: 32))
                .foregroundStyle(okAccent)

            Text("OKVideo Pro")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Export professional, watermark-free\nvideos with full editing power.")
                .font(.body)
                .foregroundStyle(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Feature List

    private var featureListSection: some View {
        VStack(spacing: 16) {
            ForEach(proFeatures) { feature in
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(okAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(feature.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer()
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Pricing Card

    private var pricingCard: some View {
        Group {
            if storeManager.isLoading {
                ProgressView()
                    .tint(.white)
            } else if storeManager.errorMessage != nil {
                VStack(spacing: 8) {
                    Text("Could not load prices")
                        .font(.subheadline)
                        .foregroundStyle(Color(white: 0.5))
                    Button("Retry") {
                        Task { await storeManager.loadProducts() }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(okAccent)
                }
            } else if let pro = storeManager.proProduct {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("One-time Purchase")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(white: 0.65))

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(pro.displayPrice)
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            if let total = storeManager.individualTotalFormatted {
                                Text(total)
                                    .font(.subheadline)
                                    .strikethrough()
                                    .foregroundStyle(Color(white: 0.35))
                            }
                        }
                    }

                    Spacer()

                    if storeManager.savingsPercentage > 0 {
                        Text("SAVE \(storeManager.savingsPercentage)%")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(okAccent, in: Capsule())
                    }
                }
                .accessibilityElement(children: .combine)
                .padding(16)
                .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        // Consistent minimum height prevents the CTA from jumping
        // when the spinner is replaced by the pricing card.
        .frame(maxWidth: .infinity, minHeight: 80)
        .animation(.easeOut(duration: 0.25), value: storeManager.isLoading)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchaseBundle() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Unlock OKVideo Pro")
                            .font(.headline.weight(.bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58) // Tall tap target per Superwall recommendation
                .background(
                    LinearGradient(
                        colors: [okAccent, okAccent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .disabled(isPurchasing || storeManager.proProduct == nil)

            Text("No subscription — pay once, yours forever.")
                .font(.caption)
                .foregroundStyle(Color(white: 0.4))
        }
    }

    // MARK: - See Individual Options Link

    private var seeOptionsLink: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showIndividualOptions.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(showIndividualOptions
                     ? "Hide individual options"
                     : "See individual options")
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(showIndividualOptions ? 180 : 0))
            }
            .font(.subheadline)
            .foregroundStyle(Color(white: 0.45))
        }
    }

    // MARK: - Individual Purchases

    private var individualSection: some View {
        VStack(spacing: 1) {
            ForEach(proFeatures) { feature in
                individualRow(for: feature)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func individualRow(for feature: ProFeature) -> some View {
        let product = storeManager.products[feature.id]
        let owned   = storeManager.isPurchased(feature.id)

        return HStack {
            // TODO: Swap systemImage for your own asset with Image("name")
            Image(systemName: feature.systemImage)
                .font(.system(size: 15))
                .foregroundStyle(okAccent)
                .frame(width: 26)

            Text(feature.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            if owned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            } else if let product {
                Button {
                    Task { await purchaseIndividual(product) }
                } label: {
                    Text(product.displayPrice)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(okAccent, in: Capsule())
                }
                .disabled(isPurchasing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(white: 0.14))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Restore Link (intentionally subtle)

    private var restoreLink: some View {
        Button {
            Task { await storeManager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.footnote)
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(.top, 4)
    }

    // MARK: - Purchase Actions

    private func purchaseBundle() async {
        guard let product = storeManager.proProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await storeManager.purchase(product) != nil {
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func purchaseIndividual(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await storeManager.purchase(product)
            if storeManager.isFullyUnlocked { dismiss() }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

// MARK: - Smart Sheet Presentation (iOS 16+)

/// Manages sheet detents: starts compact, auto-expands when individual
/// options are revealed, and falls back gracefully on older iOS.
@available(iOS 16.0, *)
private struct SheetPresentationModifier: ViewModifier {
    var isExpanded: Bool
    @State private var selectedDetent: PresentationDetent = .fraction(0.7)

    func body(content: Content) -> some View {
        content
            .presentationDetents([.fraction(0.7), .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundIfAvailable()
            .task(id: isExpanded) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedDetent = isExpanded ? .large : .fraction(0.7)
                }
            }
    }
}

// MARK: - Availability Helpers

extension View {
    /// Applies smart sheet detents on iOS 16+; plain sheet on iOS 15.
    @ViewBuilder
    fileprivate func smartSheetPresentation(isExpanded: Bool) -> some View {
        if #available(iOS 16.0, *) {
            self.modifier(SheetPresentationModifier(isExpanded: isExpanded))
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func presentationBackgroundIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(Color(white: 0.11))
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func scrollBounceBehaviorIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            OKVideoProUpsellView(storeManager: StoreManager())
        }
}
