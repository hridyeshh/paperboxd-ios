  import Foundation

extension String {
    /// Google Books / Open Library descriptions arrive as HTML fragments
    /// (`<p>`, `<br>`, `<b>`, `&quot;`, …). Strip tags and decode the common
    /// entities so the text renders cleanly as plain SwiftUI `Text`.
    var strippingHTML: String {
        // Turn block/line breaks into newlines before dropping the rest of the tags.
        var s = replacingOccurrences(
            of: "<br\\s*/?>|</p>|</div>|</li>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
            "&rsquo;": "\u{2019}", "&lsquo;": "\u{2018}",
            "&rdquo;": "\u{201D}", "&ldquo;": "\u{201C}",
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.decodingNumericEntities()

        // Collapse the runs of blank lines the tag removal can leave behind.
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Replaces `&#160;`-style numeric character references with their scalar.
    private func decodingNumericEntities() -> String {
        guard let re = try? NSRegularExpression(pattern: "&#(\\d+);") else { return self }
        var result = self
        let matches = re.matches(in: self, range: NSRange(startIndex..., in: self)).reversed()
        for m in matches {
            guard let full = Range(m.range, in: result),
                  let numRange = Range(m.range(at: 1), in: result),
                  let code = UInt32(result[numRange]),
                  let scalar = Unicode.Scalar(code) else { continue }
            result.replaceSubrange(full, with: String(scalar))
        }
        return result
    }
}
