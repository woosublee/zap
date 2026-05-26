import Foundation

extension Dictionary where Key == String, Value == Any {
    func trimmedString(for key: String) -> String? {
        guard let value = self[key] as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
