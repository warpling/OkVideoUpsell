//
//  OKVideoProUpsellViewController.swift
//  OKViewUpsell
//
//  UIKit version of the "OKVideo Pro" paywall sheet.
//  Equivalent to OKVideoProUpsellView.swift but built entirely with UIKit.
//
//  Uses UISheetPresentationController with a custom content-measuring
//  detent on iOS 16+ and .medium()/.large() fallback on iOS 15.
//

import UIKit
import SwiftUI
import Combine
import StoreKit

// MARK: - Accent Color

private let okUIAccent = UIColor(red: 1.0, green: 0.26, blue: 0.40, alpha: 1.0)

// MARK: - Feature Definitions
// TODO: Customise titles, subtitles, and SF Symbol names below.

private struct UIKitProFeature {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

private let uikitProFeatures: [UIKitProFeature] = [
    UIKitProFeature(
        id: OKVideoProductID.projects,
        title: "Unlimited Projects",
        subtitle: "Never delete a project again",
        systemImage: "rectangle.stack.fill"                  // TODO: your icon
    ),
    UIKitProFeature(
        id: OKVideoProductID.watermark,
        title: "Remove Watermark",
        subtitle: "Professional, clean exports",
        systemImage: "eye.slash.fill"                        // TODO: your icon
    ),
    UIKitProFeature(
        id: OKVideoProductID.editor,
        title: "Timeline Editor",
        subtitle: "Full creative control",
        systemImage: "slider.horizontal.below.rectangle"     // TODO: your icon
    ),
]

// MARK: - Detent Identifier

@available(iOS 15.0, *)
private extension UISheetPresentationController.Detent.Identifier {
    static let compact = UISheetPresentationController.Detent.Identifier("compact")
}

// MARK: - View Controller

final class OKVideoProUpsellViewController: UIViewController {

    // MARK: Dependencies

    private let storeManager: StoreManager
    var onDismiss: (() -> Void)?

    // MARK: State

    private var showIndividualOptions = false
    private var isPurchasing = false
    private var compactContentHeight: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: Stored UI References (updated after creation)

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Pricing card
    private let pricingContainer = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)
    private let errorStack = UIStackView()
    private let loadedPricingStack = UIStackView()
    private let priceLabel = UILabel()
    private let strikeThroughLabel = UILabel()
    private let savingsBadge = UIButton(type: .custom)

    // CTA
    private let ctaButton = UIButton(type: .custom)
    private let ctaSpinner = UIActivityIndicatorView(style: .medium)
    private let ctaGradient = CAGradientLayer()

    // Individual options
    private let seeOptionsButton = UIButton(type: .system)
    private let individualContainer = UIView()
    private var individualRows: [(featureID: String, buyButton: UIButton, checkmark: UIImageView)] = []

    // MARK: Init

    init(storeManager: StoreManager) {
        self.storeManager = storeManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.11, alpha: 1)

        setupScrollView()
        addHeaderSection()
        addFeatureListSection()
        addPricingCardSection()
        addCTASection()
        addSeeOptionsSection()
        addIndividualSection()
        addRestoreSection()
        setupCloseButton()

        configureSheet()
        presentationController?.delegate = self
        bindToStoreManager()

        Task { await storeManager.loadProducts() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ctaGradient.frame = ctaButton.bounds
    }

