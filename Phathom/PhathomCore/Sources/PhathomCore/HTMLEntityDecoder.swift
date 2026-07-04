import Foundation

/// Decodes HTML character references found in scraped text so they do not survive into tag intake.
///
/// Handles numeric decimal (`&#8220;`), numeric hex (`&#x201C;` / `&#X201C;`), and a small set of
/// common named entities (`&amp;`, `&quot;`, `&#39;`, `&nbsp;`, …). Malformed or unknown references
/// are passed through verbatim so legitimate text containing a bare `&` is never corrupted.
public enum HTMLEntityDecoder {
    /// Common named entities seen in scraped article/caption text. Intentionally small — numeric
    /// references cover the long tail.
    private static let namedEntities: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": "\u{00A0}",
        "copy": "\u{00A9}",
        "reg": "\u{00AE}",
        "trade": "\u{2122}",
        "hellip": "\u{2026}",
        "mdash": "\u{2014}",
        "ndash": "\u{2013}",
        "lsquo": "\u{2018}",
        "rsquo": "\u{2019}",
        "ldquo": "\u{201C}",
        "rdquo": "\u{201D}",
    ]

    /// Maximum length of the token between `&` and `;` we will attempt to resolve. Bounds the scan so
    /// a stray `&` in normal prose does not trigger an expensive lookahead.
    private static let maxReferenceBodyLength = 32

    public static func decode(_ input: String) -> String {
        guard input.contains("&") else { return input }

        var output = ""
        output.reserveCapacity(input.count)

        let scalars = Array(input.unicodeScalars)
        var index = 0
        let count = scalars.count

        while index < count {
            let scalar = scalars[index]
            guard scalar == "&" else {
                output.unicodeScalars.append(scalar)
                index += 1
                continue
            }

            // Find the terminating ';' within the bounded window.
            var semicolon = -1
            let limit = min(count, index + 1 + maxReferenceBodyLength + 1)
            var j = index + 1
            while j < limit {
                if scalars[j] == ";" {
                    semicolon = j
                    break
                }
                j += 1
            }

            guard semicolon > index + 1 else {
                output.unicodeScalars.append(scalar)
                index += 1
                continue
            }

            let body = String(String.UnicodeScalarView(scalars[(index + 1)..<semicolon]))
            if let decoded = resolve(body) {
                output.append(decoded)
                index = semicolon + 1
            } else {
                output.unicodeScalars.append(scalar)
                index += 1
            }
        }

        return output
    }

    /// Resolves the text between `&` and `;` (exclusive) to its replacement string, or `nil` if it is
    /// not a recognized reference.
    private static func resolve(_ body: String) -> String? {
        if body.hasPrefix("#") {
            let numberPart = body.dropFirst()
            let codePoint: UInt32?
            if let first = numberPart.first, first == "x" || first == "X" {
                let hexDigits = numberPart.dropFirst()
                guard !hexDigits.isEmpty, hexDigits.allSatisfy(\.isHexDigit) else { return nil }
                codePoint = UInt32(hexDigits, radix: 16)
            } else {
                guard !numberPart.isEmpty, numberPart.allSatisfy(\.isNumber) else { return nil }
                codePoint = UInt32(numberPart, radix: 10)
            }
            guard let value = codePoint, let unicode = Unicode.Scalar(value) else { return nil }
            return String(unicode)
        }

        return namedEntities[body]
    }
}
