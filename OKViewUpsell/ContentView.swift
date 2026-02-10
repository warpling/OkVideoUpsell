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

    @State private var showSwiftUIUpsell = false
    @State private var showUIKitUpsell = false
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
                    showSwiftUIUpsell = true
                } label: {
                    Label("SwiftUI Upsell", systemImage: "swift")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Color(red: 1.0, green: 0.26, blue: 0.40),
                            in: Capsule()
                        )
                }

                Button {
                    showUIKitUpsell = true
                } label: {
                    Label("UIKit Upsell", systemImage: "hammer.fill")
                        .font(.headline)
                        .foregroundStyle(Color(red: 1.0, green: 0.26, blue: 0.40))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Color(red: 1.0, green: 0.26, blue: 0.40).opacity(0.15),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(Color(red: 1.0, green: 0.26, blue: 0.40), lineWidth: 1.5))
                }
            }
        }
        .sheet(isPresented: $showSwiftUIUpsell) {
            OKVideoProUpsellView(storeManager: storeManager)
        }
        .background(
            UIKitUpsellPresenter(isPresented: $showUIKitUpsell, storeManager: storeManager)
        )
    }
}

#Preview {
    ContentView()
}