    // MARK: - Scroll View & Content Stack

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
        ])
    }

    // MARK: - Close Button

    private func setupCloseButton() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 14
        container.clipsToBounds = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        container.addSubview(blur)

        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: symbolConfig), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.55)
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        button.accessibilityLabel = "Close"
        container.addSubview(button)

        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container.widthAnchor.constraint(equalToConstant: 28),
            container.heightAnchor.constraint(equalToConstant: 28),

            blur.topAnchor.constraint(equalTo: container.topAnchor),
            blur.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }

    // MARK: - Header Section

    private func addHeaderSection() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center

        // TODO: Replace with your own app icon / custom image.
        let icon = UIImageView()
        icon.image = UIImage(systemName: "lock.open.fill")
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 32)
        icon.tintColor = okUIAccent
        icon.setContentHuggingPriority(.required, for: .vertical)

        let title = UILabel()
        title.text = "OKVideo Pro"
        title.font = .systemFont(ofSize: 34, weight: .bold)
        title.textColor = .white
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.text = "Export professional, watermark-free\nvideos with full editing power."
        subtitle.font = .preferredFont(forTextStyle: .body)
        subtitle.textColor = UIColor(white: 0.55, alpha: 1)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)

        contentStack.addArrangedSubview(stack)
    }

    // MARK: - Feature List Section

    private func addFeatureListSection() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16

        for feature in uikitProFeatures {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 14
            row.alignment = .center

            let checkIcon = UIImageView()
            checkIcon.image = UIImage(systemName: "checkmark.circle.fill")
            checkIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22)
            checkIcon.tintColor = okUIAccent
            checkIcon.setContentHuggingPriority(.required, for: .horizontal)
            checkIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 2

            let titleLabel = UILabel()
            titleLabel.text = feature.title
            titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
            titleLabel.textColor = .white

            let subtitleLabel = UILabel()
            subtitleLabel.text = feature.subtitle
            subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
            subtitleLabel.textColor = UIColor(white: 0.45, alpha: 1)

            textStack.addArrangedSubview(titleLabel)
            textStack.addArrangedSubview(subtitleLabel)

            row.addArrangedSubview(checkIcon)
            row.addArrangedSubview(textStack)

            stack.addArrangedSubview(row)
        }

        contentStack.addArrangedSubview(stack)
    }

    // MARK: - Pricing Card Section

    private func addPricingCardSection() {
        pricingContainer.translatesAutoresizingMaskIntoConstraints = false
        pricingContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

        // --- Loading state ---
        loadingSpinner.color = .white
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        pricingContainer.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: pricingContainer.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: pricingContainer.centerYAnchor),
        ])

        // --- Error state ---
        errorStack.axis = .vertical
        errorStack.spacing = 8
        errorStack.alignment = .center
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.isHidden = true

        let errorLabel = UILabel()
        errorLabel.text = "Could not load prices"
        errorLabel.font = .preferredFont(forTextStyle: .subheadline)
        errorLabel.textColor = UIColor(white: 0.5, alpha: 1)

        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        retryButton.tintColor = okUIAccent
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        errorStack.addArrangedSubview(errorLabel)
        errorStack.addArrangedSubview(retryButton)
        pricingContainer.addSubview(errorStack)
        NSLayoutConstraint.activate([
            errorStack.centerXAnchor.constraint(equalTo: pricingContainer.centerXAnchor),
            errorStack.centerYAnchor.constraint(equalTo: pricingContainer.centerYAnchor),
        ])

        // --- Loaded state ---
        loadedPricingStack.axis = .horizontal
        loadedPricingStack.alignment = .center
        loadedPricingStack.spacing = 8
        loadedPricingStack.translatesAutoresizingMaskIntoConstraints = false
        loadedPricingStack.isHidden = true
        loadedPricingStack.backgroundColor = UIColor(white: 0.16, alpha: 1)
        loadedPricingStack.layer.cornerRadius = 14
        loadedPricingStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        loadedPricingStack.isLayoutMarginsRelativeArrangement = true

        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 4

        let oneTimeLabel = UILabel()
        oneTimeLabel.text = "One-time Purchase"
        oneTimeLabel.font = .systemFont(ofSize: 15, weight: .medium)
        oneTimeLabel.textColor = UIColor(white: 0.65, alpha: 1)

        let priceRow = UIStackView()
        priceRow.axis = .horizontal
        priceRow.alignment = .firstBaseline
        priceRow.spacing = 8

        priceLabel.font = .systemFont(ofSize: 22, weight: .bold)
        priceLabel.textColor = .white

        strikeThroughLabel.isHidden = true

        priceRow.addArrangedSubview(priceLabel)
        priceRow.addArrangedSubview(strikeThroughLabel)

        leftStack.addArrangedSubview(oneTimeLabel)
        leftStack.addArrangedSubview(priceRow)
        leftStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Savings badge — uses UIButton for proper intrinsic content size
        savingsBadge.isUserInteractionEnabled = false
        savingsBadge.isHidden = true
        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.baseBackgroundColor = okUIAccent
        badgeConfig.baseForegroundColor = .white
        badgeConfig.cornerStyle = .capsule
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        badgeConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            return outgoing
        }
        savingsBadge.configuration = badgeConfig
        savingsBadge.setContentHuggingPriority(.required, for: .horizontal)
        savingsBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        loadedPricingStack.addArrangedSubview(leftStack)
        loadedPricingStack.addArrangedSubview(savingsBadge)

        pricingContainer.addSubview(loadedPricingStack)
        NSLayoutConstraint.activate([
            loadedPricingStack.topAnchor.constraint(equalTo: pricingContainer.topAnchor),
            loadedPricingStack.bottomAnchor.constraint(equalTo: pricingContainer.bottomAnchor),
            loadedPricingStack.leadingAnchor.constraint(equalTo: pricingContainer.leadingAnchor),
            loadedPricingStack.trailingAnchor.constraint(equalTo: pricingContainer.trailingAnchor),
        ])

        loadedPricingStack.isAccessibilityElement = true
        loadedPricingStack.accessibilityTraits = .staticText

        contentStack.addArrangedSubview(pricingContainer)
    }

    // MARK: - CTA Section

    private func addCTASection() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        // Gradient button
        ctaButton.setTitle("Unlock OKVideo Pro", for: .normal)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.setTitleColor(UIColor.white.withAlphaComponent(0.4), for: .disabled)
        ctaButton.layer.cornerRadius = 16
        ctaButton.clipsToBounds = true
        ctaButton.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.heightAnchor.constraint(equalToConstant: 58).isActive = true

        ctaGradient.colors = [okUIAccent.cgColor, okUIAccent.withAlphaComponent(0.8).cgColor]
        ctaGradient.startPoint = CGPoint(x: 0, y: 0.5)
        ctaGradient.endPoint = CGPoint(x: 1, y: 0.5)
        ctaGradient.cornerRadius = 16
        ctaButton.layer.insertSublayer(ctaGradient, at: 0)

        ctaSpinner.color = .white
        ctaSpinner.hidesWhenStopped = true
        ctaSpinner.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.addSubview(ctaSpinner)
        NSLayoutConstraint.activate([
            ctaSpinner.centerXAnchor.constraint(equalTo: ctaButton.centerXAnchor),
            ctaSpinner.centerYAnchor.constraint(equalTo: ctaButton.centerYAnchor),
        ])

        let subtitle = UILabel()
        subtitle.text = "No subscription \u{2014} pay once, yours forever."
        subtitle.font = .preferredFont(forTextStyle: .caption1)
        subtitle.textColor = UIColor(white: 0.4, alpha: 1)
        subtitle.textAlignment = .center

        stack.addArrangedSubview(ctaButton)
        stack.addArrangedSubview(subtitle)

        contentStack.addArrangedSubview(stack)
    }

    // MARK: - See Options Section

    private func addSeeOptionsSection() {
        var config = UIButton.Configuration.plain()
        config.title = "See individual options"
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.baseForegroundColor = UIColor(white: 0.45, alpha: 1)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .subheadline)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        seeOptionsButton.configuration = config
        seeOptionsButton.addTarget(self, action: #selector(seeOptionsTapped), for: .touchUpInside)

        let wrapper = UIStackView(arrangedSubviews: [seeOptionsButton])
        wrapper.alignment = .center
        contentStack.addArrangedSubview(wrapper)
    }

    // MARK: - Individual Section

    private func addIndividualSection() {
        individualContainer.isHidden = true
        individualContainer.alpha = 0
        individualContainer.layer.cornerRadius = 12
        individualContainer.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        individualContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: individualContainer.topAnchor),
            stack.bottomAnchor.constraint(equalTo: individualContainer.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: individualContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: individualContainer.trailingAnchor),
        ])

        for feature in uikitProFeatures {
            let row = makeIndividualRow(for: feature)
            stack.addArrangedSubview(row)
        }

        contentStack.addArrangedSubview(individualContainer)
    }

    private func makeIndividualRow(for feature: UIKitProFeature) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.14, alpha: 1)

        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.spacing = 10
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])

        // TODO: Swap systemImage for your own asset
        let icon = UIImageView()
        icon.image = UIImage(systemName: feature.systemImage)
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15)
        icon.tintColor = okUIAccent
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = UILabel()
        titleLabel.text = feature.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Buy button (hidden until products load)
        let featureID = feature.id
        var buyConfig = UIButton.Configuration.filled()
        buyConfig.baseBackgroundColor = okUIAccent
        buyConfig.baseForegroundColor = .white
        buyConfig.cornerStyle = .capsule
        buyConfig.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        buyConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            return outgoing
        }
        let buyButton = UIButton(configuration: buyConfig, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            Task { await self.purchaseIndividual(featureID) }
        })
        buyButton.isHidden = true

        // Checkmark (hidden by default)
        let checkmark = UIImageView()
        checkmark.image = UIImage(systemName: "checkmark.circle.fill")
        checkmark.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18)
        checkmark.tintColor = .systemGreen
        checkmark.isHidden = true
        checkmark.setContentHuggingPriority(.required, for: .horizontal)

        rowStack.addArrangedSubview(icon)
        rowStack.addArrangedSubview(titleLabel)
        rowStack.addArrangedSubview(buyButton)
        rowStack.addArrangedSubview(checkmark)

        individualRows.append((featureID: feature.id, buyButton: buyButton, checkmark: checkmark))

        container.isAccessibilityElement = true
        container.accessibilityLabel = feature.title

        return container
    }

    // MARK: - Restore Section

    private func addRestoreSection() {
        let button = UIButton(type: .system)
        button.setTitle("Restore Purchases", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        button.tintColor = UIColor(white: 0.3, alpha: 1)
        button.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        let wrapper = UIStackView(arrangedSubviews: [button])
        wrapper.alignment = .center
        contentStack.addArrangedSubview(wrapper)
    }

    // MARK: - Combine Bindings

    private func bindToStoreManager() {
        storeManager.$products
            .combineLatest(storeManager.$isLoading, storeManager.$purchasedProductIDs, storeManager.$errorMessage)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updatePricingCard()
                self.updateIndividualRows()
                self.updateCTAState()
                // Measure content after layout settles
                DispatchQueue.main.async {
                    self.measureCompactHeight()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Updates

    private func updatePricingCard() {
        let isLoading = storeManager.isLoading
        let hasError = storeManager.errorMessage != nil
        let hasProduct = storeManager.proProduct != nil

        if isLoading { loadingSpinner.startAnimating() } else { loadingSpinner.stopAnimating() }
        errorStack.isHidden = !hasError || isLoading
        loadedPricingStack.isHidden = !hasProduct || isLoading || hasError

        guard let pro = storeManager.proProduct else { return }

        priceLabel.text = pro.displayPrice

        if let total = storeManager.individualTotalFormatted {
            let attrs: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor(white: 0.35, alpha: 1),
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
            ]
            strikeThroughLabel.attributedText = NSAttributedString(string: total, attributes: attrs)
            strikeThroughLabel.isHidden = false
        } else {
            strikeThroughLabel.isHidden = true
        }

        let savings = storeManager.savingsPercentage
        savingsBadge.isHidden = savings <= 0
        var badgeConfig = savingsBadge.configuration ?? UIButton.Configuration.filled()
        badgeConfig.title = "SAVE \(savings)%"
        savingsBadge.configuration = badgeConfig

        // Update accessibility
        var accessLabel = "One-time Purchase. \(pro.displayPrice)."
        if let total = storeManager.individualTotalFormatted {
            accessLabel += " Originally \(total)."
        }
        if savings > 0 {
            accessLabel += " Save \(savings) percent."
        }
        loadedPricingStack.accessibilityLabel = accessLabel
    }

    private func updateIndividualRows() {
        for row in individualRows {
            let owned = storeManager.isPurchased(row.featureID)
            let product = storeManager.products[row.featureID]

            row.checkmark.isHidden = !owned
            row.buyButton.isHidden = owned || product == nil

            if let product, !owned {
                var config = row.buyButton.configuration ?? UIButton.Configuration.filled()
                config.title = product.displayPrice
                row.buyButton.configuration = config
            }
        }
    }

    private func updateCTAState() {
        ctaButton.isEnabled = !isPurchasing && storeManager.proProduct != nil
        if isPurchasing {
            ctaButton.setTitle(nil, for: .normal)
            ctaSpinner.startAnimating()
        } else {
            ctaButton.setTitle("Unlock OKVideo Pro", for: .normal)
            ctaSpinner.stopAnimating()
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismissSheet()
    }

    @objc private func ctaTapped() {
        Task { await purchaseBundle() }
    }

    @objc private func seeOptionsTapped() {
        showIndividualOptions.toggle()

        var config = seeOptionsButton.configuration
        config?.title = showIndividualOptions ? "Hide individual options" : "See individual options"
        config?.image = UIImage(systemName: showIndividualOptions ? "chevron.up" : "chevron.down")
        seeOptionsButton.configuration = config

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: []
        ) {
            self.individualContainer.isHidden = !self.showIndividualOptions
            self.individualContainer.alpha = self.showIndividualOptions ? 1 : 0
            self.contentStack.layoutIfNeeded()
        }

        animateDetentChange()
    }

    @objc private func retryTapped() {
        Task { await storeManager.loadProducts() }
    }

    @objc private func restoreTapped() {
        Task { await storeManager.restorePurchases() }
    }

    // MARK: - Purchase Logic

    private func purchaseBundle() async {
        guard let product = storeManager.proProduct else { return }
        isPurchasing = true
        updateCTAState()
        defer {
            isPurchasing = false
            updateCTAState()
        }
        do {
            if try await storeManager.purchase(product) != nil {
                dismissSheet()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func purchaseIndividual(_ productID: String) async {
        guard let product = storeManager.products[productID] else { return }
        isPurchasing = true
        updateCTAState()
        defer {
            isPurchasing = false
            updateCTAState()
        }
        do {
            try await storeManager.purchase(product)
            if storeManager.isFullyUnlocked {
                dismissSheet()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func dismissSheet() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Something went wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Sheet Detent Configuration

    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 20

        if #available(iOS 16.0, *) {
            let compact = UISheetPresentationController.Detent.custom(identifier: .compact) { [weak self] context in
                guard let self, self.compactContentHeight > 0 else {
                    return context.maximumDetentValue
                }
                return min(self.compactContentHeight, context.maximumDetentValue)
            }
            sheet.detents = [compact, .large()]
            sheet.selectedDetentIdentifier = .compact
        } else {
            sheet.detents = [.medium(), .large()]
        }
    }

    private func measureCompactHeight() {
        guard !showIndividualOptions else { return }
        view.layoutIfNeeded()
        let height = scrollView.contentSize.height
        guard height > 0 else { return }
        compactContentHeight = height

        if #available(iOS 16.0, *) {
            sheetPresentationController?.invalidateDetents()
        }
    }

    private func animateDetentChange() {
        if #available(iOS 16.0, *) {
            sheetPresentationController?.animateChanges {
                self.sheetPresentationController?.selectedDetentIdentifier = self.showIndividualOptions ? .large : .compact
            }
        }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension OKVideoProUpsellViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss?()
    }
}

// MARK: - SwiftUI Bridge
/// Presents the UIKit upsell view controller as a modal sheet.
/// Add this as a background element and control with `isPresented`.
struct UIKitUpsellPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let storeManager: StoreManager

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        if isPresented {
            guard host.presentedViewController == nil, !context.coordinator.isPresenting else { return }
            context.coordinator.isPresenting = true

            let upsellVC = OKVideoProUpsellViewController(storeManager: storeManager)
            upsellVC.onDismiss = {
                isPresented = false
                context.coordinator.isPresenting = false
            }

            DispatchQueue.main.async {
                host.present(upsellVC, animated: true) {
                    context.coordinator.isPresenting = false
                }
            }
        } else if host.presentedViewController != nil {
            host.dismiss(animated: true)
        }
    }

    class Coordinator {
        var isPresenting = false
    }
}

// MARK: - Preview

#Preview("UIKit Version") {
    ZStack {
        Color.black.ignoresSafeArea()
        UIKitUpsellPresenter(isPresented: .constant(true), storeManager: StoreManager())
    }
}
