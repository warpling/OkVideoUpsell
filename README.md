# OKVideo Pro Upsell Sheet

A drop-in SwiftUI paywall for OKVideo that bundles three existing IAPs into a single "OKVideo Pro" unlock. Built with StoreKit 2 — no subscriptions, no third-party SDKs.

## What's Inside

| File | Purpose |
|---|---|
| `StoreManager.swift` | StoreKit 2 manager — loads products, handles purchases, checks entitlements, listens for transaction updates |
| `OKVideoProUpsellView.swift` | The paywall sheet UI — bundle-first with expandable individual options |
| `ContentView.swift` | Demo harness showing how to present the sheet |

## How It Works

The sheet presents a unified "OKVideo Pro" bundle as the primary purchase. Below the main CTA, a small "See individual options" link expands to reveal the three a-la-carte purchases. This lets you offer the bundle without removing the existing IAPs.

- **Bundle purchase** dismisses the sheet on success
- **Individual purchases** show a green checkmark per owned item; if all three are bought, the sheet dismisses
- **Savings badge** and **strikethrough total** are calculated dynamically from real App Store prices
- **"No subscription — pay once, yours forever."** is displayed below the buy button
- **Restore Purchases** is present but intentionally subtle (footnote-sized text)

## Setup Checklist

### 1. Create the bundle product in App Store Connect

Create a new **non-consumable** IAP for the bundle (e.g. "OKVideo Pro"). Price it below the sum of the three individuals — the sheet will auto-calculate and display the savings percentage.

### 2. Replace product identifiers

Open `StoreManager.swift` and replace the placeholder strings in `OKVideoProductID` with your real App Store Connect product IDs:

```swift
enum OKVideoProductID {
    static let pro       = "com.okvideo.pro"         // ← your bundle product ID
    static let projects  = "com.okvideo.projects"    // ← your existing "multiple projects" ID
    static let watermark = "com.okvideo.watermark"   // ← your existing "remove watermark" ID
    static let editor    = "com.okvideo.editor"      // ← your existing "timeline editor" ID
}
```

### 3. Match your brand color

Open `OKVideoProUpsellView.swift` and adjust the accent color at the top of the file:

```swift
private let okAccent = Color(red: 1.0, green: 0.26, blue: 0.40) // ← your pink
```

### 4. Swap in your icons

Search for `// TODO: your icon` in `OKVideoProUpsellView.swift`. The defaults are SF Symbols — swap any of them for your own image assets:

```swift
// SF Symbol (default)
Image(systemName: "rectangle.stack.fill")

// Your own asset
Image("YourCustomIcon")
```

The header lock icon (`lock.open.fill`) can also be replaced with your app icon or a custom badge — search for `// TODO: Replace with your own app icon`.

### 5. Present the sheet from your feature gates

Wherever you currently show the old individual paywall, present `OKVideoProUpsellView` instead:

```swift
// In your view:
@State private var showUpsell = false
@StateObject private var storeManager = StoreManager()

// Trigger it when the user hits a locked feature:
.sheet(isPresented: $showUpsell) {
    // Detents, drag indicator, and background are all handled
    // inside OKVideoProUpsellView (with iOS 15 fallbacks).
    OKVideoProUpsellView(storeManager: storeManager)
}
```

Keep a single `StoreManager` instance and pass it to each sheet presentation so entitlement state stays in sync.

### 6. Test with a StoreKit Configuration file

In Xcode: **File > New > File > StoreKit Configuration File**. Add your four products (the bundle + three individuals) with test prices. Then edit your scheme (**Product > Scheme > Edit Scheme > Run > Options**) and select the configuration file under **StoreKit Configuration**. This lets you test purchases in the simulator without a sandbox account.

## Customizing Copy

Feature titles, subtitles, and ordering are all defined in the `proFeatures` array at the top of `OKVideoProUpsellView.swift`:

```swift
private let proFeatures: [ProFeature] = [
    ProFeature(
        id: OKVideoProductID.projects,
        title: "Unlimited Projects",           // ← feature name
        subtitle: "Never delete a project again", // ← benefit line
        systemImage: "rectangle.stack.fill"     // ← icon
    ),
    // ...
]
```

The CTA text ("Unlock OKVideo Pro"), subtitle ("No subscription — pay once, yours forever."), and header copy can all be changed directly in the view body.

## Architecture Notes

- `StoreManager` uses `ObservableObject` + `@MainActor` — works on iOS 15+ (StoreKit 2 minimum)
- Entitlements are checked on init and after every purchase/restore
- A background `Task` listens for `Transaction.updates` so purchases made outside the app (promo codes, family sharing, Ask to Buy) are picked up automatically
- `isFullyUnlocked` returns `true` if the user owns the bundle **or** all three individual IAPs — either path counts as "Pro"
- **Smart detents (iOS 16+):** the sheet starts compact (~70% height) and auto-expands to full height when "See individual options" is tapped. Falls back to a plain full-height sheet on iOS 15.
- All presentation APIs (`presentationDetents`, `presentationBackground`, `scrollBounceBehavior`) are gated behind `if #available` so the code compiles on any deployment target that supports StoreKit 2
