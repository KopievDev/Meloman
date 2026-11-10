import Foundation
import MelomanDomain

/// Editable OFFLINE draft, not a dictionary-quality phonetic transcription.
/// English orthography is irregular: manual corrections remain essential.
public enum EnglishToRussianPronunciation {
    private static let common: [String: String] = [
        "a": "э", "about": "эбаут", "all": "ол", "am": "эм", "and": "энд",
        "are": "ар", "at": "эт", "away": "эвэй", "back": "бэк", "be": "би",
        "been": "бин", "but": "бат", "by": "бай", "can": "кэн", "come": "кам",
        "could": "куд", "day": "дэй", "do": "ду", "don't": "доунт",
        "down": "даун", "dream": "дрим", "feel": "фил", "for": "фор",
        "from": "фром", "get": "гет", "give": "гив", "go": "гоу",
        "good": "гуд", "got": "гот", "had": "хад", "have": "хэв",
        "he": "хи", "heart": "харт", "here": "хиэр", "his": "хиз",
        "how": "хау", "i": "ай", "if": "иф", "in": "ин", "into": "инту",
        "is": "из", "it": "ит", "just": "джаст", "know": "ноу",
        "life": "лайф", "like": "лайк", "little": "литл", "look": "лук",
        "lose": "луз", "love": "лав", "make": "мэйк", "me": "ми",
        "more": "мор", "my": "май", "never": "нэвер", "no": "ноу",
        "not": "нот", "now": "нау", "of": "ов", "on": "он", "one": "уан",
        "only": "оунли", "opportunity": "оппортюнити", "or": "ор",
        "our": "ауэр", "out": "аут", "over": "оувер", "say": "сэй",
        "see": "си", "she": "ши", "shot": "шот", "so": "соу",
        "some": "сам", "take": "тэйк", "tell": "тел", "that": "зэт",
        "the": "зэ", "their": "зэир", "them": "зэм", "there": "зэа",
        "these": "зиз", "they": "зэй", "this": "зис", "time": "тайм",
        "to": "ту", "today": "тудэй", "too": "ту", "try": "трай",
        "up": "ап", "us": "ас", "want": "вонт", "was": "воз",
        "way": "вэй", "we": "ви", "were": "вёр", "what": "вот",
        "when": "вэн", "where": "вэа", "who": "ху", "will": "вил",
        "with": "виз", "world": "вёрлд", "would": "вуд", "yeah": "йе",
        "yes": "йес", "you": "ю", "your": "йор", "yourself": "йорселф",
    ]

    private static let groups: [(String, String)] = [
        ("tion", "шн"), ("sion", "жн"), ("ough", "о"), ("igh", "ай"),
        ("sh", "ш"), ("ch", "ч"), ("th", "з"), ("ph", "ф"),
        ("ee", "и"), ("oo", "у"), ("ea", "и"), ("ou", "ау"),
        ("ow", "ау"), ("ai", "эй"), ("ay", "эй"), ("ck", "к"),
        ("ng", "нг"), ("qu", "кв"), ("wh", "в"),
    ]
    private static let letters: [Character: String] = [
        "a": "а", "b": "б", "c": "к", "d": "д", "e": "е", "f": "ф",
        "g": "г", "h": "х", "i": "и", "j": "дж", "k": "к", "l": "л",
        "m": "м", "n": "н", "o": "о", "p": "п", "q": "к", "r": "р",
        "s": "с", "t": "т", "u": "у", "v": "в", "w": "в", "x": "кс",
        "y": "й", "z": "з",
    ]

    public static func draft(_ text: String) -> String {
        let chars = Array(text)
        let first = chars.prefix(while: { !$0.isLetter && !$0.isNumber })
        let last = chars.reversed().prefix(while: { !$0.isLetter && !$0.isNumber }).reversed()
        let core = String(chars.dropFirst(first.count).dropLast(last.count))
        guard !core.isEmpty else { return text }
        let lower = core.lowercased()
        let phonetic = common[lower] ?? fallback(lower)
        let formatted = core.first?.isUppercase == true ? phonetic.capitalized : phonetic
        return String(first) + formatted + String(last)
    }

    public static func fillMissing(
        track: KaraokePronunciationTrack,
        lines: [LyricLine]
    ) -> KaraokePronunciationTrack {
        var result = track
        for word in lines.flatMap(\.words) where track.text(for: word.id) == nil {
            result.setText(draft(word.text), for: word.id)
        }
        return result
    }

    private static func fallback(_ word: String) -> String {
        var remaining = word
        var output = ""
        while !remaining.isEmpty {
            if let match = groups.first(where: { remaining.hasPrefix($0.0) }) {
                output += match.1
                remaining.removeFirst(match.0.count)
            } else {
                let char = remaining.removeFirst()
                output += letters[char] ?? String(char)
            }
        }
        return output
    }
}
