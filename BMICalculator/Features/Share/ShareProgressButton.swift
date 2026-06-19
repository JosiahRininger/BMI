//
//  ShareProgressButton.swift
//  BMICalculator — Features/Share
//
//  Opt-in entry point for sharing a progress card. Drop it into History or the
//  result screen. The "Include my BMI number" toggle defaults OFF — the shared
//  artifact is progress-framed unless the user deliberately adds the number.
//

import SwiftUI

public struct ShareProgressButton: View {

    private let basePayload: SharePayload
    @State private var includeNumber = false
    @State private var showSheet = false

    public init(payload: SharePayload) { self.basePayload = payload }

    private var payload: SharePayload {
        var p = basePayload
        p.includeNumber = includeNumber
        return p
    }

    public var body: some View {
        Button {
            showSheet = true
        } label: {
            Label("Share my progress", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.primaryGlass)
        .accessibilityLabel("Share my progress")
        .accessibilityHint("Opens a sheet to preview and share a progress card")
        .sheet(isPresented: $showSheet) {
            ShareProgressSheet(basePayload: basePayload, includeNumber: $includeNumber)
        }
    }
}

/// Preview + opt-in toggle + the actual `ShareLink`.
private struct ShareProgressSheet: View {
    let basePayload: SharePayload
    @Binding var includeNumber: Bool
    @Environment(\.dismiss) private var dismiss

    private var payload: SharePayload {
        var p = basePayload
        p.includeNumber = includeNumber
        return p
    }

    // Rasterizing the 1080×1920 card is expensive, so cache it and regenerate
    // ONLY when the payload changes (via `.task(id:)`) — never in `body`.
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Live preview of the exact card that will be shared. The card
                    // itself is a fixed 1080×1920 render canvas; here we only scale
                    // the on-screen PREVIEW to fit the available width on any device
                    // (SE → Pro Max → iPad), preserving its aspect ratio. Never alter
                    // ShareCardView's canvas — only this preview's display size.
                    cardPreview

                    Toggle("Include my BMI number", isOn: $includeNumber)
                        .tint(Theme.brand)
                        .padding(.horizontal)
                        .accessibilityHint("When on, your card shows your current BMI number and category. Off by default.")

                    Text("By default your card shows your streak and trend shape, never an absolute BMI or weight. Your data stays on your device.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let image = renderedImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("My BMI progress", image: Image(uiImage: image))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.primaryGlass)
                        .padding(.horizontal)
                        .accessibilityLabel("Share progress card")
                    } else {
                        ProgressView()
                            .padding()
                            .accessibilityLabel("Preparing your card")
                    }
                }
                .padding(.vertical, 24)
                // Constrain primary content on iPad / large widths so it isn't
                // stretched edge-to-edge.
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Share progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        // Re-render the shareable image only when the payload changes (e.g. the
        // "include my number" toggle), not on every view update.
        .task(id: payload) {
            renderedImage = ShareCardRenderer.image(for: payload)
        }
    }

    /// On-screen preview of the fixed render canvas, scaled to fit the available
    /// width while preserving the 1080×1920 aspect ratio. The card content itself
    /// is never restructured — only the display size adapts.
    private var cardPreview: some View {
        // Aspect ratio of the fixed canvas; reused to reserve vertical space.
        let aspect = ShareCardView.canvas.width / ShareCardView.canvas.height
        return GeometryReader { proxy in
            let targetWidth = proxy.size.width
            let scale = targetWidth / ShareCardView.canvas.width
            ShareCardView(payload: payload)
                .frame(width: ShareCardView.canvas.width, height: ShareCardView.canvas.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: targetWidth, height: ShareCardView.canvas.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(radius: 12, y: 6)
        }
        // Reserve the correct height so the GeometryReader doesn't collapse and
        // the ScrollView lays the preview out at its true scaled size. Capped so
        // it never dominates the sheet on tall/iPad layouts.
        .aspectRatio(aspect, contentMode: .fit)
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of your shareable progress card")
    }
}
