import Foundation

enum Transliterator {
	// Minimal mapping for en<->ru based on standard layout; can be extended for Ilya Birman
	private static let enToRu: [Character: Character] = [
		"q":"й","w":"ц","e":"у","r":"к","t":"е","y":"н","u":"г","i":"ш","o":"щ","p":"з",
		"[":"х","]":"ъ","a":"ф","s":"ы","d":"в","f":"а","g":"п","h":"р","j":"о","k":"л",
		"l":"д",";":"ж","'":"э","z":"я","x":"ч","c":"с","v":"м","b":"и","n":"т","m":"ь",
		",":"б",".":"ю","/":"."
	]

	private static let ruToEn: [Character: Character] = {
		var map: [Character: Character] = [:]
		for (k, v) in enToRu { map[v] = k }
		return map
	}()

	static func transliterate(_ input: String) -> String {
		let latinCount = input.unicodeScalars.filter { $0.value < 128 && CharacterSet.letters.contains($0) }.count
		let cyrillicRange = 0x0400...0x04FF
		let cyrCount = input.unicodeScalars.filter { cyrillicRange.contains(Int($0.value)) }.count
		let toRu = latinCount >= cyrCount
		let mapping = toRu ? enToRu : ruToEn
		return String(input.map { ch in
			if let mapped = mapping[Character(String(ch).lowercased())] {
				let isUpper = String(ch).uppercased() == String(ch) && String(ch).lowercased() != String(ch)
				return isUpper ? Character(String(mapped).uppercased()) : mapped
			} else {
				return ch
			}
		})
	}
}


