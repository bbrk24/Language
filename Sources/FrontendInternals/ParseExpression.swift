import Algorithms

extension SyntaxTree {
    private static func withoutTrivia(_ tokens: [Lexer.Token]) -> some BidirectionalCollection<Lexer.Token> {
        tokens.lazy
            .filter {
                $0.kind != .blockComment && $0.kind != .lineComment && $0.kind != .whitespace
            }
    }

    static func parseCommaSeparatedIdentifiers(_ tokens: [Lexer.Token]) throws -> [String] {
        try withoutTrivia(tokens)
            .chunks(ofCount: 2)
            .map {
                if $0.first!.kind != .identifier {
                    throw UnexpectedToken(found: $0.first!, expected: [.identifier])
                }
                if $0.count > 1 && $0.last!.kind != .comma {
                    throw UnexpectedToken(found: $0.last!, expected: [.comma])
                }
                return String($0.first!.text)
            }
    }

    enum PairType {
        case paren, bracket
    }

    struct UnexpectedEndOfList: Error, CustomStringConvertible {
        var location: SourceLocation

        var description: String {
            "\(location): Unexpected end of argument list"
        }
    }

    static func parseArgumentList(_ tokens: [Lexer.Token]) throws -> [_NameAndType] {
        guard let lastToken = tokens.last else {
            return []
        }

        var pairs = Array<(String, Expression)>()

        var name: String? = nil
        var seenColon = false
        var bracketStack = Array<PairType>()
        var currentExpression = Array<Lexer.Token>()

        for token in withoutTrivia(tokens) {
            guard let typeName = name else {
                guard token.kind == .identifier else {
                    throw UnexpectedToken(found: token, expected: [.identifier])
                }
                name = String(token.text)
                continue
            }

            if !seenColon {
                guard token.kind == .colon else {
                    throw UnexpectedToken(found: token, expected: [.colon])
                }
                seenColon = true
                continue
            }

            switch token.kind {
            case .openParen:
                bracketStack.append(.paren)
            case .closeParen:
                if bracketStack.last != .paren {
                    var expected: Set<Lexer.TokenKind> = [
                        .identifier, .comma, .leftBracket, .openParen
                    ]
                    if bracketStack.last == .bracket {
                        expected.insert(.rightBracket)
                    }
                    throw UnexpectedToken(found: token, expected: expected)
                }
                bracketStack.removeLast()
            case .leftBracket:
                bracketStack.append(.bracket)
            case .rightBracket:
                if bracketStack.last != .bracket {
                    var expected: Set<Lexer.TokenKind> = [
                        .identifier, .comma, .leftBracket, .openParen
                    ]
                    if bracketStack.last == .paren {
                        expected.insert(.closeParen)
                    }
                    throw UnexpectedToken(found: token, expected: expected)
                }
                bracketStack.removeLast()
            case .comma:
                if !bracketStack.isEmpty {
                    break
                }
                let type = try parseType(currentExpression)
                pairs.append((typeName, type))

                name = nil
                seenColon = false
                currentExpression = []

                continue
            default:
                break
            }
            currentExpression.append(token)
        }

        if name != nil || !currentExpression.isEmpty {
            throw UnexpectedEndOfList(location: lastToken.endLoc)
        }

        return pairs.map { .init(name: $0, type: $1) }
    }

    struct IncompleteType: Error {}

    enum PartlyParsedType {
        case comma
        case identifier(String)
        indirect case indexed(PartlyParsedType, [PartlyParsedType])
        indirect case propertyAccess(PartlyParsedType, String?)

        func toExpr() throws -> Expression {
            switch self {
            case .comma:
                throw IncompleteType()
            case .identifier(let name):
                return .identifier(name)
            case .indexed(let base, let indexes):
                return try .indexAccess(
                    base: base.toExpr(),
                    index: indexes.map { try $0.toExpr() }
                )
            case .propertyAccess(let base, let property):
                guard let property else {
                    throw IncompleteType()
                }
                return .propertyAccess(base: try base.toExpr(), property: property)
            }
        }
    }

    static func parseType(_ tokens: [Lexer.Token]) throws -> Expression {
        // Type parsing is limited. Only the following expression kinds are allowed:
        // Identifier - Foo
        // Index access - Foo[Bar] OR Foo[Bar, Baz]
        // Property access - Foo.Bar
        notImplemented()
    }

    static func shuntingYard(_ tokens: [Lexer.Token]) throws -> Expression {
        notImplemented()
    }
}
