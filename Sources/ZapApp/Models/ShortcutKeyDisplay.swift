import Carbon
import Foundation

enum ShortcutKeyDisplay {
    static func displayName(forKeyCode keyCode: UInt32, fallback: String? = nil) -> String {
        let useKorean = isKoreanInputSourceActive()
        return switch keyCode {
        case 0: useKorean ? "ㅁ" : "A"
        case 1: useKorean ? "ㄴ" : "S"
        case 2: useKorean ? "ㅇ" : "D"
        case 3: useKorean ? "ㄹ" : "F"
        case 4: useKorean ? "ㅗ" : "H"
        case 5: useKorean ? "ㅎ" : "G"
        case 6: useKorean ? "ㅋ" : "Z"
        case 7: useKorean ? "ㅌ" : "X"
        case 8: useKorean ? "ㅊ" : "C"
        case 9: useKorean ? "ㅍ" : "V"
        case 11: useKorean ? "ㅠ" : "B"
        case 12: useKorean ? "ㅂ" : "Q"
        case 13: useKorean ? "ㅈ" : "W"
        case 14: useKorean ? "ㄷ" : "E"
        case 15: useKorean ? "ㄱ" : "R"
        case 16: useKorean ? "ㅛ" : "Y"
        case 17: useKorean ? "ㅅ" : "T"
        case 18: "1"
        case 19: "2"
        case 20: "3"
        case 21: "4"
        case 22: "6"
        case 23: "5"
        case 24: "="
        case 25: "9"
        case 26: "7"
        case 27: "-"
        case 28: "8"
        case 29: "0"
        case 30: "]"
        case 31: useKorean ? "ㅐ" : "O"
        case 32: useKorean ? "ㅕ" : "U"
        case 33: "["
        case 34: useKorean ? "ㅑ" : "I"
        case 35: useKorean ? "ㅔ" : "P"
        case 36: "Return"
        case 37: useKorean ? "ㅣ" : "L"
        case 38: useKorean ? "ㅓ" : "J"
        case 39: "'"
        case 40: useKorean ? "ㅏ" : "K"
        case 41: ";"
        case 42: "\\"
        case 43: ","
        case 44: "/"
        case 45: useKorean ? "ㅜ" : "N"
        case 46: useKorean ? "ㅡ" : "M"
        case 47: "."
        case 48: "Tab"
        case 49: "Space"
        case 50, 93: useKorean ? "₩" : "`"
        case 51: "Delete"
        case 53: "Esc"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default:
            if let fallback, !fallback.isEmpty {
                fallback.uppercased()
            } else {
                "#\(keyCode)"
            }
        }
    }

    private static func isKoreanInputSourceActive() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let sourceID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return false
        }
        let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
        return id.localizedCaseInsensitiveContains("korean")
            || id.localizedCaseInsensitiveContains("hangul")
            || id.contains("2SetKorean")
    }
}
