//
//  LocalizationFormattingTests.swift
//  BMICalculatorTests
//
//  Decimal-comma input and locale-aware number display for the first UI
//  localizations (Spanish, Brazilian Portuguese, French). Each test pins its
//  locale, so results don't depend on the simulator's language or region.
//

import Testing
import Foundation
@testable import BMICalculator

private let enUS = Locale(identifier: "en_US")
private let esES = Locale(identifier: "es_ES")
private let esMX = Locale(identifier: "es_MX")
private let ptBR = Locale(identifier: "pt_BR")
private let frFR = Locale(identifier: "fr_FR")

@Suite("Weight input parsing")
struct WeightInputParsingTests {

    private func parse(_ text: String, _ locale: Locale) throws -> Double {
        try WeightField.inputFormat.locale(locale).parseStrategy.parse(text)
    }

    @Test("A decimal comma parses in Spanish (Spain), Portuguese (Brazil), and French",
          arguments: [esES, ptBR, frFR])
    func decimalComma(locale: Locale) throws {
        #expect(try parse("72,5", locale) == 72.5)
        #expect(try parse("154", locale) == 154)
    }

    @Test("A decimal point parses where the region uses one (US English, Mexican Spanish)",
          arguments: [enUS, esMX])
    func decimalPoint(locale: Locale) throws {
        #expect(try parse("72.5", locale) == 72.5)
        #expect(try parse("154", locale) == 154)
    }

    @Test("The field shows the locale's separator, so what it shows parses back")
    func roundTrip() throws {
        for locale in [enUS, esES, esMX, ptBR, frFR] {
            let shown = 72.5.formatted(WeightField.inputFormat.locale(locale))
            #expect(try parse(shown, locale) == 72.5, "\(locale.identifier): \(shown)")
        }
        #expect(72.5.formatted(WeightField.inputFormat.locale(esES)) == "72,5")
        #expect(72.5.formatted(WeightField.inputFormat.locale(enUS)) == "72.5")
    }
}

@Suite("Locale-aware number display")
struct DisplayNumberTests {

    @Test("One-decimal values use the locale's decimal separator")
    func decimal() {
        #expect(DisplayNumber.decimal(22.5, locale: enUS) == "22.5")
        #expect(DisplayNumber.decimal(22.5, locale: esES) == "22,5")
        #expect(DisplayNumber.decimal(22.5, locale: esMX) == "22.5")
        #expect(DisplayNumber.decimal(22.5, locale: ptBR) == "22,5")
        #expect(DisplayNumber.decimal(22.5, locale: frFR) == "22,5")
        #expect(DisplayNumber.decimal(22, locale: frFR) == "22,0")
        #expect(DisplayNumber.decimal(175.4, places: 0, locale: ptBR) == "175")
    }

    @Test("No grouping separator, even for large values")
    func noGrouping() {
        #expect(DisplayNumber.decimal(1234.5, locale: enUS) == "1234.5")
        #expect(DisplayNumber.decimal(1234.5, locale: esES) == "1234,5")
    }

    @Test("Signed changes keep their sign and never show +0.0 or -0.0")
    func signed() {
        #expect(DisplayNumber.signedDecimal(0.44, locale: enUS) == "+0.4")
        #expect(DisplayNumber.signedDecimal(-1.44, locale: enUS) == "-1.4")
        #expect(DisplayNumber.signedDecimal(0.44, locale: ptBR) == "+0,4")
        #expect(DisplayNumber.signedDecimal(0.04, locale: esES) == "0,0")
        #expect(DisplayNumber.signedDecimal(-0.04, locale: enUS) == "0.0")
        let negative = DisplayNumber.signedDecimal(-1.44, locale: frFR)
        #expect(negative.hasSuffix("1,4"))
        #expect(negative.count == 4)   // a single minus sign, whichever glyph
    }

    @Test("Category ranges use the locale's decimal separator")
    func categoryRanges() {
        #expect(BMICategory.healthy.displayRange(locale: enUS) == "18.5 – < 25")
        #expect(BMICategory.healthy.displayRange(locale: frFR) == "18,5 – < 25")
        #expect(BMICategory.underweight.displayRange(locale: esES) == "< 18,5")
        #expect(BMICategory.obesityIII.displayRange(locale: ptBR) == "≥ 40")
    }

    @Test("The CSV keeps English category names in every language")
    func csvStaysEnglish() {
        #expect(BMICategory.healthy.englishTitle == "Healthy weight")
        #expect(BMICategory.obesityI.englishTitle == "Obesity (class 1)")
        let csv = HistoryCSV.make(
            entries: [ExportEntry(date: Date(timeIntervalSince1970: 1_790_000_000), bmi: 22.86,
                                  weightKilograms: 70, heightMeters: 1.75)],
            standard: .standard,
            timeZone: TimeZone(identifier: "UTC")!
        )
        #expect(csv.contains("\"Healthy weight\""))
        #expect(csv.contains("\"22.9\""))
    }
}

/// The English plural variants live in Localizable.xcstrings (the source code
/// has one key per sentence), so these check the compiled catalog the app
/// ships. They read the host app's bundle, so they only run in English.
@Suite("English plural variants",
       .enabled(if: Bundle.main.preferredLocalizations.first == "en"))
struct EnglishPluralTests {

    @Test("Entry counts on the doctor summary")
    func entries() {
        #expect(String(localized: "\(1) entries, shown in metric units.") == "1 entry, shown in metric units.")
        #expect(String(localized: "\(3) entries, shown in stone units.") == "3 entries, shown in stone units.")
    }

    @Test("A plural argument after other arguments")
    func measurements() {
        let first = "22.0", last = "23.0"
        #expect(String(localized: "BMI increasing from \(first) to \(last) over \(1) measurements.")
                == "BMI increasing from 22.0 to 23.0 over 1 measurement.")
        #expect(String(localized: "BMI steady from \(first) to \(first) over \(4) measurements.")
                == "BMI steady from 22.0 to 22.0 over 4 measurements.")
    }

    @Test("Feet and pages")
    func feetAndPages() {
        let inches = "7 in"
        #expect(String(localized: "\(1) feet \(inches)") == "1 foot 7 in")
        #expect(String(localized: "\(5) feet \(inches)") == "5 feet 7 in")
        #expect(String(localized: "Plus \(1) more pages in the full summary.") == "Plus 1 more page in the full summary.")
    }
}
