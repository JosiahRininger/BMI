//
//  ShareCardRenderer.swift
//  BMICalculator — Features/Share
//
//  Rasterizes `ShareCardView` to a 1080×1920 PNG entirely on-device. No
//  networking, no backend — the image is generated locally and handed to the
//  system share sheet.
//

import SwiftUI
import UIKit

@MainActor
public enum ShareCardRenderer {

    /// Renders the progress card to a `UIImage` at the full 1080×1920 canvas.
    public static func image(for payload: SharePayload) -> UIImage? {
        let content = ShareCardView(payload: payload)
            .frame(width: ShareCardView.canvas.width, height: ShareCardView.canvas.height)
        let renderer = ImageRenderer(content: content)
        // The view is already sized at 1080×1920 points, so scale 1 → 1080×1920 px.
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(ShareCardView.canvas)
        return renderer.uiImage
    }

    /// Writes the rendered card to a temporary PNG file and returns its URL,
    /// suitable for `ShareLink(item:)` / `UIActivityViewController`.
    public static func temporaryFileURL(for payload: SharePayload) -> URL? {
        guard let image = image(for: payload), let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmi-progress-\(UUID().uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
