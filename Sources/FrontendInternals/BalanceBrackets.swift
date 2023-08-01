extension SyntaxTree {
    struct UnexpectedEOF: Error {}

    private static func parseGroup(
        _ tokens: inout Lexer.TokenCollection,
        open: Lexer.TokenKind,
        close: Lexer.TokenKind
    ) throws -> [Lexer.Token] {
        tokens.discardLeadingTrivia()
        try assertStarts(&tokens, with: [open])

        var parenCount = 1
        var expr = Array<Lexer.Token>()
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

    static func parseParenGroup(_ tokens: inout Lexer.TokenCollection) throws -> [Lexer.Token] {
        return try parseGroup(&tokens, open: .openParen, close: .closeParen)
    }

    static func parseBraceGroup(_ tokens: inout Lexer.TokenCollection) throws -> [Lexer.Token] {
        return try parseGroup(&tokens, open: .openBrace, close: .closeBrace)
    }
}