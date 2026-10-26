//
//  DoctorSummaryView.swift
//  BMICalculator — Features/History
//
//  The doctor summary (a Pro feature): pick a date range, see the pages, then
//  share or print the PDF. Without Pro the same preview is shown (the value is
//  shown, not claimed) with a calm Pro card instead of the share button. The
//  preview is page images, so it can't be lifted out as a file.
//

import SwiftUI
import PDFKit

struct DoctorSummaryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(StoreState.self) private var store

    /// A snapshot of the saved entries (plain values).
    let entries: [ExportEntry]
    let unitSystem: UnitSystem
    let standard: HealthStandard

    @State private var range: SummaryRange = .quarter
    @State private var customStart: Date
    @State private var customEnd: Date
    @State private var pageImages: [UIImage] = []
    @State private var totalPages = 0
    @State private var isRendering = false
    @State private var showsPro = false

    init(entries: [ExportEntry], unitSystem: UnitSystem, standard: HealthStandard) {
        self.entries = entries
        self.unitSystem = unitSystem
        self.standard = standard
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -89, to: Calendar.current.startOfDay(for: now)) ?? now
        _customStart = State(initialValue: start)
        _customEnd = State(initialValue: now)
    }

    private var summary: DoctorSummary {
        let custom = DateInterval(
            start: Calendar.current.startOfDay(for: min(customStart, customEnd)),
            end: Calendar.current.date(byAdding: .day, value: 1,
                                       to: Calendar.current.startOfDay(for: max(customStart, customEnd))) ?? customEnd
        )
        let interval = range.interval(now: .now, entries: entries, custom: custom)
        return DoctorSummary(allEntries: entries, interval: interval, unitSystem: unitSystem, standard: standard)
    }

    /// Re-render whenever the inputs change.
    private var renderKey: String {
        "\(range.rawValue)|\(customStart.timeIntervalSince1970)|\(customEnd.timeIntervalSince1970)|\(store.hasPro)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    rangeControls
                    preview
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if !store.hasPro {
                    lockedCard
                }
            }
            .navigationTitle("Doctor summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let export = DoctorSummaryPDF.shareable(summary, hasPro: store.hasPro) {
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: export,
                                  preview: SharePreview(DoctorSummary.title, image: Image(systemName: "doc.text"))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task(id: renderKey) { await renderPreview() }
            .sheet(isPresented: $showsPro) {
                ProSheet()
            }
        }
    }

    // MARK: Controls

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose the dates to include, for example since your last appointment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Dates", selection: $range) {
                ForEach(SummaryRange.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            if range == .custom {
                DatePicker("From", selection: $customStart, in: ...Date(), displayedComponents: .date)
                DatePicker("To", selection: $customEnd, in: ...Date(), displayedComponents: .date)
            }
            Text(summary.isEmpty
                 ? "No entries in these dates."
                 : "\(summary.entries.count) \(summary.entries.count == 1 ? "entry" : "entries"), shown in \(unitSystem.displayName.lowercased()) units.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Preview

    @ViewBuilder
    private var preview: some View {
        if isRendering && pageImages.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            VStack(spacing: 14) {
                ForEach(pageImages.indices, id: \.self) { index in
                    Image(uiImage: pageImages[index])
                        .resizable()
                        .aspectRatio(DoctorSummaryPDF.pageSize, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                        .accessibilityLabel("Summary page \(index + 1) of \(totalPages)")
                }
                if totalPages > pageImages.count {
                    let more = totalPages - pageImages.count
                    Text("Plus \(more) more \(more == 1 ? "page" : "pages") in the full summary.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Locked state

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Here is a preview of your summary. With Pro you can save it or share it with your doctor or care team.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button {
                    showsPro = true
                } label: {
                    Text("See Pro")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
                Button("Not now") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // MARK: Rendering

    /// Pages shown in the preview. The rest are counted, not drawn.
    static let previewPageLimit = 3

    @MainActor
    private func renderPreview() async {
        isRendering = true
        defer { isRendering = false }
        // Debounce later changes (picking custom dates restarts this task); the
        // first preview draws right away.
        if !pageImages.isEmpty {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
        }
        await Task.yield()   // let the spinner draw before the synchronous render
        let summary = self.summary
        totalPages = DoctorSummaryLayout.pages(rowCount: summary.entries.count).count
        let data = DoctorSummaryPDF.render(summary, pageLimit: Self.previewPageLimit)
        guard let document = PDFDocument(data: data) else {
            pageImages = []
            return
        }
        var images: [UIImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            // Sharp at the screen's scale: the preview is at most ~600pt wide.
            let scale = min(max(displayScale, 1), 3)
            images.append(page.thumbnail(of: CGSize(width: 612 * scale, height: 792 * scale), for: .mediaBox))
        }
        pageImages = images
    }
}
