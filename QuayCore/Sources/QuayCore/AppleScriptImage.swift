import Foundation

public enum AppleScriptImage {
    /// Decodes an `osascript` picture result such as `«data JPEGFFD8…»`.
    public static func decode(_ output: String) -> Data? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "missing value" { return nil }
        guard let start = trimmed.range(of: "«data ") else { return nil }
        var body = trimmed[start.upperBound...]
        if let end = body.range(of: "»") {
            body = body[..<end.lowerBound]
        }
        let compact = body.filter { !$0.isWhitespace }
        guard compact.count > 4 else { return nil }
        let hex = compact.dropFirst(4)
        guard hex.count.isMultiple(of: 2), !hex.isEmpty else { return nil }
        var data = Data()
        data.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}
