import Algorithms
import DequeModule

extension SyntaxTree {
    static func withoutTrivia(
        _ tokens: some BidirectionalCollection<Lexer.Token>
    ) -> some BidirectionalCollection<Lexer.Token> {
        tokens.lazy
            .filter {
                $0.kind != .blockComment && $0.kind != .lineComment && $0.kind != .whitespace
            }
    }

    static func parseCommaSeparatedIdentifiers(_ tokens: Deque<Lexer.Token>) throws -> [String] {
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

    static func parseArgumentDeclList(_ tokens: Deque<Lexer.Token>) throws -> [_NameAndType] {
        guard let lastToken = tokens.last else {
            return []
        }

        var pairs = Array<(String, _Type)>()

        var name: String? = nil
        var seenColon = false
        var bracketStack = Array<PairType>()
        var currentExpression = Deque<Lexer.Token>()

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

    enum TypeParseError: Error {
        case tooManyTypes
        case dotWithoutProperty
        case missingType
    }

    static func parseType(_ tokens: __owned Deque<Lexer.Token>) throws -> _Type {
        let list = try parseTypeList(tokens)
        guard list.count == 1 else {
            throw TypeParseError.tooManyTypes
        }
        return list[0]
    }

    static func parseFullExpression(_ tokens: __owned Deque<Lexer.Token>) throws -> Expression {
        let balanced = try parseBalancedExpr(tokens)
        let callAccessParsed = try parseCallsAndAccesses(balanced)
        return try shuntingYard(callAccessParsed)
    }

    static func parseTypeList(_ tokens: __owned Deque<Lexer.Token>) throws -> [_Type] {
        // Type parsing is limited. Only the following expression kinds are allowed:
        // Identifier - Foo
        // Index access - Foo[Bar] OR Foo[Bar, Baz]
        // Property access - Foo.Bar
        var tokens = tokens
        var result: [_Type?] = [nil]

        while let next = tokens.first {
            switch next.kind {
            case .identifier:
                guard case .some(.none) = result.popLast() else {
                    throw UnexpectedToken(found: next, expected: [.leftBracket, .rightBracket, .dot, .comma])
                }
                result.append(.identifier(String(next.text)))
                tokens.removeFirst() // Name
            case .dot:
                guard case let oldResult?? = result.popLast() else {
                    throw UnexpectedToken(found: next, expected: [.identifier])
                }
                guard tokens.count > 1,
                      tokens[1].kind == .identifier else {
                    throw TypeParseError.dotWithoutProperty
                }
                result.append(.dot(oldResult, String(tokens[1].text)))
                tokens.removeFirst(2) // '.', Property
            case .leftBracket:
                guard case let oldResult?? = result.popLast() else {
                    throw UnexpectedToken(found: next, expected: [.identifier])
                }
                let argumentTokens = try parseBracketGroup(&tokens)
                let argumentList = try parseTypeList(argumentTokens)
                result.append(.generic(oldResult, argumentList))
            case .comma:
                tokens.removeFirst() // ','
                result.append(nil)
            default:
                throw UnexpectedToken(found: next, expected: [.identifier, .dot, .leftBracket])
            }
        }

        return try result.map {
            guard let type = $0 else {
                throw TypeParseError.missingType
            }
            return type
        }
    }
}
