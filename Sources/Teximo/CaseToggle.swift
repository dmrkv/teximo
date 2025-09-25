import Foundation

enum CaseToggle {
	static func transform(_ input: String) -> String {
		guard !input.isEmpty else { return input }
		let hasLetters = input.rangeOfCharacter(from: .letters) != nil
		guard hasLetters else { return input }

		let isAllUpper = input == input.uppercased()
		let isAllLower = input == input.lowercased()

		if isAllUpper {
			return input.lowercased()
		} else if isAllLower {
			return capitalizeFirst(input)
		} else {
			return capitalizeFirst(input.lowercased())
		}
	}

	private static func capitalizeFirst(_ s: String) -> String {
		guard let first = s.first else { return s }
		return String(first).uppercased() + s.dropFirst()
	}
}

