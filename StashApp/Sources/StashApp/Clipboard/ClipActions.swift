import Foundation

enum TextTransform: String, CaseIterable {
    case upper = "UPPERCASE"
    case lower = "lowercase"
    case title = "Title Case"
    case trim = "Trim Whitespace"
    case jsonPretty = "Pretty-Print JSON"
    case base64Encode = "Base64 Encode"
    case base64Decode = "Base64 Decode"
    case urlEncode = "URL Encode"
    case urlDecode = "URL Decode"

    func apply(_ s: String) -> String? {
        switch self {
        case .upper:
            return s.uppercased()
        case .lower:
            return s.lowercased()
        case .title:
            return s.capitalized
        case .trim:
            return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .jsonPretty:
            guard let data = s.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                  let result = String(data: pretty, encoding: .utf8)
            else { return nil }
            return result
        case .base64Encode:
            return Data(s.utf8).base64EncodedString()
        case .base64Decode:
            guard let data = Data(base64Encoded: s),
                  let result = String(data: data, encoding: .utf8)
            else { return nil }
            return result
        case .urlEncode:
            guard let result = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            else { return nil }
            return result
        case .urlDecode:
            guard let result = s.removingPercentEncoding
            else { return nil }
            return result
        }
    }
}
