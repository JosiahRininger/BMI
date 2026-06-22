//
//  HistoryExporter.swift
//  BMICalculator — Features/History
//
//  Local-first export of saved BMI history to CSV and PDF. A Pro feature
//  (gated by `StoreState.isPro` at the call site). Everything is generated
//  on-device into a temporary file; nothing leaves the device until the
//  person shares it via the system share sheet.
//

import Foundation
import UIKit

enum HistoryExporter {

    // MARK: - CSV

    /// Writes the records to a temporary CSV file and returns its URL.
    static func csvFileURL(records: [BMIRecord], standard: HealthStandard) -> URL? {
        let iso = ISO8601DateFormatter()
        var lines = ["Date,BMI,Category,Weight (kg),Height (m)"]
        for record in records.sorted(by: { $0.date < $1.date }) {
            let category = record.category(standard: standard).title
            lines.append([
                iso.string(from: record.date),
                String(format: "%.1f", record.roundedBMI),
                "\"\(category)\"",
                String(format: "%.1f", record.weightKilograms),
                String(format: "%.3f", record.heightMeters)
            ].joined(separator: ","))
        }
        return write(lines.joined(separator: "\n"), fileName: "BMI-History.csv")
    }

    // MARK: - PDF

    /// Renders a simple, paginated PDF table of the history and returns its URL.
    static func pdfFileURL(records: [BMIRecord], standard: HealthStandard) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter @ 72dpi
        let margin: CGFloat = 48
        let url = temporaryURL(fileName: "BMI-History.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let title: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 24)]
        let header: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12)]
        let row: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
        let footer: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 9),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let disclaimer = "BMI is a screening tool, not a diagnosis. Talk to a healthcare provider."

        do {
            try renderer.writePDF(to: url) { ctx in
                let sorted = records.sorted(by: { $0.date < $1.date })
                var index = 0

                func startPage() {
                    ctx.beginPage()
                    "BMI History".draw(at: CGPoint(x: margin, y: margin), withAttributes: title)
                    String(format: "%-22@%-10@%@", "Date" as NSString, "BMI" as NSString, "Category" as NSString)
                        .draw(at: CGPoint(x: margin, y: margin + 40), withAttributes: header)
                    disclaimer.draw(at: CGPoint(x: margin, y: pageRect.height - margin),
                                    withAttributes: footer)
                }

                startPage()
                var y = margin + 64
                if sorted.isEmpty {
                    "No measurements saved yet.".draw(at: CGPoint(x: margin, y: y), withAttributes: row)
                }
                while index < sorted.count {
                    if y > pageRect.height - margin - 24 {
                        startPage()
                        y = margin + 64
                    }
                    let r = sorted[index]
                    let line = String(format: "%-22@%-10.1f%@",
                                      dateFormatter.string(from: r.date) as NSString,
                                      r.roundedBMI,
                                      r.category(standard: standard).title as NSString)
                    line.draw(at: CGPoint(x: margin, y: y), withAttributes: row)
                    y += 18
                    index += 1
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func temporaryURL(fileName: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    private static func write(_ string: String, fileName: String) -> URL? {
        let url = temporaryURL(fileName: fileName)
        do {
            try string.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
