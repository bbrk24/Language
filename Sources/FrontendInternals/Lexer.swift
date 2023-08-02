import DequeModule

public enum Lexer {
    public struct Token {
        var startLoc: SourceLocation
        var kind: TokenKind
        var text: Substring

        var endLoc: SourceLocation {
            var line = self.startLoc.line
            var col = self.startLoc.col
            let spanLines = text.split(
                separator: .newlineSequence,
                omittingEmptySubsequences: false
            )
            let numLinesSkipped = UInt(spanLines.count - 1)
            if numLinesSkipped > 0 {
                line += numLinesSkipped
                col = 1
            }
            col += UInt(spanLines.last!.count)
            return .init(file: self.startLoc.file, line: line, col: col)
        }
    }

    struct UnrecognizedToken: Error, CustomStringConvertible {
        var loc: SourceLocation
        var text: String

        var description: String {
            "\(loc): Unrecognized token \"\(text)\""
        }
    }

    public static func lex(source: String, fileName: String) throws -> TokenCollection {
        var line: UInt = 1, col: UInt = 1
        var unlexedSource = source[...]
        var result = TokenCollection()

        while !unlexedSource.isEmpty {
            guard let (match, kind) = TokenKind.allCases.lazy.compactMap({ kind in
                unlexedSource.prefixMatch(of: kind.matcher).map { ($0, kind) }
            }).first else {
                throw UnrecognizedToken(
                    loc: .init(file: fileName, line: line, col: col),
                    text: String(unlexedSource.prefix { !$0.isWhitespace })
                )
            }

            let token = Token(
                startLoc: .init(file: fileName, line: line, col: col),
                kind: kind,
                text: match.output
            )
            let endLoc = token.endLoc
            (line, col) = (endLoc.line, endLoc.col)
            result.append(token)
            unlexedSource = unlexedSource[match.range.upperBound...]
        }

        return result
    }

    public typealias TokenCollection = Deque<Token>
}

extension Lexer.Token: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startLoc = try container.decode(SourceLocation.self, forKey: .startLoc)
        self.kind = try container.decode(Lexer.TokenKind.self, forKey: .kind)
        self.text = try container.decode(String.self, forKey: .text)[...]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startLoc, forKey: .startLoc)
        try container.encode(kind, forKey: .kind)
        try container.encode(String(text), forKey: .text)
    }

    enum CodingKeys: String, CodingKey {
        case startLoc, kind, text
    }
}
