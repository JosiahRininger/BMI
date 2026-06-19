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

    private var renderedImage: UIImage? { ShareCardRenderer.image(for: payload) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Live, scaled-down preview of the exact card that will be shared.
                    ShareCardView(payload: payload)
                        .frame(width: ShareCardView.canvas.width, height: ShareCardView.canvas.height)
                        .scaleEffect(0.28)
                        .frame(width: ShareCardView.canvas.width * 0.28,
                               height: ShareCardView.canvas.height * 0.28)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(radius: 12, y: 6)

                    Toggle("Include my BMI number", isOn: $includeNumber)
                        .tint(Theme.brand)
                        .padding(.horizontal)

                    Text("By default your card shows your streak and trend shape — never an absolute BMI or weight. Your data stays on your device.")
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
                    }
                }
                .padding(.vertical, 24)
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
    }
}
