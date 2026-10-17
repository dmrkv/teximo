import Cocoa
import Translation
import NaturalLanguage

enum LanguageDownloadAvailability: Equatable {
    case checking, installed, needsDownload, unsupported, sameLanguage, unavailable
    var title: String {
        switch self {
        case .checking: return "Checking language files…"
        case .installed: return "Language files downloaded"
        case .needsDownload: return "Language download needed"
        case .unsupported: return "Language pair not supported"
        case .sameLanguage: return "Choose two different languages"
        case .unavailable: return "Requires macOS 15 or later"
        }
    }
    var symbol: String {
        switch self {
        case .installed: return "checkmark.circle.fill"
        case .needsDownload: return "arrow.down.circle.fill"
        case .checking: return "ellipsis.circle"
        default: return "exclamationmark.triangle"
        }
    }
    @available(macOS 15, *)
    init(_ status: LanguageAvailability.Status) {
        switch status {
        case .installed: self = .installed
        case .supported: self = .needsDownload
        case .unsupported: self = .unsupported
        @unknown default: self = .unsupported
        }
    }
}

struct TranslationDirection: Equatable {
    let source: String
    let target: String
}

enum TranslationLanguages {
    static func matchingIdentifier(_ identifier: String, supported: [String]) -> String? {
        let language = Locale.Language(identifier: identifier)
        if let match = supported.first(where: { Locale.Language(identifier: $0).minimalIdentifier == language.minimalIdentifier }) { return match }
        return supported.first { Locale.Language(identifier: $0).languageCode == language.languageCode }
    }
    static func suggestedSource(target: String, supported: [String], preferred: [String]) -> String {
        for preferred in preferred + ["en"] {
            if let match = matchingIdentifier(preferred, supported: supported), match != target { return match }
        }
        return supported.first { $0 != target } ?? ""
    }
    static func detectedSource(in text: String, supported: [String]) -> String? {
        guard let detected = NLLanguageRecognizer.dominantLanguage(for: text) else { return nil }
        return matchingIdentifier(detected.rawValue, supported: supported)
    }
    static func direction(first: String, second: String, detected: String?) -> TranslationDirection {
        let detected = detected.flatMap { matchingIdentifier($0, supported: [first, second]) }
        if detected == second { return TranslationDirection(source: second, target: first) }
        return TranslationDirection(source: first, target: second)
    }
    static func direction(for text: String, first: String, second: String) -> TranslationDirection {
        direction(first: first, second: second, detected: detectedSource(in: text, supported: [first, second]))
    }
    @available(macOS 15, *)
    static func supportedIdentifiers() async -> [String] {
        await LanguageAvailability().supportedLanguages.map { $0.minimalIdentifier }
    }
    @available(macOS 15, *)
    static func availability(source: String, target: String) async -> LanguageDownloadAvailability {
        guard Locale.Language(identifier: source).minimalIdentifier != Locale.Language(identifier: target).minimalIdentifier else { return .sameLanguage }
        return LanguageDownloadAvailability(await LanguageAvailability().status(from: Locale.Language(identifier: source), to: Locale.Language(identifier: target)))
    }
    static func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!)
    }
}
