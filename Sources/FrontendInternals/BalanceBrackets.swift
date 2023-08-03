extension SyntaxTree {
    struct UnexpectedEOF: Error, CustomStringConvertible {
        var file: String?

        var description: String {
            if let file {
                return "\(file): Unexpected EOF"
            } else {
                return "Unexpected EOF"
            }
        }
    }

    private static func parseGroup(
        _ tokens: inout Lexer.TokenCollection,
        open: Lexer.TokenKind,
        close: Lexer.TokenKind
    ) throws -> Lexer.TokenCollection {
        tokens.discardLeadingTrivia()
        try assertStarts(&tokens, with: [open])

        var parenCount = 1
        var expr = Lexer.TokenCollection()
        loop: while true {
            guard let next = tokens.popFirst() else {
                throw UnexpectedEOF()
            }

            switch next.kind {
            case open:
                parenCount += 1
            case close:
                parenCount -= 1
                if parenCount == 0 {
                    break loop
                }
            default:
                break
            }
            
            expr.append(next)
        }

        return expr
    }

    static func parseParenGroup(_ tokens: inout Lexer.TokenCollection) throws -> Lexer.TokenCollection {
        return try parseGroup(&tokens, open: .openParen, close: .closeParen)
    }

    static func parseBraceGroup(_ tokens: inout Lexer.TokenCollection) throws -> Lexer.TokenCollection {
        return try parseGroup(&tokens, open: .openBrace, close: .closeBrace)
    }

    static func parseBracketGroup(_ tokens: inout Lexer.TokenCollection) throws -> Lexer.TokenCollection {
        return try parseGroup(&tokens, open: .leftBracket, close: .rightBracket)
    }

    enum BalancedExpr {
        case token(Lexer.Token)
        case group(start: Lexer.Token, body: [BalancedExpr])
    }

    static func parseBalancedExpr(_ tokens: __owned Lexer.TokenCollection) throws -> [BalancedExpr] {
        var result = Array<BalancedExpr>()
        var tokens = tokens

        while let next = tokens.first {
            switch next.kind {
            case .openParen:
                let slice = try parseParenGroup(&tokens)
                result.append(.group(start: next, body: try parseBalancedExpr(slice)))
            case .leftBracket:
                let slice = try parseBracketGroup(&tokens)
                result.append(.group(start: next, body: try parseBalancedExpr(slice)))
            case .openBrace:
                let slice = try parseBraceGroup(&tokens)
                result.append(.group(start: next, body: try parseBalancedExpr(slice)))
            default:
                result.append(.token(next))
                tokens.removeFirst()
            }
        }

        return result
    }

    enum PartiallyParsedExpr {
        indirect case functionApplication(function: PartiallyParsedExpr, args: [PartiallyParsedExpr])
        case unparsed([Lexer.Token])
    }

    static func parseFunctionApplications(_ tokens: __owned Lexer.TokenCollection) throws -> [PartiallyParsedExpr] {
        let balanced = try parseBalancedExpr(tokens)
        notImplemented()
    }
}