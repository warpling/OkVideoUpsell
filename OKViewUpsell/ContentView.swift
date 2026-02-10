//
//  ContentView.swift
//  OKViewUpsell
//
//  Demo harness showing how to present the OKVideo Pro upsell sheet.
//
//  TODO: In the real app, present the sheet when a user hits a locked
//  feature gate (e.g. project limit, watermark export, editor access).
//

import SwiftUI

struct ContentView: View {

    @State private var showUpsell = false
    @StateObject private var storeManager = StoreManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // TODO: Replace with your app icon
                Image(systemName: "video.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(red: 1.0, green: 0.26, blue: 0.40))

                Text("OKVideo")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Button {
                    showUpsell = true
                } label: {
                    Label("Show Pro Upsell", systemImage: "lock.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Color(red: 1.0, green: 0.26, blue: 0.40),
                            in: Capsule()
                        )
                }
            }
        }
        .sheet(isPresented: $showUpsell) {
            // Sheet presentation (detents, background, drag indicator)
            // is handled inside OKVideoProUpsellView itself.
            OKVideoProUpsellView(storeManager: storeManager)
        }
    }
}

#Preview {
    ContentView()
}
