import Foundation

enum CaseToggle {
    static func transform(_ input: String) -> String {
        guard !input.isEmpty else { return input }
        let hasLetters = input.rangeOfCharacter(from: .letters) != nil
        guard hasLetters else { return input }

        // Detect current case style
        let isAllUpper = input == input.uppercased()
        let isAllLower = input == input.lowercased()
        let isTitleCase = input == titleCase(input)
        
        // Cycle through: lowercase → UPPERCASE → Title Case → lowercase
        if isAllLower {
            return input.uppercased()
        } else if isAllUpper {
            return titleCase(input.lowercased())
        } else {
            // Mixed case or title case - go to lowercase
            return input.lowercased()
        }
    }

    private static func titleCase(_ text: String) -> String {
        // Capitalize first letter of each word
        return text.split(separator: " ").map { word in
            guard let first = word.first else { return String(word) }
            return String(first).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}
